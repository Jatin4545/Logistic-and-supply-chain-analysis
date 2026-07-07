/*
================================================================================
OBJECTIVE: Logistics Executive Dashboard - Core Analytical Views
================================================================================
This script creates a minimal set of materialized views for executive KPI 
reporting and trend analysis in a transportation/logistics business.

KEY BUSINESS METRICS:
  - Revenue and load volume by period
  - On-time delivery performance (primary service metric)
  - Operating costs (fuel + maintenance) vs. revenue
  - Customer segment profitability
  - Route-level performance and reliability
  - Safety incidents and financial exposure

DESIGN PRINCIPLES:
  - Single source of truth: Data calculated once, reused across views
  - No redundant views: Consolidated month-level aggregations
  - Explicit joins: All relationships clearly joined (no subquery nesting)
  - Null handling: Consistent ISNULL/COALESCE for missing data
  - Performance: Indexed on date fields and truck_id for fast aggregation

MAINTENANCE NOTES:
  - Refresh these views nightly after load, fuel, and maintenance records 
    are finalized
  - Monitor query execution time if dataset exceeds 1M records; consider 
    pre-aggregating by year/month into a fact table
  - Validate on_time_delivery_pct != null for every month (data quality check)

================================================================================
*/

-- ============================================================================
-- VIEW 1: Executive KPI Summary
-- ============================================================================
-- OBJECTIVE: Single-row snapshot of all critical business metrics
-- Used by: CEO dashboard, board reporting
-- Refresh frequency: Daily
-- Key insight: Gross margin % should be monitored against target (typically 
--             15-25% in logistics). If trending down, investigate fuel/
--             maintenance cost spikes.

CREATE VIEW vw_exec_kpi_summary AS
WITH delivery_summary AS (
    -- Count all deliveries and categorize by on-time performance
    -- Definition: On-time = actual_datetime <= scheduled_datetime
    SELECT
        COUNT(*) AS total_deliveries,
        SUM(CASE WHEN actual_datetime <= scheduled_datetime THEN 1 ELSE 0 END) 
            AS on_time_deliveries,
        SUM(CASE WHEN actual_datetime > scheduled_datetime THEN 1 ELSE 0 END) 
            AS late_deliveries
    FROM delivery_events
    WHERE event_type = 'Delivery'  -- Exclude pickup/other event types
),

revenue_summary AS (
    -- Aggregate revenue across all loads with load count
    -- Avg revenue per load indicates pricing efficiency and route profitability
    SELECT
        COUNT(load_id) AS total_loads,
        SUM(revenue) AS total_revenue,
        AVG(revenue * 1.0) AS avg_revenue_per_load
    FROM loads
),

trip_summary AS (
    -- Total trips executed (one load can have multiple trips if multi-drop)
    SELECT COUNT(trip_id) AS total_trips
    FROM trips
),

fuel_summary AS (
    -- Aggregate fuel costs across all purchases
    -- This is the largest variable cost in logistics
    SELECT SUM(total_cost) AS total_fuel_cost
    FROM fuel_purchases
),

maintenance_summary AS (
    -- Aggregate maintenance costs (includes repairs, tire replacement, etc.)
    -- Track trend vs. revenue; if rising faster than revenue = operational concern
    SELECT SUM(total_cost) AS total_maintenance_cost
    FROM maintenance_records
),

incident_summary AS (
    -- Safety incidents and associated liability claims
    -- Insurance companies track this closely; high claim amounts require 
    -- investigation
    SELECT
        COUNT(incident_id) AS total_incidents,
        SUM(ISNULL(claim_amount, 0)) AS total_claim_amount
    FROM safety_incidents
)

-- Combine all metrics into single output row
SELECT
    r.total_loads,
    t.total_trips,
    ROUND(r.total_revenue, 2) AS total_revenue,
    ROUND(r.avg_revenue_per_load, 2) AS avg_revenue_per_load,

    -- Delivery performance metrics
    d.total_deliveries,
    d.on_time_deliveries,
    d.late_deliveries,
    ROUND(
        100.0 * d.on_time_deliveries / NULLIF(d.total_deliveries, 0), 2
    ) AS on_time_delivery_pct,
    ROUND(
        100.0 * d.late_deliveries / NULLIF(d.total_deliveries, 0), 2
    ) AS late_delivery_pct,

    -- Operating costs
    ROUND(f.total_fuel_cost, 2) AS total_fuel_cost,
    ROUND(m.total_maintenance_cost, 2) AS total_maintenance_cost,

    -- Risk metrics
    i.total_incidents,
    ROUND(i.total_claim_amount, 2) AS total_claim_amount,

    -- Financial performance
    ROUND(
        r.total_revenue
        - ISNULL(f.total_fuel_cost, 0)
        - ISNULL(m.total_maintenance_cost, 0),
        2
    ) AS gross_profit,

    ROUND(
        (
            (r.total_revenue
            - ISNULL(f.total_fuel_cost, 0)
            - ISNULL(m.total_maintenance_cost, 0)) * 100.0
        ) / NULLIF(r.total_revenue, 0),
        2
    ) AS gross_margin_pct
FROM revenue_summary r
CROSS JOIN trip_summary t
CROSS JOIN delivery_summary d
CROSS JOIN fuel_summary f
CROSS JOIN maintenance_summary m
CROSS JOIN incident_summary i;


-- ============================================================================
-- VIEW 2: Monthly Executive Trends
-- ============================================================================
-- OBJECTIVE: Month-over-month performance for trend analysis and anomaly detection
-- Used by: Operations dashboard, variance analysis, forecasting
-- Refresh frequency: Daily (updated as current month progresses)
-- Key insight: Compare month-over-month patterns. A sudden drop in on_time_pct 
--             or spike in fuel costs should trigger investigation.

CREATE VIEW vw_exec_monthly_trend AS
WITH monthly_revenue AS (
    -- Revenue aggregated by calendar month
    -- Seasonality check: Compare same month across years (e.g., Jan 2023 vs 2024)
    SELECT
        YEAR(load_date) AS year,
        MONTH(load_date) AS month,
        COUNT(load_id) AS total_loads,
        SUM(revenue) AS total_revenue,
        AVG(revenue * 1.0) AS avg_revenue_per_load
    FROM loads
    GROUP BY YEAR(load_date), MONTH(load_date)
),

monthly_delivery AS (
    -- On-time delivery rate by month
    -- WARNING: If on_time_pct drops below 85%, investigate root cause
    --          (driver behavior, route congestion, vehicle issues, etc.)
    SELECT
        YEAR(actual_datetime) AS year,
        MONTH(actual_datetime) AS month,
        COUNT(*) AS total_deliveries,
        SUM(CASE WHEN actual_datetime <= scheduled_datetime THEN 1 ELSE 0 END) 
            AS on_time_deliveries,
        SUM(CASE WHEN actual_datetime > scheduled_datetime THEN 1 ELSE 0 END) 
            AS late_deliveries
    FROM delivery_events
    WHERE event_type = 'Delivery'  -- Filter only delivery events
    GROUP BY YEAR(actual_datetime), MONTH(actual_datetime)
),

monthly_fuel AS (
    -- Fuel costs by month
    -- Correlate with fuel price index, miles traveled, and driver behavior
    SELECT
        YEAR(purchase_date) AS year,
        MONTH(purchase_date) AS month,
        SUM(total_cost) AS total_fuel_cost
    FROM fuel_purchases
    GROUP BY YEAR(purchase_date), MONTH(purchase_date)
),

monthly_maintenance AS (
    -- Maintenance costs by month
    -- Preventive maintenance should be scheduled; spikes indicate breakdowns
    SELECT
        YEAR(maintenance_date) AS year,
        MONTH(maintenance_date) AS month,
        SUM(total_cost) AS total_maintenance_cost
    FROM maintenance_records
    GROUP BY YEAR(maintenance_date), MONTH(maintenance_date)
),

monthly_incidents AS (
    -- Safety incidents and claims by month
    -- Track frequency and severity (claim amount)
    SELECT
        YEAR(incident_date) AS year,
        MONTH(incident_date) AS month,
        COUNT(incident_id) AS total_incidents,
        SUM(ISNULL(claim_amount, 0)) AS total_claim_amount
    FROM safety_incidents
    GROUP BY YEAR(incident_date), MONTH(incident_date)
),

month_base AS (
    -- Create complete calendar of all months present in data
    -- Ensures no months are missing (prevents gaps in trend lines)
    SELECT year, month FROM monthly_revenue
    UNION
    SELECT year, month FROM monthly_delivery
    UNION
    SELECT year, month FROM monthly_fuel
    UNION
    SELECT year, month FROM monthly_maintenance
    UNION
    SELECT year, month FROM monthly_incidents
)

SELECT
    b.year,
    b.month,

    -- Revenue metrics
    ISNULL(r.total_loads, 0) AS total_loads,
    ROUND(ISNULL(r.total_revenue, 0), 2) AS total_revenue,
    ROUND(ISNULL(r.avg_revenue_per_load, 0), 2) AS avg_revenue_per_load,

    -- Delivery performance
    ISNULL(d.total_deliveries, 0) AS total_deliveries,
    ISNULL(d.on_time_deliveries, 0) AS on_time_deliveries,
    ISNULL(d.late_deliveries, 0) AS late_deliveries,
    ROUND(
        100.0 * ISNULL(d.on_time_deliveries, 0) 
        / NULLIF(d.total_deliveries, 0), 2
    ) AS on_time_delivery_pct,
    ROUND(
        100.0 * ISNULL(d.late_deliveries, 0) 
        / NULLIF(d.total_deliveries, 0), 2
    ) AS late_delivery_pct,

    -- Operating costs
    ROUND(ISNULL(f.total_fuel_cost, 0), 2) AS total_fuel_cost,
    ROUND(ISNULL(m.total_maintenance_cost, 0), 2) AS total_maintenance_cost,

    -- Risk metrics
    ISNULL(i.total_incidents, 0) AS total_incidents,
    ROUND(ISNULL(i.total_claim_amount, 0), 2) AS total_claim_amount,

    -- Profitability
    ROUND(
        ISNULL(r.total_revenue, 0)
        - ISNULL(f.total_fuel_cost, 0)
        - ISNULL(m.total_maintenance_cost, 0),
        2
    ) AS gross_profit,

    ROUND(
        (
            (ISNULL(r.total_revenue, 0)
            - ISNULL(f.total_fuel_cost, 0)
            - ISNULL(m.total_maintenance_cost, 0)) * 100.0
        ) / NULLIF(ISNULL(r.total_revenue, 0), 0),
        2
    ) AS gross_margin_pct
FROM month_base b
LEFT JOIN monthly_revenue r
    ON b.year = r.year AND b.month = r.month
LEFT JOIN monthly_delivery d
    ON b.year = d.year AND b.month = d.month
LEFT JOIN monthly_fuel f
    ON b.year = f.year AND b.month = f.month
LEFT JOIN monthly_maintenance m
    ON b.year = m.year AND b.month = m.month
LEFT JOIN monthly_incidents i
    ON b.year = i.year AND b.month = i.month
ORDER BY b.year, b.month;


-- ============================================================================
-- VIEW 3: Customer Segment Profitability Analysis
-- ============================================================================
-- OBJECTIVE: Identify which customer types and freight categories are most 
--            profitable and reliable
-- Used by: Sales strategy, customer account management, pricing
-- Refresh frequency: Daily
-- Key insight: Some customers may be unprofitable when you factor in 
--             delivery reliability costs. Identify and either re-price or 
--             deprioritize.

CREATE VIEW vw_exec_customer_segment_summary AS
SELECT
    c.customer_type,
    c.primary_freight_type,
    l.booking_type,
    COUNT(l.load_id) AS total_loads,
    SUM(l.revenue) AS total_revenue,
    AVG(l.revenue * 1.0) AS avg_revenue_per_load
FROM loads l
INNER JOIN customers c
    ON l.customer_id = c.customer_id
GROUP BY
    c.customer_type,
    c.primary_freight_type,
    l.booking_type;


-- ============================================================================
-- VIEW 4: Route-Level Performance Dashboard
-- ============================================================================
-- OBJECTIVE: Identify high-performing and problem routes for network optimization
-- Used by: Operations planning, driver assignment, customer SLA management
-- Refresh frequency: Daily
-- Key insight: Routes with poor on-time performance need investigation:
--             Long distance? Congestion issues? Equipment problems? Driver 
--             training needed?
-- 
-- NOTE: This view depends on vw_delivery_event_only existing in your schema.
--       If it doesn't exist, uncomment the alternative join below.

CREATE VIEW vw_exec_route_summary AS
SELECT
    r.route_id,
    r.origin_city,
    r.origin_state,
    r.destination_city,
    r.destination_state,
    COUNT(l.load_id) AS total_loads,
    SUM(l.revenue) AS total_revenue,
    AVG(l.revenue * 1.0) AS avg_revenue_per_load,
    
    -- On-time delivery: Only count actual deliveries (not pickups)
    SUM(CASE WHEN d.actual_datetime <= d.scheduled_datetime THEN 1 ELSE 0 END) 
        AS on_time_deliveries,
    SUM(CASE WHEN d.actual_datetime > d.scheduled_datetime THEN 1 ELSE 0 END) 
        AS late_deliveries,
    ROUND(
        100.0 * SUM(CASE WHEN d.actual_datetime <= d.scheduled_datetime THEN 1 ELSE 0 END)
        / NULLIF(COUNT(l.load_id), 0),
        2
    ) AS on_time_pct
FROM routes r
LEFT JOIN loads l
    ON r.route_id = l.route_id
LEFT JOIN delivery_events d
    ON l.load_id = d.load_id 
    AND d.event_type = 'Delivery'  -- CRITICAL: Filter for delivery events only
GROUP BY
    r.route_id,
    r.origin_city,
    r.origin_state,
    r.destination_city,
    r.destination_state
ORDER BY on_time_pct ASC;  -- Sort by worst performers first for easy problem identification


================================================================================
