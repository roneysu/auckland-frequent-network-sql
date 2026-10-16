-- 07a_official_list.sql
-- Official AT frequent route list, copied by hand from:
-- https://at.govt.nz/bus-train-ferry/bus-services/frequent-buses-on-key-routes
-- Page says "Last updated 11/06/2026". Copied 2026-10-15, 57 entries.
-- Official promise: every 15 min, 7am-7pm, 7 days a week.
-- Branches (e.g. 22N, 22R) are listed as separate entries on the page.
-- Descriptions are ASCII (macrons dropped) except route name TāmakiLink, kept as on the page.

DROP TABLE IF EXISTS official_frequent;

CREATE TABLE official_frequent (
    route_short_name VARCHAR(20) NOT NULL,
    area VARCHAR(20) NOT NULL,
    description VARCHAR(100) NULL,
    PRIMARY KEY (route_short_name)
);

INSERT INTO official_frequent (route_short_name, area, description) VALUES
('82', 'North', 'Milford to Mayoral Drive'),
('83', 'North', 'Massey University to Takapuna'),
('94', 'North', 'Beach Haven to Takapuna'),
('95B', 'North', 'Glenfield to City Centre (Lower Albert Street)'),
('95C', 'North', 'Glenfield to City Centre (Lower Albert Street)'),
('97B', 'North', 'Beach Haven to City Centre (Lower Albert Street)'),
('97R', 'North', 'Beach Haven to City Centre (Lower Albert Street)'),
('NX1', 'North', 'Albany Bus Station to City Centre (Lower Albert Street)'),
('NX2', 'North', 'Albany Bus Station to City Centre (Auckland Universities)'),
('20', 'Central', 'St Lukes to City Centre (Wynyard Quarter)'),
('22N', 'Central', 'New Lynn to City Centre (Victoria Street)'),
('22R', 'Central', 'Avondale to City Centre (Victoria Street)'),
('24B', 'Central', 'Sandringham to City Centre (Victoria Street)'),
('24R', 'Central', 'Sandringham to City Centre (Victoria Street)'),
('25B', 'Central', 'Mt Roskill to City Centre (Aotea Square)'),
('25L', 'Central', 'Mt Roskill to City Centre (Aotea Square)'),
('27H', 'Central', 'Three Kings to City Centre (Waitemata Station)'),
('27W', 'Central', 'Three Kings to City Centre (Waitemata Station)'),
('27T', 'Central', 'Three Kings to City Centre (Waitemata Station)'),
('30', 'Central', 'Onehunga to City Centre (The Civic)'),
('64', 'Central', 'St Lukes to Newmarket'),
('65', 'Central', 'Pt Chevalier to Glen Innes'),
('66', 'Central', 'Pt Chevalier to Sylvia Park'),
('67A', 'Central', 'New Lynn to Onehunga'),
('67B', 'Central', 'New Lynn to Onehunga'),
('68', 'Central', 'New Lynn to Onehunga'),
('74', 'Central', 'Onehunga to Glen Innes'),
('75', 'Central', 'Glen Innes to City Centre (Wynyard Quarter)'),
('76', 'Central', 'Glen Innes to City Centre (Fort Street)'),
('InnerLink', 'Central', NULL),
('TāmakiLink', 'Central', NULL),
('CityLink', 'Central', NULL),
('OuterLink', 'Central', NULL),
('50A', 'Waiheke', 'Matiatia Wharf to Onetangi'),
('50B', 'Waiheke', 'Matiatia Wharf to Onetangi'),
('70', 'East', 'Botany to City Centre (Waitemata)'),
('72C', 'East', 'Botany to Panmure'),
('72M', 'East', 'Botany to Panmure'),
('72X', 'East', 'Botany to City Centre (Waitemata)'),
('11T', 'West', 'Northwest Centre to City Centre (Queen St)'),
('11W', 'West', 'Northwest Centre to City Centre (Queen St)'),
('12', 'West', 'Henderson to Constellation Station'),
('13', 'West', 'Henderson to Te Atatu Peninsula loop'),
('14', 'West', 'Lincoln Bus Interchange to New Lynn'),
('15', 'West', 'Henderson to New Lynn'),
('17', 'West', 'Glen Eden to New Lynn'),
('18', 'West', 'New Lynn to City Centre (Vulcan Lane)'),
('WX1', 'West', 'Northwest Centre to City Centre (Vulcan Lane)'),
('31', 'South', 'Mangere to Botany'),
('32', 'South', 'Mangere to Sylvia Park'),
('33', 'South', 'Papakura to Otahuhu Station'),
('35', 'South', 'Botany to Manukau'),
('36', 'South', 'Manukau to Onehunga'),
('37', 'South', 'Manurewa to Highbrook'),
('38', 'South', 'Onehunga to Airport'),
('39', 'South', 'Manurewa to Otara/MIT'),
('AirportLink', 'South', NULL);

-- Check: should return 57, then 6 area groups (North 9, Central 24, Waiheke 2, East 4, West 9, South 9)
SELECT COUNT(*) AS n FROM official_frequent;
SELECT area, COUNT(*) AS n FROM official_frequent GROUP BY area;


-- Compare the routes identified as meeting the criteria against the list of high-frequency routes officially published by Auckland Transport. --

DROP VIEW IF EXISTS our_frequecy;

CREATE VIEW our_frequecy AS
SELECT r.route_short_name
FROM v_route_gap_a vga
JOIN routes r ON vga.route_id = r.route_id
WHERE frequency_check = 'OK'
GROUP BY r.route_short_name
HAVING COUNT(vga.date) = 3;

SELECT ofy.route_short_name, 'BOTH' AS status
FROM our_frequecy ofy 
JOIN official_frequent oft ON ofy.route_short_name = oft.route_short_name
UNION ALL
SELECT oft1.route_short_name, 'Official_ok'
FROM official_frequent oft1 LEFT JOIN our_frequecy ofy1 ON ofy1.route_short_name = oft1.route_short_name
WHERE ofy1.route_short_name IS NULL
UNION ALL
SELECT ofy2.route_short_name, 'Our_ok'
FROM our_frequecy ofy2 LEFT JOIN official_frequent oft2 ON ofy2.route_short_name = oft2.route_short_name
WHERE oft2.route_short_name IS NULL;


SELECT oft.route_short_name
FROM official_frequent oft LEFT JOIN routes r ON oft.route_short_name = r.route_short_name
WHERE r.route_short_name IS NULL;

SELECT
    oft.route_short_name,
    oft.area,
    MAX(CASE WHEN ad.day_type = 'Weekday'  THEN vga.max_interval END) AS weekday_max_gap,
    MAX(CASE WHEN ad.day_type = 'Saturday' THEN vga.max_interval END) AS saturday_max_gap,
    MAX(CASE WHEN ad.day_type = 'Sunday'   THEN vga.max_interval END) AS sunday_max_gap
FROM official_frequent oft
JOIN routes r ON r.route_short_name = oft.route_short_name
LEFT JOIN v_route_gap_a vga ON vga.route_id = r.route_id
LEFT JOIN analysis_days ad ON ad.date = vga.date
WHERE NOT EXISTS (
    SELECT 1
    FROM our_frequecy vf
    WHERE vf.route_short_name = oft.route_short_name
)
GROUP BY oft.route_short_name, oft.area
ORDER BY weekday_max_gap DESC;



-- branch check --
-- written by claude--
-- 07b_branch_check.sql
-- Hypothesis: many official "frequent" routes are branches of one corridor
-- (e.g. 95B + 95C). Each branch runs about every 30 min, together about every 15 min.
-- Test: merge the origin departures of all branches in a group, then redo definition A.
-- Branch groups below were read by hand from the official AT list (same endpoints on the page).
-- Caveat: 22N starts at New Lynn and 22R at Avondale (different origins), so group 22
-- is only an approximation. 72X is kept separate, as on the official list.

DROP TABLE IF EXISTS branch_group;

CREATE TABLE branch_group (
    route_short_name VARCHAR(20) NOT NULL,
    group_name VARCHAR(20) NOT NULL,
    PRIMARY KEY (route_short_name)
);

INSERT INTO branch_group (route_short_name, group_name) VALUES
('11T', '11'), ('11W', '11'),
('22N', '22'), ('22R', '22'),
('24B', '24'), ('24R', '24'),
('25B', '25'), ('25L', '25'),
('27H', '27'), ('27T', '27'), ('27W', '27'),
('50A', '50'), ('50B', '50'),
('67A', '67'), ('67B', '67'),
('72C', '72'), ('72M', '72'),
('95B', '95'), ('95C', '95'),
('97B', '97'), ('97R', '97');

DROP VIEW IF EXISTS v_group_gap_a;

CREATE VIEW v_group_gap_a AS
WITH merged AS (
    SELECT
        bg.group_name,
        tsd.direction_id,
        tsd.date,
        tsd.departure_time,
        LAG(tsd.departure_time) OVER (
            PARTITION BY bg.group_name, tsd.direction_id, tsd.date
            ORDER BY tsd.departure_time
        ) AS prev_time
    FROM trip_stop_departures tsd
    JOIN routes r ON r.route_id = tsd.route_id
    JOIN branch_group bg ON bg.route_short_name = r.route_short_name
    WHERE tsd.is_origin = 1
      AND tsd.departure_time >= '07:00:00'
      AND tsd.departure_time < '19:00:00'
)
SELECT
    group_name,
    date,
    MAX(TIME_TO_SEC(departure_time) - TIME_TO_SEC(prev_time)) / 60 AS max_interval
FROM merged
GROUP BY group_name, date;

-- Result: max gap per group and day type (OK means 15 or less)
SELECT
    g.group_name,
    MAX(CASE WHEN ad.day_type = 'Weekday'  THEN g.max_interval END) AS weekday_max_gap,
    MAX(CASE WHEN ad.day_type = 'Saturday' THEN g.max_interval END) AS saturday_max_gap,
    MAX(CASE WHEN ad.day_type = 'Sunday'   THEN g.max_interval END) AS sunday_max_gap
FROM v_group_gap_a g
JOIN analysis_days ad ON ad.date = g.date
GROUP BY g.group_name
ORDER BY weekday_max_gap DESC;