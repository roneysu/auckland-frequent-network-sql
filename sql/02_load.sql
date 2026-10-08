-- calendar--

LOAD DATA LOCAL INFILE 'E:/auckland-frequent-network-sql/data/calendar.txt'
INTO TABLE calendar
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(service_id, monday, tuesday, wednesday, thursday, friday, saturday, sunday,
 @start_date, @end_date)
SET `start_date` = STR_TO_DATE(NULLIF(@start_date, ''), '%Y%m%d'),
    end_date   = STR_TO_DATE(NULLIF(TRIM(TRAILING '\r' FROM @end_date), ''), '%Y%m%d');


-- calendar date --

LOAD DATA LOCAL INFILE 'E:/auckland-frequent-network-sql/data/calendar_dates.txt'
INTO TABLE calendar_dates
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(service_id, @date, @exception_type)
SET `date`       = STR_TO_DATE(NULLIF(@date, ''), '%Y%m%d'),
    exception_type = NULLIF(TRIM(TRAILING '\r' FROM @exception_type), '');

-- routes --

LOAD DATA LOCAL INFILE 'E:/auckland-frequent-network-sql/data/routes.txt'
INTO TABLE routes
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(route_id, agency_id, route_short_name, route_long_name, @route_desc,
 route_type, @route_url, @route_color, @route_text_color, @route_sort_order,
 @contract_id)
SET route_desc       = NULLIF(@route_desc, ''),
    route_url        = NULLIF(@route_url, ''),
    route_color      = NULLIF(@route_color, ''),
    route_text_color = NULLIF(@route_text_color, ''),
    route_sort_order = NULLIF(@route_sort_order, ''),
    contract_id      = NULLIF(TRIM(TRAILING '\r' FROM @contract_id), '');

-- stops -- 

LOAD DATA LOCAL INFILE 'E:/auckland-frequent-network-sql/data/stops.txt'
INTO TABLE stops
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(stop_id, stop_code, stop_name, @stop_desc, stop_lat, stop_lon,
 @zone_id, @stop_url, location_type, @parent_station, @stop_timezone,
 @platform_code, wheelchair_boarding, @start_date, @end_date)
SET stop_desc      = NULLIF(@stop_desc, ''),
    zone_id        = NULLIF(@zone_id, ''),
    stop_url       = NULLIF(@stop_url, ''),
    parent_station = NULLIF(@parent_station, ''),
    stop_timezone  = NULLIF(@stop_timezone, ''),
    platform_code  = NULLIF(@platform_code, ''),
    `start_date`     = STR_TO_DATE(NULLIF(@start_date, ''), '%Y%m%d'),
    end_date       = STR_TO_DATE(NULLIF(TRIM(TRAILING '\r' FROM @end_date), ''), '%Y%m%d');

-- trips --

LOAD DATA LOCAL INFILE 'E:/auckland-frequent-network-sql/data/trips.txt'
INTO TABLE trips
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(route_id, service_id, trip_id, @trip_headsign, @trip_short_name,
 direction_id, @block_id, @shape_id, wheelchair_accessible, @bikes_allowed)
SET trip_headsign   = NULLIF(@trip_headsign, ''),
    trip_short_name = NULLIF(@trip_short_name, ''),
    block_id        = NULLIF(@block_id, ''),
    shape_id        = NULLIF(@shape_id, ''),
    bikes_allowed   = NULLIF(TRIM(TRAILING '\r' FROM @bikes_allowed), '');

-- stop times --

LOAD DATA LOCAL INFILE 'E:/auckland-frequent-network-sql/data/stop_times.txt'
INTO TABLE stop_times
CHARACTER SET utf8mb4
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(trip_id, arrival_time, departure_time, stop_id, stop_sequence,
 @stop_headsign, pickup_type, drop_off_type, @shape_dist_traveled, @timepoint)
SET stop_headsign       = NULLIF(@stop_headsign, ''),
    shape_dist_traveled = NULLIF(@shape_dist_traveled, ''),
    timepoint           = NULLIF(TRIM(TRAILING '\r' FROM @timepoint), '');


-- check --

SELECT COUNT(*) AS bad_cr
FROM routes
WHERE LOCATE(CHAR(13), contract_id) > 0;

SELECT COUNT(*)          AS total_rows,
       COUNT(block_id)   AS block_id_not_null,
       COUNT(shape_id)   AS shape_id_not_null,
       SUM(block_id = '') AS block_id_empty_string
FROM trips;

SELECT MIN(start_date) AS min_start, MAX(end_date) AS max_end FROM calendar;
SELECT MIN(`date`) AS min_d, MAX(`date`) AS max_d FROM calendar_dates;

SELECT MIN(departure_time) AS min_dep,
       MAX(departure_time) AS max_dep,
       COUNT(*)            AS over_24h
FROM stop_times
WHERE departure_time >= '24:00:00';

SELECT stop_id, stop_name
FROM stops
WHERE stop_name LIKE '%ā%'
LIMIT 5;

SELECT stop_id,
       stop_name,
       CHAR_LENGTH(stop_name) AS chars,
       LENGTH(stop_name)      AS bytes
FROM stops
WHERE LENGTH(stop_name) > CHAR_LENGTH(stop_name)
LIMIT 10;