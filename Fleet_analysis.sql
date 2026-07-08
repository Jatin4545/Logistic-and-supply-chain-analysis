/*======================================================================================================================
  PROJECT: Supply Chain & Logistics Operations Analytics
  MODULE : Fleet Dashboard SQL Views
  AUTHOR : Jatin
  DATABASE: SQL Server

  OBJECTIVE
  ---------------------------------------------------------------------------------------------------------------
  Build reusable SQL views for the Fleet Analytics dashboard in Power BI.

  These views are designed to support monthly fleet monitoring and answer business questions such as:
  1. How many trips, miles, and fuel are consumed by each truck?
  2. Which trucks are driving high maintenance cost, downtime, and incident risk?
  3. Which trucks are idle / underutilized but still generating maintenance or fuel cost?
  4. How do fleet KPIs trend by truck, month, and year?
  5. Which trucks should be prioritized for replacement based on age, maintenance burden,
     downtime, fuel efficiency, and safety incidents?

  FINAL VIEWS INCLUDED
  ---------------------------------------------------------------------------------------------------------------
  1. vw_truck_trip_summary
     - Truck-level trip, mileage, fuel and MPG summary.

  2. vw_truck_maintenance_summary
     - Truck-level maintenance events, maintenance cost, labor/parts split, downtime.

  3. vw_truck_incident_summary
     - Truck-level incident, claim and damage summary.

  4. vw_idle_truck_diagnostic
     - Trucks with zero trips, used to identify idle trucks still generating cost.

  5. vw_fleet_dashboard_monthly
     - Main monthly fleet fact view for Power BI slicers (year / month / truck).

  6. vw_fleet_replacement_score
     - Truck replacement / fleet risk scoring view based on cost, downtime, MPG and incidents.

  NOTES
  ---------------------------------------------------------------------------------------------------------------
  - This script intentionally excludes exploratory one-off analysis queries.
  - Only reusable production-style views are retained for the final dashboard.
  - Monthly view is the primary source for most Fleet dashboard visuals and KPI cards.
======================================================================================================================*/


/*======================================================================================================================
  OPTIONAL PERFORMANCE INDEXES
  ---------------------------------------------------------------------------------------------------------------
  These indexes improve joins and aggregations on truck-level fleet reporting queries.
  Run once if they do not already exist.
======================================================================================================================*/

CREATE INDEX IX_trips_truck_id
ON trips(truck_id);

CREATE INDEX IX_maintenance_records_truck_id
ON maintenance_records(truck_id)
INCLUDE(total_cost, labor_cost, parts_cost, downtime_hours, maintenance_date);

CREATE INDEX IX_fuel_purchases_truck_id
ON fuel_purchases(truck_id)
INCLUDE(total_cost, fuel_in_liter, purchase_date);

CREATE INDEX IX_safety_incidents_truck_id
ON safety_incidents(truck_id)
INCLUDE(claim_amount, vehicle_damage_cost, cargo_damage_cost, incident_date);



/*======================================================================================================================
  VIEW 1: vw_truck_trip_summary
  ---------------------------------------------------------------------------------------------------------------
  PURPOSE
  - Create a truck-level trip performance summary.
  - Used to measure truck activity, miles, fuel consumption, weighted MPG and trip volume.

  BUSINESS USE
  - Active trucks
  - Total trips by truck
  - Total miles by truck
  - Weighted MPG / fuel efficiency analysis
  - Base input for replacement scoring and monthly fleet analysis
======================================================================================================================*/

DROP VIEW IF EXISTS vw_truck_trip_summary;
GO

CREATE VIEW vw_truck_trip_summary AS
SELECT
    t.truck_id,
    COUNT(DISTINCT t.trip_id) AS trip_count,
    SUM(ISNULL(t.actual_distance_miles, 0)) AS total_miles,
    SUM(ISNULL(t.actual_duration_hours, 0)) AS total_duration_hours,
    SUM(ISNULL(t.fuel_consumed, 0)) AS total_fuel_gallons,

    CASE
        WHEN SUM(ISNULL(t.fuel_consumed, 0)) = 0 THEN NULL
        ELSE SUM(ISNULL(t.actual_distance_miles, 0)) * 1.0
             / SUM(ISNULL(t.fuel_consumed, 0))
    END AS weighted_mpg,

    AVG(CAST(t.actual_distance_miles AS FLOAT)) AS avg_trip_distance,
    AVG(CAST(t.actual_duration_hours AS FLOAT)) AS avg_trip_duration
FROM trips t
GROUP BY t.truck_id;
GO



/*======================================================================================================================
  VIEW 2: vw_truck_maintenance_summary
  ---------------------------------------------------------------------------------------------------------------
  PURPOSE
  - Create a truck-level maintenance summary across all maintenance events.

  BUSINESS USE
  - Total maintenance cost by truck
  - Downtime by truck
  - Maintenance event frequency
  - Cost split into labor and parts
  - Input for truck health / replacement analysis
======================================================================================================================*/

DROP VIEW IF EXISTS vw_truck_maintenance_summary;
GO

CREATE VIEW vw_truck_maintenance_summary AS
SELECT
    m.truck_id,
    COUNT(*) AS maintenance_event_count,
    SUM(ISNULL(m.total_cost, 0)) AS total_maintenance_cost,
    SUM(ISNULL(m.labor_cost, 0)) AS total_labor_cost,
    SUM(ISNULL(m.parts_cost, 0)) AS total_parts_cost,
    SUM(ISNULL(m.downtime_hours, 0)) AS total_downtime_hours,
    AVG(CAST(m.total_cost AS FLOAT)) AS avg_maintenance_cost,
    MAX(m.maintenance_date) AS last_maintenance_date
FROM maintenance_records m
GROUP BY m.truck_id;
GO



/*======================================================================================================================
  VIEW 3: vw_truck_incident_summary
  ---------------------------------------------------------------------------------------------------------------
  PURPOSE
  - Create a truck-level safety and claim summary from incident records.

  BUSINESS USE
  - Incident count by truck
  - At-fault / preventable / injury incidents
  - Total vehicle damage, cargo damage and claim amount
  - Input for fleet risk and replacement prioritization
======================================================================================================================*/

DROP VIEW IF EXISTS vw_truck_incident_summary;
GO

CREATE VIEW vw_truck_incident_summary AS
SELECT
    s.truck_id,
    COUNT(*) AS incident_count,
    SUM(CASE WHEN s.at_fault_flag = 1 THEN 1 ELSE 0 END) AS at_fault_incident_count,
    SUM(CASE WHEN s.preventable_flag = 1 THEN 1 ELSE 0 END) AS preventable_incident_count,
    SUM(CASE WHEN s.injury_flag = 1 THEN 1 ELSE 0 END) AS injury_incident_count,
    SUM(ISNULL(s.vehicle_damage_cost, 0)) AS total_vehicle_damage_cost,
    SUM(ISNULL(s.cargo_damage_cost, 0)) AS total_cargo_damage_cost,
    SUM(ISNULL(s.claim_amount, 0)) AS total_claim_amount
FROM safety_incidents s
WHERE s.truck_id IS NOT NULL
GROUP BY s.truck_id;
GO



/*======================================================================================================================
  VIEW 4: vw_idle_truck_diagnostic
  ---------------------------------------------------------------------------------------------------------------
  PURPOSE
  - Identify trucks with zero recorded trips.
  - Diagnose whether idle trucks still incur maintenance or fuel costs.

  BUSINESS USE
  - Underutilized / non-operating trucks
  - Trucks with no trips but maintenance spend
  - Trucks with no trips but fuel transactions
  - Useful for utilization audits and asset rationalization
======================================================================================================================*/

DROP VIEW IF EXISTS vw_idle_truck_diagnostic;
GO

CREATE VIEW vw_idle_truck_diagnostic AS
WITH fuel_summary AS (
    SELECT
        fp.truck_id,
        COUNT(*) AS fuel_txn_count,
        SUM(ISNULL(fp.total_cost, 0)) AS total_fuel_cost,
        SUM(ISNULL(fp.fuel_in_liter, 0)) AS total_fuel_liters
    FROM fuel_purchases fp
    GROUP BY fp.truck_id
)
SELECT
    t.truck_id,
    t.status,
    t.model_year,
    t.acquisition_date,

    ISNULL(ts.trip_count, 0) AS trip_count,

    ISNULL(ms.maintenance_event_count, 0) AS maintenance_event_count,
    ISNULL(ms.total_maintenance_cost, 0) AS total_maintenance_cost,
    ISNULL(ms.total_downtime_hours, 0) AS total_downtime_hours,

    ISNULL(fs.fuel_txn_count, 0) AS fuel_txn_count,
    ISNULL(fs.total_fuel_cost, 0) AS total_fuel_cost,
    ISNULL(fs.total_fuel_liters, 0) AS total_fuel_liters
FROM trucks t
LEFT JOIN vw_truck_trip_summary ts
    ON t.truck_id = ts.truck_id
LEFT JOIN vw_truck_maintenance_summary ms
    ON t.truck_id = ms.truck_id
LEFT JOIN fuel_summary fs
    ON t.truck_id = fs.truck_id
WHERE ISNULL(ts.trip_count, 0) = 0;
GO



/*======================================================================================================================
  VIEW 5: vw_fleet_dashboard_monthly
  ---------------------------------------------------------------------------------------------------------------
  PURPOSE
  - Create the main monthly fleet dashboard dataset.
  - Aggregates truck-level monthly activity across trips, fuel, maintenance and incidents.

  BUSINESS USE
  - Fleet dashboard slicers by Year / Month / Truck
  - KPI cards: Active trucks, Utilization, Avg MPG, Maintenance Cost/Truck, Fuel Cost/Mile, Downtime
  - Charts: trip trend, fuel efficiency, maintenance cost trend, truck age analysis, route/fleet operations

  DESIGN NOTES
  - The view creates a unified truck-month grain using the union of all truck-month combinations
    present in trips, fuel, maintenance and incident tables.
  - This avoids losing months where a truck had maintenance or incidents but no trips.
======================================================================================================================*/

DROP VIEW IF EXISTS vw_fleet_dashboard_monthly;
GO

CREATE VIEW vw_fleet_dashboard_monthly AS

WITH truck_base AS (
    SELECT
        t.truck_id,
        t.model_year,
        t.acquisition_date,
        t.acquisition_mileage,
        t.fuel_type,
        t.status
    FROM trucks t
),

/*------------------------------------------
  Monthly trip metrics by truck
-------------------------------------------*/
trip_summary AS (
    SELECT
        tr.truck_id,
        YEAR(tr.dispatch_date) AS [year],
        MONTH(tr.dispatch_date) AS [month],
        COUNT(tr.trip_id) AS total_trips,
        SUM(ISNULL(tr.actual_distance_miles, 0)) AS total_miles,
        SUM(ISNULL(tr.actual_duration_hours, 0)) AS total_duration_hours,
        SUM(ISNULL(tr.fuel_consumed, 0)) AS total_fuel_gallons,
        AVG(CAST(tr.average_mpg AS FLOAT)) AS avg_mpg,
        AVG(CAST(tr.idle_time_hours AS FLOAT)) AS avg_idle_hours
    FROM trips tr
    GROUP BY tr.truck_id, YEAR(tr.dispatch_date), MONTH(tr.dispatch_date)
),

/*------------------------------------------
  Monthly fuel metrics by truck
-------------------------------------------*/
fuel_summary AS (
    SELECT
        fp.truck_id,
        YEAR(fp.purchase_date) AS [year],
        MONTH(fp.purchase_date) AS [month],
        COUNT(fp.fuel_purchase_id) AS fuel_purchase_count,
        SUM(ISNULL(fp.fuel_in_liter, 0)) AS total_fuel_liters,
        SUM(ISNULL(fp.total_cost, 0)) AS total_fuel_cost
    FROM fuel_purchases fp
    GROUP BY fp.truck_id, YEAR(fp.purchase_date), MONTH(fp.purchase_date)
),

/*------------------------------------------
  Monthly maintenance metrics by truck
-------------------------------------------*/
maintenance_summary AS (
    SELECT
        mr.truck_id,
        YEAR(mr.maintenance_date) AS [year],
        MONTH(mr.maintenance_date) AS [month],
        COUNT(mr.maintenance_id) AS maintenance_events,
        SUM(ISNULL(mr.total_cost, 0)) AS total_maintenance_cost,
        SUM(ISNULL(mr.labor_cost, 0)) AS total_labor_cost,
        SUM(ISNULL(mr.parts_cost, 0)) AS total_parts_cost,
        SUM(ISNULL(mr.downtime_hours, 0)) AS total_downtime_hours
    FROM maintenance_records mr
    GROUP BY mr.truck_id, YEAR(mr.maintenance_date), MONTH(mr.maintenance_date)
),

/*------------------------------------------
  Monthly incident metrics by truck
-------------------------------------------*/
incident_summary AS (
    SELECT
        si.truck_id,
        YEAR(si.incident_date) AS [year],
        MONTH(si.incident_date) AS [month],
        COUNT(si.incident_id) AS incident_count,
        SUM(ISNULL(si.claim_amount, 0)) AS total_claim_amount
    FROM safety_incidents si
    WHERE si.truck_id IS NOT NULL
    GROUP BY si.truck_id, YEAR(si.incident_date), MONTH(si.incident_date)
),

/*------------------------------------------
  Build a complete truck-month spine
  so that a truck-month is retained even
  if activity exists in only one source table
-------------------------------------------*/
all_truck_months AS (
    SELECT truck_id, [year], [month] FROM trip_summary
    UNION
    SELECT truck_id, [year], [month] FROM fuel_summary
    UNION
    SELECT truck_id, [year], [month] FROM maintenance_summary
    UNION
    SELECT truck_id, [year], [month] FROM incident_summary
),

/*------------------------------------------
  Join all monthly truck metrics into one row
-------------------------------------------*/
base AS (
    SELECT
        tm.truck_id,
        tm.[year],
        tm.[month],

        tb.model_year,
        tb.acquisition_date,
        tb.acquisition_mileage,
        tb.fuel_type,
        tb.status,

        ISNULL(ts.total_trips, 0) AS total_trips,
        ISNULL(ts.total_miles, 0) AS total_miles,
        ISNULL(ts.total_duration_hours, 0) AS total_duration_hours,
        ISNULL(ts.total_fuel_gallons, 0) AS total_fuel_gallons,
        ts.avg_mpg,
        ts.avg_idle_hours,

        ISNULL(fs.fuel_purchase_count, 0) AS fuel_purchase_count,
        ISNULL(fs.total_fuel_liters, 0) AS total_fuel_liters,
        ISNULL(fs.total_fuel_cost, 0) AS total_fuel_cost,

        ISNULL(ms.maintenance_events, 0) AS maintenance_events,
        ISNULL(ms.total_maintenance_cost, 0) AS total_maintenance_cost,
        ISNULL(ms.total_labor_cost, 0) AS total_labor_cost,
        ISNULL(ms.total_parts_cost, 0) AS total_parts_cost,
        ISNULL(ms.total_downtime_hours, 0) AS total_downtime_hours,

        ISNULL(ins.incident_count, 0) AS incident_count,
        ISNULL(ins.total_claim_amount, 0) AS total_claim_amount

    FROM all_truck_months tm
    LEFT JOIN truck_base tb
        ON tm.truck_id = tb.truck_id
    LEFT JOIN trip_summary ts
        ON tm.truck_id = ts.truck_id
       AND tm.[year] = ts.[year]
       AND tm.[month] = ts.[month]
    LEFT JOIN fuel_summary fs
        ON tm.truck_id = fs.truck_id
       AND tm.[year] = fs.[year]
       AND tm.[month] = fs.[month]
    LEFT JOIN maintenance_summary ms
        ON tm.truck_id = ms.truck_id
       AND tm.[year] = ms.[year]
       AND tm.[month] = ms.[month]
    LEFT JOIN incident_summary ins
        ON tm.truck_id = ins.truck_id
       AND tm.[year] = ins.[year]
       AND tm.[month] = ins.[month]
)

SELECT
    b.truck_id,
    b.[year],
    b.[month],
    DATEFROMPARTS(b.[year], b.[month], 1) AS month_start_date,

    b.model_year,
    b.acquisition_date,
    b.acquisition_mileage,
    b.fuel_type,
    b.status,

    b.total_trips,
    b.total_miles,
    b.total_duration_hours,
    b.total_fuel_gallons,
    b.avg_mpg,
    b.avg_idle_hours,

    b.fuel_purchase_count,
    b.total_fuel_liters,
    b.total_fuel_cost,

    b.maintenance_events,
    b.total_maintenance_cost,
    b.total_labor_cost,
    b.total_parts_cost,
    b.total_downtime_hours,

    b.incident_count,
    b.total_claim_amount,

    DATEDIFF(YEAR, b.acquisition_date, DATEFROMPARTS(b.[year], b.[month], 1)) AS truck_age,

    CAST(b.total_fuel_cost * 1.0 / NULLIF(b.total_miles, 0) AS DECIMAL(18,2)) AS fuel_cost_per_mile,
    CAST(b.total_maintenance_cost * 1.0 / NULLIF(b.total_trips, 0) AS DECIMAL(18,2)) AS maintenance_cost_per_trip,
    CAST(b.total_maintenance_cost * 1000.0 / NULLIF(b.total_miles, 0) AS DECIMAL(18,2)) AS maintenance_cost_per_1000_miles,
    CAST(b.total_downtime_hours * 1.0 / NULLIF(b.total_trips, 0) AS DECIMAL(18,2)) AS downtime_per_trip,
    CAST(b.incident_count * 100.0 / NULLIF(b.total_trips, 0) AS DECIMAL(18,2)) AS incident_rate_per_100_trips
FROM base b;
GO



/*======================================================================================================================
  VIEW 6: vw_fleet_replacement_score
  ---------------------------------------------------------------------------------------------------------------
  PURPOSE
  - Create a truck-level fleet replacement / risk score.
  - Scores trucks using age, maintenance burden, downtime, MPG and incident rate.

  BUSINESS USE
  - Identify high-risk trucks
  - Prioritize trucks for preventive action or replacement
  - Support fleet risk table / top risky trucks visual in Power BI

  SCORING LOGIC
  ---------------------------------------------------------------------------------------------------------------
  +1  if truck age > 7 years
  +2  if maintenance cost per 1000 miles is above fleet average
  +2  if downtime per trip is above fleet average
  +1  if MPG is below fleet average
  +3  if incident rate per 100 trips is above fleet average

  Higher score = higher replacement / risk priority
======================================================================================================================*/

DROP VIEW IF EXISTS vw_fleet_replacement_score;
GO

CREATE VIEW vw_fleet_replacement_score AS
WITH base AS (
    SELECT *
    FROM vw_fleet_dashboard_monthly
),
fleet_avg AS (
    SELECT
        AVG(CAST(maintenance_cost_per_1000_miles AS FLOAT)) AS avg_maint_per_1000,
        AVG(CAST(downtime_per_trip AS FLOAT)) AS avg_downtime_per_trip,
        AVG(CAST(avg_mpg AS FLOAT)) AS avg_mpg,
        AVG(CAST(incident_rate_per_100_trips AS FLOAT)) AS avg_incident_rate
    FROM base
    WHERE total_trips > 0
)
SELECT
    b.*,
    (
        CASE WHEN b.truck_age > 7 THEN 1 ELSE 0 END +
        CASE WHEN b.maintenance_cost_per_1000_miles > f.avg_maint_per_1000 THEN 2 ELSE 0 END +
        CASE WHEN b.downtime_per_trip > f.avg_downtime_per_trip THEN 2 ELSE 0 END +
        CASE WHEN b.avg_mpg < f.avg_mpg THEN 1 ELSE 0 END +
        CASE WHEN b.incident_rate_per_100_trips > f.avg_incident_rate THEN 3 ELSE 0 END
    ) AS fleet_risk_score
FROM base b
CROSS JOIN fleet_avg f;
GO
