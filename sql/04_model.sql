
SELECT * FROM routes LIMIT 5;
SELECT * FROM trips LIMIT 5;
SELECT * FROM stop_times LIMIT 5;
SELECT * FROM stops LIMIT 5;
SELECT * FROM calendar LIMIT 5;
SELECT * FROM calendar_dates LIMIT 5;


DROP TABLE IF EXISTS trip_stop_departures;
DROP TABLE IF EXISTS active_trips;
DROP VIEW  IF EXISTS v_active_services;
DROP TABLE IF EXISTS analysis_days;


-- create tabel analysis days--

CREATE TABLE analysis_days (
    date Date NOT NULL,
    day_type ENUM('Weekday','Saturday','Sunday'),
    PRIMARY KEY(date)
);


INSERT INTO analysis_days
VALUES ('2026-11-18', 'Weekday'),
       ('2026-11-21', 'Saturday'),
       ('2026-11-22', 'Sunday');

-- which trip is running with the analysis day --

SELECT exception_type, COUNT(*) FROM calendar_dates GROUP BY exception_type;

CREATE VIEW v_active_services AS
    SELECT c.service_id, ad.date
FROM calendar c
CROSS JOIN analysis_days ad
WHERE ad.date >= c.start_date AND ad.date <= c.end_date AND  
    CASE WHEN DAYOFWEEK(date) = 2 THEN c.monday
         WHEN DAYOFWEEK(date) = 3 THEN c.tuesday
         WHEN DAYOFWEEK(date) = 4 THEN c.wednesday
         WHEN DAYOFWEEK(date) = 5 THEN c.thursday
         WHEN DAYOFWEEK(date) = 6 THEN c.friday
         WHEN DAYOFWEEK(date) = 7 THEN c.saturday
         WHEN DAYOFWEEK(date) = 1 THEN c.sunday
        END = 1 
    AND NOT EXISTS(
        SELECT 1
        FROM calendar_dates cd
        WHERE cd.exception_type = 2 AND cd.date = ad.date AND cd.service_id = c.service_id
    )
UNION
SELECT cd.service_id, ad.date
FROM calendar_dates cd
JOIN analysis_days ad on ad.date = cd.date
WHERE cd.exception_type = 1;

-- every bus (route type = 3) which run in analysis days and their info -- 

CREATE TABLE active_trips AS
SELECT t.route_id,vas.service_id,t.direction_id,vas.date,t.trip_id
FROM v_active_services vas
JOIN trips t ON t.service_id = vas.service_id
JOIN routes r ON r.route_id = t.route_id
WHERE r.route_type = 3;

SELECT *
FROM active_trips;

-- On a certain analysis day, a train departs from a station.--

CREATE TABLE trip_stop_departures AS
SELECT st.trip_id, st.stop_sequence,ats.date,ats.direction_id,ats.route_id,st.stop_id,st.departure_time,
    CASE WHEN
       ROW_NUMBER() OVER(PARTITION BY st.trip_id,ats.date ORDER BY st.stop_sequence) = 1 THEN 1
       ELSE 0 END AS is_origin
FROM stop_times st
JOIN active_trips ats ON ats.trip_id = st.trip_id;
