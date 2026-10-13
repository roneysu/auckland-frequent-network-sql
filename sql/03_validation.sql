-- 03_validation.sql
-- Validate the 6 imported GTFS tables before any analysis.
-- Each check selects the BAD rows. 0 rows = passed.
-- Re-runnable: the script clears data_issues first.

-- ========== setup ==========

CREATE TABLE IF NOT EXISTS data_issues (
    issue_id INT AUTO_INCREMENT PRIMARY KEY,
    table_name VARCHAR(20),
    record_id VARCHAR(255),
    issue_type VARCHAR(255),
    severity VARCHAR(30),
    detail VARCHAR(255),
    found_at DATETIME
);

TRUNCATE TABLE data_issues;


-- ========== check 1: duplicate primary keys ==========
-- Primary key constraints already block duplicates at import (Skipped = 0),
-- so these are expected to be 0 rows. Kept as a redundant confirmation.

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'routes', route_id, 'pk_duplicate', 'blocking', CONCAT('appears ', COUNT(*), ' times'), NOW()
FROM routes
GROUP BY route_id
HAVING COUNT(*) > 1;

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'trips', trip_id, 'pk_duplicate', 'blocking', CONCAT('appears ', COUNT(*), ' times'), NOW()
FROM trips
GROUP BY trip_id
HAVING COUNT(*) > 1;

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'stop_times', CONCAT(trip_id, '+', stop_sequence), 'pk_duplicate', 'blocking', CONCAT('appears ', COUNT(*), ' times'), NOW()
FROM stop_times
GROUP BY trip_id, stop_sequence
HAVING COUNT(*) > 1;

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'stops', stop_id, 'pk_duplicate', 'blocking', CONCAT('appears ', COUNT(*), ' times'), NOW()
FROM stops
GROUP BY stop_id
HAVING COUNT(*) > 1;

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'calendar', service_id, 'pk_duplicate', 'blocking', CONCAT('appears ', COUNT(*), ' times'), NOW()
FROM calendar
GROUP BY service_id
HAVING COUNT(*) > 1;

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'calendar_dates', CONCAT(service_id, '+', `date`), 'pk_duplicate', 'blocking', CONCAT('appears ', COUNT(*), ' times'), NOW()
FROM calendar_dates
GROUP BY service_id, `date`
HAVING COUNT(*) > 1;


-- ========== check 2: stop_times references ==========
-- One row per MISSING id (not per referencing row), with the reference count in detail.
-- No foreign keys on purpose, so orphans can be imported and found here.

-- trip_id in stop_times but not in trips
INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'stop_times', st.trip_id, 'orphan_trip_id', 'blocking',
       CONCAT('trip_id not in trips, referenced by ', COUNT(*), ' stop_times rows'), NOW()
FROM stop_times st
LEFT JOIN trips t ON t.trip_id = st.trip_id
WHERE t.trip_id IS NULL
GROUP BY st.trip_id;

-- stop_id in stop_times but not in stops
INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'stop_times', st.stop_id, 'orphan_stop_id', 'blocking',
       CONCAT('stop_id not in stops, referenced by ', COUNT(*), ' stop_times rows'), NOW()
FROM stop_times st
LEFT JOIN stops s ON s.stop_id = st.stop_id
WHERE s.stop_id IS NULL
GROUP BY st.stop_id;


-- ========== check 3: trips references ==========

-- route_id in trips but not in routes
INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'trips', t.route_id, 'orphan_route_id', 'blocking',
       CONCAT('route_id not in routes, referenced by ', COUNT(*), ' trips'), NOW()
FROM trips t
WHERE NOT EXISTS (
    SELECT 1
    FROM routes r
    WHERE r.route_id = t.route_id
)
GROUP BY t.route_id;

-- service_id found in NEITHER calendar nor calendar_dates (trip would never run)
-- found in only one of the two is normal in GTFS
INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'trips', t.service_id, 'orphan_service_id', 'blocking',
       CONCAT('service_id in neither calendar nor calendar_dates, referenced by ', COUNT(*), ' trips'), NOW()
FROM trips t
WHERE NOT EXISTS (
    SELECT 1
    FROM calendar c
    WHERE c.service_id = t.service_id
)
AND NOT EXISTS (
    SELECT 1
    FROM calendar_dates cd
    WHERE cd.service_id = t.service_id
)
GROUP BY t.service_id;


-- ========== check 4: unused routes and stops ==========
-- Not necessarily an error (retired routes, station parents), so info.

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'routes', r.route_id, 'unused_route', 'info', 'route has no trips', NOW()
FROM routes r
WHERE NOT EXISTS (
    SELECT 1
    FROM trips t
    WHERE t.route_id = r.route_id
);

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'stops', s.stop_id, 'unused_stop', 'info',
       CONCAT('no stop_times, location_type = ', COALESCE(CAST(s.location_type AS CHAR), 'NULL')), NOW()
FROM stops s
WHERE NOT EXISTS (
    SELECT 1
    FROM stop_times st
    WHERE st.stop_id = s.stop_id
);




-- ========== check 5: NULL in key columns ==========
-- Key column = a NULL here would make a later analysis wrong.
-- One row per table + column, with the NULL count in detail.

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT x.table_name, NULL, 'null_key_column', x.severity,
       CONCAT(x.col, ' is NULL in ', x.n, ' rows'), NOW()
FROM (
    SELECT 'stop_times' AS table_name, 'departure_time' AS col, 'blocking' AS severity, COUNT(*) AS n
    FROM stop_times WHERE departure_time IS NULL
    UNION ALL
    SELECT 'stop_times', 'arrival_time', 'warning', COUNT(*)
    FROM stop_times WHERE arrival_time IS NULL
    UNION ALL
    SELECT 'stops', 'stop_lat', 'warning', COUNT(*)
    FROM stops WHERE stop_lat IS NULL
    UNION ALL
    SELECT 'stops', 'stop_lon', 'warning', COUNT(*)
    FROM stops WHERE stop_lon IS NULL
    UNION ALL
    SELECT 'trips', 'direction_id', 'warning', COUNT(*)
    FROM trips WHERE direction_id IS NULL
    UNION ALL
    SELECT 'routes', 'route_short_name', 'warning', COUNT(*)
    FROM routes WHERE route_short_name IS NULL
    UNION ALL
    SELECT 'routes', 'route_type', 'warning', COUNT(*)
    FROM routes WHERE route_type IS NULL
    UNION ALL
    SELECT 'calendar_dates', 'exception_type', 'blocking', COUNT(*)
    FROM calendar_dates WHERE exception_type IS NULL
) x
WHERE x.n > 0;

-- block_id is entirely NULL: AT does not publish vehicle blocks
INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'trips', NULL, 'column_all_null', 'info',
       'block_id is NULL in all rows, AT does not publish vehicle blocks', NOW()
FROM trips
HAVING COUNT(block_id) = 0;


-- ========== check 6: arrival later than departure at the same stop ==========

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'stop_times', CONCAT(trip_id, '+', stop_sequence), 'arrival_after_departure', 'warning',
       CONCAT('arrival ', arrival_time, ' is later than departure ', departure_time), NOW()
FROM stop_times
WHERE arrival_time > departure_time;


-- ========== check 7: time going backwards along a trip ==========
-- window function is computed in the CTE, filtered outside (WHERE runs before windows)
-- first stop of each trip has no previous row: LAG gives NULL, comparison is NULL, row is skipped

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
WITH check_sequence AS (
    SELECT trip_id, stop_sequence, arrival_time,
           LAG(departure_time) OVER (PARTITION BY trip_id ORDER BY stop_sequence) AS prev_departure
    FROM stop_times
)
SELECT 'stop_times', CONCAT(trip_id, '+', stop_sequence), 'time_reversed', 'warning',
       CONCAT('arrival ', arrival_time, ' is earlier than previous stop departure ', prev_departure), NOW()
FROM check_sequence
WHERE arrival_time < prev_departure;


-- ========== check 8: coordinates inside the Auckland region ==========
-- lat -38 to -35.5, lon 174 to 176 (BETWEEN is inclusive, smaller value first)
-- NULL coordinates are not caught here, check 5 covers them

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'stops', stop_id, 'location_out_of_range', 'warning',
       CONCAT_WS(', ', CONCAT('lat=', stop_lat), CONCAT('lon=', stop_lon)), NOW()
FROM stops
WHERE stop_lat NOT BETWEEN -38 AND -35.5
   OR stop_lon NOT BETWEEN 174 AND 176;


-- ========== check 9: times past 24:00:00 ==========
-- Allowed by GTFS (trip running past midnight on the same service day), not an error.
-- Analysis must be aware: >= 24:00:00 counts as the next calendar day.

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'stop_times', NULL, 'time_over_24h', 'info',
       CONCAT('departure >= 24:00:00 in ', SUM(departure_time >= '24:00:00'), ' rows, max ', MAX(departure_time),
              '; arrival >= 24:00:00 in ', SUM(arrival_time >= '24:00:00'), ' rows, max ', MAX(arrival_time)), NOW()
FROM stop_times
HAVING SUM(departure_time >= '24:00:00') > 0
    OR SUM(arrival_time >= '24:00:00') > 0;

-- ========== check 10: calendar validity range ==========
-- Chosen analysis dates must fall inside these ranges.

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'calendar', NULL, 'valid_date_range', 'info',
       CONCAT('start_date min ', MIN(start_date), ', end_date max ', MAX(end_date)), NOW()
FROM calendar;

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT 'calendar_dates', NULL, 'valid_date_range', 'info',
       CONCAT('date min ', MIN(`date`), ', max ', MAX(`date`)), NOW()
FROM calendar_dates;


-- ========== record the checks that passed ==========
-- A check with 0 bad rows leaves nothing in data_issues, so log it explicitly.
-- NOT EXISTS is tied to BOTH table_name and issue_type.

INSERT INTO data_issues (table_name, record_id, issue_type, severity, detail, found_at)
SELECT c.table_name, NULL, 'check_passed', 'info', CONCAT(c.check_name, ': 0 bad rows'), NOW()
FROM (
    SELECT 'routes' AS table_name, 'pk_duplicate' AS check_name
    UNION ALL SELECT 'trips', 'pk_duplicate'
    UNION ALL SELECT 'stop_times', 'pk_duplicate'
    UNION ALL SELECT 'stops', 'pk_duplicate'
    UNION ALL SELECT 'calendar', 'pk_duplicate'
    UNION ALL SELECT 'calendar_dates', 'pk_duplicate'
    UNION ALL SELECT 'stop_times', 'orphan_trip_id'
    UNION ALL SELECT 'stop_times', 'orphan_stop_id'
    UNION ALL SELECT 'trips', 'orphan_route_id'
    UNION ALL SELECT 'trips', 'orphan_service_id'
    UNION ALL SELECT 'routes', 'unused_route'
    UNION ALL SELECT 'stops', 'unused_stop'
    UNION ALL SELECT 'stop_times', 'null_key_column'
    UNION ALL SELECT 'stops', 'null_key_column'
    UNION ALL SELECT 'trips', 'null_key_column'
    UNION ALL SELECT 'routes', 'null_key_column'
    UNION ALL SELECT 'calendar_dates', 'null_key_column'
    UNION ALL SELECT 'stop_times', 'arrival_after_departure'
    UNION ALL SELECT 'stop_times', 'time_reversed'
    UNION ALL SELECT 'stops', 'location_out_of_range'
) c
WHERE NOT EXISTS (
    SELECT 1
    FROM data_issues d
    WHERE d.table_name = c.table_name
      AND d.issue_type = c.check_name
);


-- ========== summary (goes into the README) ==========

SELECT issue_type, severity, COUNT(*) AS n
FROM data_issues
GROUP BY issue_type, severity
ORDER BY FIELD(severity, 'blocking', 'warning', 'info'), issue_type;