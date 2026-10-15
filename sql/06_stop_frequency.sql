DROP TABLE IF EXISTS trip_stop_departures_6;

CREATE TABLE trip_stop_departures_6 AS
SELECT st.trip_id, st.stop_sequence,ats.date,ats.direction_id,ats.route_id,st.stop_id,st.departure_time
FROM stop_times st
JOIN active_trips ats ON ats.trip_id = st.trip_id
WHERE st.pickup_type = 0;


DROP VIEW IF EXISTS v_stop_gap;

CREATE VIEW v_stop_gap AS
WITH method AS(
SELECT stop_id,date,departure_time,
    LAG(departure_time) OVER (PARTITION BY stop_id,date ORDER BY departure_time) AS former_departuretime
FROM trip_stop_departures_6
WHERE  departure_time < '19:00:00' AND departure_time >= '07:00:00'
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

-- Which stations are high-traffic stations on weekdays? --
DROP VIEW IF EXISTS weekday_frequency;

CREATE VIEW weekday_frequency AS
SELECT vg.stop_id,vg.frequency_check
FROM v_stop_gap vg
JOIN analysis_days ad ON vg.date = ad.date
WHERE day_type = 'Weekday';

SELECT COUNT(*) AS Number_stop, frequency_check
FROM weekday_frequency
GROUP BY frequency_check;

SELECT s.stop_name, wf.frequency_check
FROM stops s
JOIN weekday_frequency wf ON s.stop_id = wf.stop_id
WHERE wf.frequency_check = 'OK'
LIMIT 10; 


-- Which stations are classified as "high-frequency" stations, yet none of the transit lines passing through them meet the individual compliance criteria for Phase 4? --

CREATE VIEW route_stop AS
WITH high_freqweek AS(
    SELECT vg.stop_id,vg.frequency_check,vg.date
FROM v_stop_gap vg
JOIN analysis_days ad ON vg.date = ad.date
WHERE day_type = 'Weekday' AND vg.frequency_check = 'OK'
)
SELECT DISTINCT hf.stop_id, td6.route_id, hf.date
FROM high_freqweek hf
JOIN trip_stop_departures_6 td6 ON hf.stop_id = td6.stop_id AND hf.date = td6.date
WHERE td6.departure_time >= '07:00:00' AND td6.departure_time < '19:00:00';

SELECT rs.stop_id
FROM route_stop rs
JOIN v_route_gap_a vga ON rs.route_id = vga.route_id AND rs.date = vga.date
GROUP BY rs.stop_id
HAVING SUM(vga.frequency_check = 'OK') = 0
LIMIT 10;

