EXPLAIN ANALYZE SELECT frequency_check, COUNT(*) FROM weekday_frequency GROUP BY frequency_check;


-- Re-running this file: first run DROP INDEX idx_td6_stop_date_time ON trip_stop_departures_6;
-- otherwise CREATE INDEX fails and the baseline above is no longer a baseline.
CREATE INDEX idx_td6_stop_date_time ON trip_stop_departures_6 (stop_id, `date`, departure_time);
EXPLAIN ANALYZE SELECT frequency_check, COUNT(*) FROM weekday_frequency GROUP BY frequency_check;




EXPLAIN ANALYZE 
WITH method AS(
SELECT t6.stop_id,t6.date,t6.departure_time,
    LAG(t6.departure_time) OVER (PARTITION BY t6.stop_id,t6.date ORDER BY t6.departure_time) AS former_departuretime
FROM trip_stop_departures_6 t6
JOIN analysis_days ad ON ad.date = t6.date
WHERE  t6.departure_time < '19:00:00' AND t6.departure_time >= '07:00:00' AND ad.day_type = 'Weekday'
),
stop_gap AS (
    SELECT stop_id, date, MAX((TIME_TO_SEC(departure_time) - TIME_TO_SEC(former_departuretime)))/60 AS max_interval
    FROM method
    GROUP BY stop_id, date
)
SELECT stop_id, date, max_interval,
   CASE
       WHEN max_interval IS NULL THEN 'NG'
       WHEN max_interval <= 15 THEN 'OK'
       ELSE 'NG'
   END AS frequency_check
FROM stop_gap;

