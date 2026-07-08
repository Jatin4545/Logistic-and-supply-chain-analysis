/* =====================================================================================================
   DASHBOARD 2 — DRIVER PERFORMANCE
   EXPLORATORY ANALYSIS QUERIES

   OBJECTIVE:
   These queries are exploratory analysis queries used to evaluate driver productivity,
   service performance, utilization, and safety before building the Driver Performance dashboard.

   BUSINESS QUESTIONS COVERED:
   1. How many drivers are actively operating in the network?
   2. Which drivers handle the most trips and generate the most revenue?
   3. Which drivers have the strongest or weakest on-time delivery performance?
   4. Which drivers accumulate the most idle time and may have productivity issues?
   5. Which drivers are associated with the highest incident count and claim exposure?
   6. How does driver activity trend month by month across trips, miles, and idle time?

   DASHBOARD USE:
   The output of these queries helps validate the KPI logic for the Driver Performance dashboard
   and identify which operational dimensions should be highlighted in visuals and scorecards.
===================================================================================================== */


-- ============================================================================================
-- 1) Active drivers
-- Purpose:
-- Count how many drivers actually completed at least one trip.
-- This gives the true active driver base instead of total headcount in the drivers table.
-- ============================================================================================
SELECT
    COUNT(DISTINCT driver_id) AS active_drivers
FROM trips
WHERE driver_id IS NOT NULL;


-- ============================================================================================
-- 2) Trips and revenue by driver
-- Purpose:
-- Evaluate driver productivity and revenue contribution by combining trip volume
-- with revenue generated from the loads assigned to those trips.
-- Useful for identifying high-output vs low-output drivers.
-- ============================================================================================
SELECT
    t.driver_id,
    COUNT(t.trip_id) AS total_trips,
    SUM(l.revenue) AS total_revenue,
    ROUND(AVG(l.revenue), 2) AS avg_revenue_per_trip
FROM trips t
LEFT JOIN loads l
    ON t.load_id = l.load_id
WHERE t.driver_id IS NOT NULL
GROUP BY t.driver_id
ORDER BY total_revenue DESC;


-- ============================================================================================
-- 3) On-time delivery % by driver
-- Purpose:
-- Measure service performance at the driver level by calculating each driver’s
-- on-time delivery percentage across completed delivery events.
-- This helps distinguish reliable drivers from service-risk drivers.
-- ============================================================================================
SELECT
    t.driver_id,
    COUNT(*) AS total_deliveries,
    SUM(CASE WHEN d.actual_datetime <= d.scheduled_datetime THEN 1 ELSE 0 END) AS on_time_deliveries,
    ROUND(
        100.0 * SUM(CASE WHEN d.actual_datetime <= d.scheduled_datetime THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS on_time_pct
FROM delivery_events d
JOIN trips t
    ON d.load_id = t.load_id
WHERE d.event_type = 'Delivery'
  AND t.driver_id IS NOT NULL
GROUP BY t.driver_id
ORDER BY on_time_pct DESC;


-- ============================================================================================
-- 4) Idle hours by driver
-- Purpose:
-- Measure how much non-productive idle time each driver accumulates.
-- High idle hours can indicate scheduling inefficiency, waiting time, poor route planning,
-- or low asset utilization.
-- ============================================================================================
SELECT
    driver_id,
    SUM(idle_time_hours) AS total_idle_hours,
    ROUND(AVG(idle_time_hours), 2) AS avg_idle_hours
FROM trips
WHERE driver_id IS NOT NULL
GROUP BY driver_id
ORDER BY total_idle_hours DESC;


-- ============================================================================================
-- 5) Incidents and claim exposure by driver
-- Purpose:
-- Evaluate driver-level safety risk using incident count and associated insurance / claim cost.
-- This helps identify drivers creating operational and financial risk for the business.
-- ============================================================================================
SELECT
    driver_id,
    COUNT(*) AS total_incidents,
    SUM(claim_amount) AS total_claim_amount
FROM safety_incidents
WHERE driver_id IS NOT NULL
GROUP BY driver_id
ORDER BY total_incidents DESC, total_claim_amount DESC;


-- ============================================================================================
-- 6) Monthly driver productivity trend
-- Purpose:
-- Analyze driver activity over time at a monthly level, including trip count,
-- miles driven, and average idle hours.
-- Useful for spotting utilization changes, productivity dips, and workload patterns.
-- ============================================================================================
SELECT
    YEAR(dispatch_date) AS year,
    MONTH(dispatch_date) AS month,
    driver_id,
    COUNT(trip_id) AS total_trips,
    SUM(actual_distance_miles) AS total_miles,
    ROUND(AVG(idle_time_hours), 2) AS avg_idle_hours
FROM trips
WHERE driver_id IS NOT NULL
GROUP BY YEAR(dispatch_date), MONTH(dispatch_date), driver_id
ORDER BY year, month, driver_id;
