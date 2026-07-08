/*==================================================================================================================
  PROJECT: Supply Chain & Logistics Operations Analytics
  DASHBOARD: Driver Performance Dashboard
  DATABASE: SQL Server

  OBJECTIVE
  ---------
  Build a monthly driver-performance data model for Power BI that supports Year / Month slicers
  and enables analysis of driver productivity, revenue contribution, delivery performance,
  idle time, and safety incidents.

  BUSINESS QUESTIONS ANSWERED
  ---------------------------
  1. How many trips does each driver complete by month?
  2. Which drivers generate the most revenue and revenue per mile?
  3. Which drivers have better or worse on-time delivery performance?
  4. Which drivers have high idle time or low operational productivity?
  5. Which drivers are linked to more safety incidents and insurance claims?
  6. How does driver performance change over time by year and month?

  FINAL OUTPUT
  ------------
  Main dashboard view:
      vw_driver_dashboard_monthly

  Supporting views:
      vw_driver_trip_monthly
      vw_driver_revenue_monthly
      vw_driver_delivery_monthly
      vw_driver_incident_monthly
==================================================================================================================*/


/*==================================================================================================================
  VIEW 1: vw_driver_trip_monthly
  PURPOSE:
      Monthly trip productivity summary by driver.
      This view captures operational activity such as trips completed, total miles driven,
      and average idle hours.

  GRAIN:
      One row per driver per year per month
==================================================================================================================*/
DROP VIEW IF EXISTS vw_driver_trip_monthly;
GO

CREATE VIEW vw_driver_trip_monthly AS
SELECT
    YEAR(dispatch_date) AS [year],
    MONTH(dispatch_date) AS [month],
    driver_id,
    COUNT(trip_id) AS total_trips,
    SUM(ISNULL(actual_distance_miles, 0)) AS total_miles,
    ROUND(AVG(CAST(idle_time_hours AS FLOAT)), 2) AS avg_idle_hours
FROM trips
WHERE driver_id IS NOT NULL
GROUP BY
    YEAR(dispatch_date),
    MONTH(dispatch_date),
    driver_id;
GO


/*==================================================================================================================
  VIEW 2: vw_driver_revenue_monthly
  PURPOSE:
      Monthly revenue contribution by driver.
      Joins loads to trips so revenue can be attributed to the driver who handled the trip.

  METRICS:
      - total_revenue
      - avg_revenue_per_trip
      - revenue_per_mile

  GRAIN:
      One row per driver per year per month
==================================================================================================================*/
DROP VIEW IF EXISTS vw_driver_revenue_monthly;
GO

CREATE VIEW vw_driver_revenue_monthly AS
SELECT
    YEAR(l.load_date) AS [year],
    MONTH(l.load_date) AS [month],
    t.driver_id,
    SUM(ISNULL(l.revenue, 0)) AS total_revenue,
    COUNT(t.trip_id) AS total_trips_for_revenue,
    ROUND(AVG(CAST(l.revenue AS FLOAT)), 2) AS avg_revenue_per_trip,
    SUM(ISNULL(t.actual_distance_miles, 0)) AS total_miles_for_revenue,
    ROUND(
        SUM(ISNULL(l.revenue, 0)) * 1.0 /
        NULLIF(SUM(ISNULL(t.actual_distance_miles, 0)), 0),
        2
    ) AS revenue_per_mile
FROM loads l
LEFT JOIN trips t
    ON l.load_id = t.load_id
WHERE t.driver_id IS NOT NULL
GROUP BY
    YEAR(l.load_date),
    MONTH(l.load_date),
    t.driver_id;
GO


/*==================================================================================================================
  VIEW 3: vw_driver_delivery_monthly
  PURPOSE:
      Monthly delivery service performance by driver.
      Measures delivery execution quality using on-time vs late deliveries and detention time.

  LOGIC:
      - Only delivery events are included
      - A delivery is on-time if actual_datetime <= scheduled_datetime
      - A delivery is late if actual_datetime > scheduled_datetime

  GRAIN:
      One row per driver per year per month
==================================================================================================================*/
DROP VIEW IF EXISTS vw_driver_delivery_monthly;
GO

CREATE VIEW vw_driver_delivery_monthly AS
WITH delivery_events_flagged AS (
    SELECT
        YEAR(actual_datetime) AS [year],
        MONTH(actual_datetime) AS [month],
        load_id,
        detention_minutes,
        CASE WHEN actual_datetime <= scheduled_datetime THEN 1 ELSE 0 END AS on_time_delivery,
        CASE WHEN actual_datetime > scheduled_datetime THEN 1 ELSE 0 END AS late_delivery
    FROM delivery_events
    WHERE event_type = 'Delivery'
),
driver_delivery_base AS (
    SELECT
        d.[year],
        d.[month],
        t.driver_id,
        d.load_id,
        d.detention_minutes,
        d.on_time_delivery,
        d.late_delivery
    FROM delivery_events_flagged d
    INNER JOIN trips t
        ON d.load_id = t.load_id
    WHERE t.driver_id IS NOT NULL
)
SELECT
    [year],
    [month],
    driver_id,
    COUNT(load_id) AS total_deliveries,
    SUM(on_time_delivery) AS on_time_deliveries,
    SUM(late_delivery) AS late_deliveries,
    ROUND(
        SUM(on_time_delivery) * 100.0 / NULLIF(COUNT(load_id), 0),
        2
    ) AS on_time_delivery_pct,
    ROUND(AVG(CAST(detention_minutes AS FLOAT)), 2) AS avg_detention_minutes
FROM driver_delivery_base
GROUP BY
    [year],
    [month],
    driver_id;
GO


/*==================================================================================================================
  VIEW 4: vw_driver_incident_monthly
  PURPOSE:
      Monthly safety incident and insurance claim summary by driver.

  METRICS:
      - total_incidents
      - total_claim_amount

  GRAIN:
      One row per driver per year per month
==================================================================================================================*/
DROP VIEW IF EXISTS vw_driver_incident_monthly;
GO

CREATE VIEW vw_driver_incident_monthly AS
SELECT
    YEAR(incident_date) AS [year],
    MONTH(incident_date) AS [month],
    driver_id,
    COUNT(incident_id) AS total_incidents,
    SUM(ISNULL(claim_amount, 0)) AS total_claim_amount
FROM safety_incidents
WHERE driver_id IS NOT NULL
GROUP BY
    YEAR(incident_date),
    MONTH(incident_date),
    driver_id;
GO


/*==================================================================================================================
  VIEW 5: vw_driver_dashboard_monthly
  PURPOSE:
      Final monthly driver dashboard view for Power BI.
      Combines trip productivity, revenue, delivery performance, and incident metrics into
      a single driver-month fact view.

  WHY THIS VIEW MATTERS:
      This is the main source table for the Driver Performance dashboard.
      It supports KPI cards, trend visuals, ranking charts, driver matrices,
      and risk/performance segmentation.

  GRAIN:
      One row per driver per year per month
==================================================================================================================*/
DROP VIEW IF EXISTS vw_driver_dashboard_monthly;
GO

CREATE VIEW vw_driver_dashboard_monthly AS
WITH all_driver_months AS (
    SELECT driver_id, [year], [month] FROM vw_driver_trip_monthly
    UNION
    SELECT driver_id, [year], [month] FROM vw_driver_revenue_monthly
    UNION
    SELECT driver_id, [year], [month] FROM vw_driver_delivery_monthly
    UNION
    SELECT driver_id, [year], [month] FROM vw_driver_incident_monthly
)

SELECT
    adm.driver_id,
    adm.[year],
    adm.[month],
    DATEFROMPARTS(adm.[year], adm.[month], 1) AS month_start_date,

    -- Driver master attributes
    d.first_name,
    d.last_name,
    CONCAT(d.first_name, ' ', d.last_name) AS driver_name,
    d.hire_date,
    d.termination_date,
    d.home_terminal,
    d.driver_type,

    -- Driver tenure as of reporting month
    DATEDIFF(MONTH, d.hire_date, DATEFROMPARTS(adm.[year], adm.[month], 1)) AS tenure_months,

    -- Trip productivity metrics
    ISNULL(tp.total_trips, 0) AS total_trips,
    ISNULL(tp.total_miles, 0) AS total_miles,
    ISNULL(tp.avg_idle_hours, 0) AS avg_idle_hours,

    -- Revenue metrics
    ISNULL(rv.total_revenue, 0) AS total_revenue,
    ISNULL(rv.avg_revenue_per_trip, 0) AS avg_revenue_per_trip,
    ISNULL(rv.revenue_per_mile, 0) AS revenue_per_mile,

    -- Delivery service metrics
    ISNULL(dd.total_deliveries, 0) AS total_deliveries,
    ISNULL(dd.on_time_deliveries, 0) AS on_time_deliveries,
    ISNULL(dd.late_deliveries, 0) AS late_deliveries,
    ISNULL(dd.on_time_delivery_pct, 0) AS on_time_delivery_pct,
    ISNULL(dd.avg_detention_minutes, 0) AS avg_detention_minutes,

    -- Safety metrics
    ISNULL(di.total_incidents, 0) AS total_incidents,
    ISNULL(di.total_claim_amount, 0) AS total_claim_amount,

    -- Derived business metrics
    CAST(
        ISNULL(di.total_incidents, 0) * 100.0 / NULLIF(ISNULL(tp.total_trips, 0), 0)
        AS DECIMAL(18,2)
    ) AS incident_rate_per_100_trips,

    CAST(
        ISNULL(rv.total_revenue, 0) * 1.0 / NULLIF(ISNULL(tp.total_trips, 0), 0)
        AS DECIMAL(18,2)
    ) AS realized_revenue_per_trip

FROM all_driver_months adm
LEFT JOIN drivers d
    ON adm.driver_id = d.driver_id
LEFT JOIN vw_driver_trip_monthly tp
    ON adm.driver_id = tp.driver_id
   AND adm.[year] = tp.[year]
   AND adm.[month] = tp.[month]
LEFT JOIN vw_driver_revenue_monthly rv
    ON adm.driver_id = rv.driver_id
   AND adm.[year] = rv.[year]
   AND adm.[month] = rv.[month]
LEFT JOIN vw_driver_delivery_monthly dd
    ON adm.driver_id = dd.driver_id
   AND adm.[year] = dd.[year]
   AND adm.[month] = dd.[month]
LEFT JOIN vw_driver_incident_monthly di
    ON adm.driver_id = di.driver_id
   AND adm.[year] = di.[year]
   AND adm.[month] = di.[month];
GO
