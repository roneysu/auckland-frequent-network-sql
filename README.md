# Auckland Frequent Bus Network: Checking the 15-Minute Promise with SQL

Checking Auckland Transport's (AT) frequent-service promise against its own GTFS timetable, using MySQL.

AT says: *"Each route runs at least every 15 minutes, from 7am to 7pm, 7 days a week."*
This project asks whether the published timetable shows that, route by route and stop by stop.

## Key findings

1. **22 of the 57 routes on AT's official frequent list met the standard on all three test days** (weekday, Saturday, Sunday) when each route was checked on its own. 17 matched by route number. 5 matched by name abbreviation (for example AirportLink is `AIR` in the feed; this match is my inference).
2. **Merging branch routes of the same corridor added 4 more** (25B, 25L, 97B, 97R), so 26 of 57 in total. The other 31 were not verified in this feed. This is a statement about the timetable data I used, not a claim that AT's promise is wrong (see Limitations).
3. **Many unverified routes come in pairs that each run about every 30 minutes** (95B/95C, 97B/97R, 67A/67B, 50A/50B, 22N/22R, 24B/24R). The official page lists branches separately, but the promise may apply to the corridor. Merging branches fixed some groups (97, 25), helped others (95: 30 to 25 minutes), and did not fix 67 (still 30).
4. **On the test weekday, 861 of 5,619 stops (15%) have no gap longer than 15 minutes between 07:00 and 19:00.** 126 of these 861 are *stacked* stops: no single route through the stop meets the standard, so the stop is frequent only because several routes overlap.
5. **803 stops are served by at least one route that meets the standard, but the stop itself is not frequent.** I did not find the cause (see Limitations).
6. **Performance:** the main stop-level query went from 6.2 s to 1.9 s. An index alone gave about 6% (within noise). Filtering to one day *before* the window function cut the window input from 798k to 313k rows and gave the real gain.

## Question

Does the timetable support "every 15 minutes, 7am to 7pm, 7 days a week"?

1. Which routes meet it, on a weekday, Saturday and Sunday?
2. Which routes nearly meet it, and why do they miss?
3. Which stops are frequent, and which of those are frequent only because routes overlap?
4. How does my result compare with AT's official frequent route list?

## Data

- Source: Auckland Transport public GTFS feed. Downloaded: 7 October 2026. Calendar covers 2026-09-30 to 2027-01-24.
- Six tables loaded: `routes`, `trips`, `stop_times` (1.07M rows), `stops`, `calendar`, `calendar_dates`.
- `frequencies.txt` is empty and `block_id` is all NULL in this feed.
- Official list: [AT "Frequent buses on key routes"](https://at.govt.nz/bus-train-ferry/bus-services/frequent-buses-on-key-routes), page says "Last updated 11/06/2026". I copied the 57 entries by hand (`sql/07_official_check.sql`).
- Three analysis days: Wednesday 2026-11-18, Saturday 2026-11-21, Sunday 2026-11-22.

## Data validation (`03_validation.sql`)

Checks write their results to a `data_issues` table with a severity (blocking, warning, info). Checks that found nothing are logged as `check_passed` (18 rows). The rest produced these findings:

| Issue | Count | Handling |
|---|---|---|
| Stops never used by any trip | 1,192 | Left in, noted. Cause not investigated. |
| Stops with coordinates outside the Auckland area | 3 | "Virtual Point" ferry stops. Left in; excluded from any distance work. |
| Column that is entirely NULL | 1 | `block_id`. Not used. |
| Times of 24:00:00 or later | 1 check, 9,866 rows | Real (late trips, max 28:00:00). `TIME` type holds them. |
| Calendar date range notes | 2 | Noted. |

No blocking issues. No foreign keys are declared on purpose, so orphan rows can be found by the validation queries instead of being rejected at load time.

## Method and assumptions

**Layers:** raw tables, then views and result tables, then analysis queries. Each stage is one SQL file in `sql/`.

**Service on a day** (`04_model.sql`): a service runs if `calendar` covers the weekday and date, and `calendar_dates` does not remove it (`exception_type = 2`), or `calendar_dates` adds it (`exception_type = 1`). Times after midnight stay on the service day they belong to.

**Result tables:** `active_trips` and `trip_stop_departures` are `CREATE TABLE AS SELECT` snapshots. They must be rebuilt if `analysis_days` changes.

**Definition A (main):** for each route, direction and day, take departures from the first stop of each trip between 07:00 and 19:00. A route passes if the largest gap between consecutive departures is 15 minutes or less. Passing a day needs both directions to pass.

**Definition B (cross-check):** split 07:00 to 19:00 into 48 blocks of 15 minutes (recursive CTE). A route passes if every block has at least one departure. B accepts a regular 20-minute service (each block still has a departure); A does not. Counted over route-days, A gave 85 passes (428 fails) and B gave 92 passes (423 fails).

**Why A is the main definition:** it matches the plain reading of "at least every 15 minutes". A is lenient at the window edges (the gap before the first departure after 07:00 is not counted).

**Stop-level frequency:** same gap logic per stop and day, over all departures where boarding is allowed (`pickup_type = 0`), any route and any direction at the same `stop_id`.

**Official comparison:** match on `routes.route_short_name`. A route counts as meeting the promise only if it passes on all three days. If one route number maps to several `route_id`s, a day counts if any of them passes (no such duplicates were found in this feed).

## Findings in detail

**Near-miss routes.** The near-miss list had 15 entries (largest gap just over 15 minutes). Two patterns: regular 20-minute service, and irregular service with gaps of 16 to 18 minutes. (My guess that a midday gap explained them was wrong.)

**Official list vs my result** (57 official entries):

| Group | Count |
|---|---|
| Official and met on all 3 days (route number match) | 17 |
| Official, met on all 3 days (abbreviation match, inferred) | 5 |
| Official, not met, route exists in feed | 35 |
| In my result but not official | 0 (after abbreviation mapping) |

Of the 35 not met: 14 had a weekday maximum gap of 30 minutes or more (27T was 122 minutes). 9 were between 16 and 20 minutes. 4 were between 22 and 24 minutes. 7 met 15 minutes on the weekday but failed on the weekend (72X has no weekend service in this feed).

**Branch merging** (10 groups, 21 routes, grouped by hand from the official page):

| Group | Weekday / Sat / Sun max gap (min) |
|---|---|
| 97 | 15 / 15 / 15 (passes) |
| 25 | 10 / 14 / 14 (passes) |
| 27 | 14 / 17 / 17 |
| 11 | 18 / 19 / 19 |
| 22 | 20 / 19 / 18 |
| 72 | 20 / 20 / 20 |
| 50 | 22 / 16 / 16 |
| 24 | 23 / 22 / 23 |
| 95 | 25 / 25 / 25 |
| 67 | 30 / 30 / 30 |

**Stops (weekday).** 5,619 stops in the stop-level view: 861 frequent, 4,758 not. Of the 861: 735 have at least one route that passes definition A, 126 are stacked. Separately, 803 stops have a passing route but are not frequent themselves.

## Performance (`08_performance.sql`)

Test query: count of frequent and not-frequent weekday stops (answer 861 / 4,758 each time).

| Change | Plan | Rows into window | Time |
|---|---|---|---|
| Primary key only | full table scan | 798k | 6.2 s |
| Composite index `(stop_id, date, departure_time)` | covering index skip scan | 798k | 5.8 s |
| Index plus weekday filter before the window function | covering index scan | 313k | 1.9 s |

The index removed the table scan but the sort and the window function (the largest cost, about 3.5 s) stayed. The big gain came from not computing all three days to keep one. The last row was measured with the index in place; I did not measure the rewrite without it. Each number is a single `EXPLAIN ANALYZE` run. The downstream views still use the original, slower definition.

Not done: comparing against computing everything from raw `stop_times` without the result tables.

## Limitations

- **Definition A is lenient** at the window edges.
- **Origin-based:** route frequency uses departures from the first stop of each trip. Short-turn trips that start elsewhere are not counted. I did not check how much this matters.
- **Terminal stops** with `pickup_type = 0` are still counted at stop level.
- **Three days only** (one weekday, one Saturday, one Sunday). Other days, school holidays and exceptions are not covered.
- **Stop level mixes routes and directions** that share a `stop_id`.
- **803 stops** with a passing route but not frequent: unexplained. Possible reasons, not tested: not every trip of a route serves the stop (branches or short trips), mixed directions at one `stop_id`, a mistake in my method.
- **Branch groups were made by hand** from the official page. Group 22 is approximate because 22N and 22R start at different places.
- **Abbreviation matches** (AIR, CTY, INN, OUT, TMK to the five link routes) are inferred from names, not verified route by route.
- **Timetable version:** the official page was updated on 2026-06-11; the feed I used may be a different version. Some mismatches may only reflect that.
- **1,192 unused stops** were not investigated.
- MySQL's `utf8mb4_0900_ai_ci` collation ignores case and accents, so `TāmakiLink` and `TamakiLink` match.

## How to run

```
sql/01_schema.sql           tables
sql/02_load.sql             load GTFS files
sql/03_validation.sql       data_issues checks
sql/04_model.sql            analysis_days, active services, result tables
sql/05_route_frequency.sql  definitions A and B, near misses, time-of-day, first/last bus
sql/06_stop_frequency.sql   stop-level frequency, stacked stops
sql/07_official_check.sql   official list, comparison, branch-merge test
sql/08_performance.sql      EXPLAIN ANALYZE and index (run once; see note inside)
```

MySQL 8.4. Run in order. Change `analysis_days` to test other dates, then rebuild the result tables in `04_model.sql`.

## Possible extensions

- Stops within 400 m of a frequent stop (spatial distance with `ST_Distance_Sphere`), to estimate who lives near the frequent network.
- Explain the 803 stops by checking how many trips of each passing route actually serve the stop.
- Apply the one-day filter to all downstream views.
- Check more days.