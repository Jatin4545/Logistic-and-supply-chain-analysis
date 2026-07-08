/* =====================================================================================================
   DASHBOARD 3 — FLEET + ROUTE OPERATIONS
   EXPLORATORY ANALYSIS QUERIES

   OBJECTIVE:
   These exploratory queries are used to evaluate fleet utilization, truck efficiency,
   maintenance burden, safety exposure, and route-level operating concentration before
   building the Fleet + Route Operations dashboard.

   BUSINESS QUESTIONS COVERED:
   1. How many trucks are active versus idle in the fleet?
   2. Which trucks are completely underutilized and not generating trips?
   3. Which trucks are most fuel-efficient based on actual miles and fuel consumed?
   4. Which trucks create the highest maintenance cost and downtime burden?
   5. Is truck age associated with higher maintenance cost?
   6. Which trucks contribute the highest safety incident and claim exposure?
   7. Which routes carry the most freight revenue and operational volume?

   DASHBOARD USE:
   These queries help validate KPI definitions such as Active Trucks, Idle Trucks,
   Avg MPG, Maintenance Cost/Truck, Downtime, Incident Rate, and route concentration metrics.
===================================================================================================== */


-- ============================================================================================
-- 1) Active vs idle trucks
-- Purpose:
-- Measure overall fleet utilization by separating total trucks into active trucks
-- (at least one trip recorded) and idle trucks (no trip activity).
-- ============================================================================================
SELECT
    COUNT(*) AS total_trucks,
    COUNT(DISTINCT tr.truck_id) AS active_trucks,
    COUNT(*) - COUNT(DISTINCT tr.truck_id) AS idle_trucks
FROM trucks t
LEFT JOIN trips tr
    ON t.truck_id = tr.truck_id;


-- ============================================================================================
-- 2) Underutilized trucks (no trips)
-- Purpose:
-- Identify trucks with zero trip activity. These are underutilized or idle assets
-- and may represent excess capacity, retired units, or data-quality issues.
-- ============================================================================================
SELECT
    t.truck_id,
    t.status,
    t.model_year
FROM trucks t
LEFT JOIN trips tr
    ON t.truck_id = tr.truck_id
WHERE tr.truck_id IS NULL;


-- ============================================================================================
-- 3) Fuel efficiency by truck
-- Purpose:
-- Evaluate truck-level fuel efficiency using total miles driven and total fuel consumed.
-- Weighted MPG is more reliable than averaging trip-level MPG because it reflects actual usage volume.
-- ============================================================================================
SELECT
    truck_id,
    COUNT(trip_id) AS total_trips,
    SUM(actual_distance_miles) AS total_miles,
    SUM(fuel_consumed) AS total_fuel,
    ROUND(
        SUM(actual_distance_miles) * 1.0 / NULLIF(SUM(fuel_consumed), 0),
        2
    ) AS weighted_mpg
FROM trips
GROUP BY truck_id
ORDER BY weighted_mpg DESC;


-- ============================================================================================
-- 4) Maintenance cost by truck
-- Purpose:
-- Measure maintenance burden at the truck level using total maintenance events,
-- maintenance cost, and downtime hours.
-- Useful for spotting high-cost and high-downtime assets.
-- ============================================================================================
SELECT
    truck_id,
    COUNT(*) AS maintenance_events,
    SUM(total_cost) AS total_maintenance_cost,
    SUM(downtime_hours) AS total_downtime_hours
FROM maintenance_records
GROUP BY truck_id
ORDER BY total_maintenance_cost DESC;


-- ============================================================================================
-- 5) Truck age vs maintenance cost
-- Purpose:
-- Evaluate whether older trucks are associated with higher maintenance cost.
-- This supports replacement planning and fleet renewal analysis.
-- ============================================================================================
SELECT
    t.truck_id,
    DATEDIFF(YEAR, t.acquisition_date, GETDATE()) AS truck_age,
    SUM(m.total_cost) AS total_maintenance_cost
FROM trucks t
LEFT JOIN maintenance_records m
    ON t.truck_id = m.truck_id
GROUP BY t.truck_id, t.acquisition_date
ORDER BY truck_age DESC, total_maintenance_cost DESC;


-- ============================================================================================
-- 6) Truck incidents and claim exposure
-- Purpose:
-- Measure truck-level safety exposure using incident count and total claim amount.
-- This helps identify fleet units associated with higher operational and financial risk.
-- ============================================================================================
SELECT
    truck_id,
    COUNT(*) AS total_incidents,
    SUM(claim_amount) AS total_claim_amount
FROM safety_incidents
WHERE truck_id IS NOT NULL
GROUP BY truck_id
ORDER BY total_incidents DESC, total_claim_amount DESC;


-- ============================================================================================
-- 7) Route revenue concentration
-- Purpose:
-- Identify routes carrying the highest load volume and freight revenue.
-- This is a route concentration view, not true route cost analysis.
-- ============================================================================================
SELECT
    route_id,
    COUNT(load_id) AS total_loads,
    SUM(revenue) AS total_revenue,
    ROUND(AVG(revenue), 2) AS avg_revenue_per_load
FROM loads
GROUP BY route_id
ORDER BY total_revenue DESC;
