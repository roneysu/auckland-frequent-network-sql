--CREATE DATABASE IF NOT EXISTS akl_gtfs CHARACTER SET utf8mb4;
--USE akl_gtfs;

-- create six tables --
-- create Table routes --

CREATE TABLE routes (
    route_id VARCHAR(255) NOT NULL,
    agency_id VARCHAR(255) ,
    route_short_name VARCHAR(255),
    route_long_name VARCHAR(255),
    route_desc VARCHAR(255),
    route_type INT,
    route_url VARCHAR(255),
    route_color VARCHAR(255),
    route_text_color VARCHAR(255),
    route_sort_order INT,
    contract_id VARCHAR(255),
    PRIMARY KEY (route_id)
);

-- create Table trips--

CREATE TABLE trips (
    route_id VARCHAR(255) ,
    service_id VARCHAR(255),
    trip_id VARCHAR(255) NOT NULL,
    trip_headsign VARCHAR(255),
    trip_short_name VARCHAR(255),
    direction_id INT,
    block_id VARCHAR(255),
    shape_id VARCHAR(255),
    wheelchair_accessible INT,
    bikes_allowed INT,
    PRIMARY KEY (trip_id)
);

-- create Table stop_times--

CREATE TABLE stop_times (
    trip_id VARCHAR(255) NOT NULL,
    stop_sequence INT NOT NULL ,
    arrival_time TIME,
    departure_time TIME,
    stop_id VARCHAR(255),
    stop_headsign VARCHAR(255),
    pickup_type INT,
    drop_off_type INT,
    shape_dist_traveled DECIMAL(10,4),
    timepoint INT,
    PRIMARY KEY (trip_id, stop_sequence)
);

-- create Table stops--

CREATE TABLE stops (
    stop_id VARCHAR(255) NOT NULL,
    stop_code VARCHAR(255),
    stop_name VARCHAR(255),
    stop_desc VARCHAR(255),
    stop_lat DECIMAL(9,6),
    stop_lon DECIMAL(9,6),
    zone_id VARCHAR(20),
    stop_url VARCHAR(255),
    location_type INT,
    parent_station VARCHAR(255),
    stop_timezone VARCHAR(64),
    platform_code VARCHAR(10),
    wheelchair_boarding INT,
    `start_date` Date,
    end_date Date,
    PRIMARY KEY (stop_id)
);

-- create Table calendar--

CREATE TABLE calendar (
    service_id VARCHAR(255) NOT NULL,
    monday INT,
    tuesday INT,
    wednesday INT,
    thursday INT,
    friday INT,
    saturday INT,
    sunday INT,
    `start_date` Date,
    end_date Date,
    PRIMARY KEY (service_id)
);

-- create Table calendar_dates--

CREATE TABLE calendar_dates (
    service_id VARCHAR(255) NOT NULL,
    `date` Date,
    exception_type INT,
    PRIMARY KEY (service_id, `date`)
);


SHOW TABLES;

DESCRIBE stop_times;