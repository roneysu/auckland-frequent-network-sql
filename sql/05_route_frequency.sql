SELECT * FROM analysis_days;
SELECT * FROM v_active_services ORDER BY `date`, service_id;
SELECT * FROM active_trips LIMIT 20;
SELECT * FROM trip_stop_departures LIMIT 20;

-- check frequency definition A --
-- the longest interval time no longer than 15 mins --

DROP VIEW IF EXISTS v_route_gap_a;

CREATE VIEW v_route_gap_a AS
WITH method_a AS(
SELECT route_id,direction_id,date,departure_time,
    LAG(departure_time) OVER (PARTITION BY route_id,direction_id,date ORDER BY departure_time) AS former_departuretime
FROM trip_stop_departures
WHERE is_origin = 1 AND departure_time < '19:00:00' AND departure_time >= '07:00:00'
),
route_gap AS (
    SELECT route_id, date, MAX((TIME_TO_SEC(departure_time) - TIME_TO_SEC(former_departuretime)))/60 AS max_interval
    FROM method_a
    GROUP BY route_id, date
)
SELECT route_id, date, max_interval,
   CASE
       WHEN max_interval IS NULL THEN 'NG'
       WHEN max_interval <= 15 THEN 'OK'
       ELSE 'NG'
   END AS frequency_check
FROM route_gap;

-- Which bus routes meet the standards on weekdays, Saturdays, and Sundays, respectively?--

SELECT vrga.route_id, 
MAX(CASE WHEN ad.day_type = 'Weekday' THEN vrga.frequency_check END) AS 'Weekday',
MAX(CASE WHEN ad.day_type = 'Saturday' THEN vrga.frequency_check END) AS Saturday,
MAX(CASE WHEN ad.day_type = 'Sunday' THEN vrga.frequency_check END) AS Sunday
FROM v_route_gap_a vrga
JOIN analysis_days ad ON vrga.date = ad.date
GROUP BY VRGA.route_id
HAVING SUM(vrga.frequency_check = 'OK') > 0
ORDER BY VRGA.route_id;

-- What are the times for the first and last buses on weekdays for each qualifying route? Which routes continue to operate after 10:00 PM? --
WITH ok_route AS(
SELECT vg.route_id,MIN(td.departure_time) AS First_bus,MAX(td.departure_time) AS Final_bus ,vg.date
FROM v_route_gap_a vg
JOIN trip_stop_departures td ON vg.route_id = td.route_id AND vg.date = td.date
WHERE frequency_check = 'OK' AND td.is_origin = 1
GROUP BY vg.route_id, vg.date
)
SELECT ore.route_id,ore.First_bus,ore.Final_bus
FROM ok_route ore
JOIN analysis_days ad ON ore.date = ad.date
WHERE day_type = 'Weekday';

WITH ok_route AS(
SELECT vg.route_id,MAX(td.departure_time) AS Final_bus ,vg.date
FROM v_route_gap_a vg
JOIN trip_stop_departures td ON vg.route_id = td.route_id AND vg.date = td.date
WHERE frequency_check = 'OK' AND td.is_origin = 1
GROUP BY vg.route_id, vg.date
)
SELECT ore.route_id,ore.Final_bus
FROM ok_route ore
JOIN analysis_days ad ON ore.date = ad.date
WHERE day_type = 'Weekday' AND ore.Final_bus>= '22:00:00';

-- method b --

DROP VIEW IF EXISTS expected;

CREATE VIEW expected AS
WITH RECURSIVE timetable AS(
    SELECT 28 AS n
    UNION ALL
    SELECT n + 1 FROM timetable
    WHERE n < 75   
)
SELECT DISTINCT route_id,direction_id,date,t.n
FROM active_trips ats
CROSS JOIN timetable t;

DROP VIEW IF EXISTS actual;

CREATE VIEW actual AS
SELECT DISTINCT route_id,direction_id,date,FLOOR(TIME_TO_SEC(departure_time) / 900) AS real_timetable
FROM trip_stop_departures
WHERE is_origin = 1 AND departure_time < '19:00:00' AND departure_time >= '07:00:00';

CREATE VIEW v_route_gap_b AS
SELECT e.route_id,e.date,
       CASE WHEN SUM(a.real_timetable IS NULL) > 0 THEN 'NG'
       ELSE 'OK' END AS method_B_CHECK
FROM expected e LEFT JOIN actual a ON e.route_id = a.route_id AND e.direction_id = a.direction_id AND e.date = a.date AND e.n = a.real_timetable
GROUP BY e.route_id, e.date;

SELECT COUNT(*),va.frequency_check,vb.method_B_CHECK
FROM v_route_gap_b vb LEFT JOIN v_route_gap_a va ON vb.date = va.date AND vb.route_id = va.route_id
GROUP BY va.frequency_check,VB.method_B_CHECK;


-- For routes that fall short of the standard but are reasonably close (with a maximum interval between 15 and 20 minutes), at what time does that longest interval occur? --

WITH method_a AS(
SELECT route_id,direction_id,date,departure_time,
    LAG(departure_time) OVER (PARTITION BY route_id,direction_id,date ORDER BY departure_time) AS former_departuretime
FROM trip_stop_departures
WHERE is_origin = 1 AND departure_time < '19:00:00' AND departure_time >= '07:00:00'
),
time_cal AS(
     SELECT route_id,date, departure_time, former_departuretime ,((TIME_TO_SEC(departure_time) - TIME_TO_SEC(former_departuretime)) / 60) AS time_lag
FROM method_a
),
time_rank AS(
    SELECT route_id,date,time_lag,ROW_NUMBER()OVER(PARTITION BY route_id,date ORDER BY time_lag DESC ) AS time_lag_rank,departure_time, former_departuretime
FROM time_cal
)
SELECT tr.route_id,tr.date,tr.departure_time, tr.former_departuretime,tr.time_lag
FROM time_rank tr
JOIN analysis_days ad ON tr.date = ad.date
WHERE tr.time_lag_rank = 1 AND ad.day_type = 'Weekday' AND tr.time_lag > 15 AND tr.time_lag <= 20;

-- Calculate the average headway for routes that meet the standards. --



WITH method_a AS(
SELECT route_id,direction_id,date,departure_time,
    LAG(departure_time) OVER (PARTITION BY route_id,direction_id,date ORDER BY departure_time) AS former_departuretime
FROM trip_stop_departures
WHERE is_origin = 1
),
step_2 AS(
    SELECT ma.route_id, ma.date,departure_time,former_departuretime,
      (TIME_TO_SEC(ma.departure_time) - TIME_TO_SEC(ma.former_departuretime))/60 AS interval_min,
      CASE
    WHEN departure_time < '07:00:00' THEN 'Early morning'
    WHEN departure_time < '09:00:00' THEN 'Morning rush hour'
    WHEN departure_time < '15:00:00' THEN 'Off-peak'
    WHEN departure_time < '18:00:00' THEN 'Evening rush hour'
    WHEN departure_time < '21:00:00' THEN 'Early evening'
    ELSE 'Night'
END AS time_period
FROM method_a ma
JOIN v_route_gap_a va ON  ma.route_id = va.route_id AND ma.date = va.date
JOIN analysis_days ad ON ma.date = ad.date
WHERE va.frequency_check = 'OK' AND former_departuretime IS NOT NULL AND ad.day_type = 'Weekday'
)
SELECT time_period, AVG(interval_min) AS avg_time
FROM step_2
GROUP BY time_period;


