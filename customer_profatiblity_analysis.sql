/* =====================================================================================================
   DASHBOARD 4 — CUSTOMER + ROUTE PROFITABILITY
   EXPLORATORY ANALYSIS QUERIES

   OBJECTIVE:
   These exploratory queries are used to analyze customer revenue concentration,
   revenue realization against potential, booking mix, delivery performance, and
   route monetization before building the Customer + Route Profitability dashboard.

   BUSINESS QUESTIONS COVERED:
   1. Which customers generate the highest revenue and shipment volume?
   2. How concentrated is revenue across the customer base?
   3. Which customers are under-monetized relative to their revenue potential?
   4. What booking model mix (spot / contract / dedicated) is associated with each customer?
   5. Which customers face the highest late-delivery service risk?
   6. Which routes generate the strongest revenue per planned mile?

   DASHBOARD USE:
   These queries help validate KPI definitions such as Active Customers, Revenue,
   Avg Revenue per Customer, Revenue Realization %, On-Time / Late %, High-Value Customers,
   Low-Service Customers, and Route Revenue per Mile metrics.
===================================================================================================== */


-- ============================================================================================
-- 1) Top customers by revenue
-- Purpose:
-- Identify high-value customers based on shipment volume, total revenue,
-- and average revenue per load.
-- ============================================================================================
SELECT
    customer_id,
    COUNT(load_id) AS total_loads,
    SUM(revenue) AS total_revenue,
    ROUND(AVG(revenue), 2) AS avg_revenue_per_load
FROM loads
GROUP BY customer_id
ORDER BY total_revenue DESC;


-- ============================================================================================
-- 2) Revenue share by customer
-- Purpose:
-- Measure revenue concentration across the customer base by calculating
-- each customer's share of total company revenue.
-- Useful for identifying dependency on a small number of accounts.
-- ============================================================================================
SELECT
    customer_id,
    SUM(revenue) AS customer_revenue,
    ROUND(
        100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (),
        2
    ) AS revenue_share_pct
FROM loads
GROUP BY customer_id
ORDER BY customer_revenue DESC;


-- ============================================================================================
-- 3) Revenue realization vs customer potential
-- Purpose:
-- Compare actual revenue earned from each customer against their stated
-- annual revenue potential to identify underpenetrated or overperforming accounts.
-- ============================================================================================
SELECT
    c.customer_id,
    c.customer_name,
    c.annual_revenue_potential,
    SUM(l.revenue) AS actual_revenue,
    ROUND(
        100.0 * SUM(l.revenue) / NULLIF(c.annual_revenue_potential, 0),
        2
    ) AS revenue_realization_pct
FROM customers c
LEFT JOIN loads l
    ON c.customer_id = l.customer_id
GROUP BY
    c.customer_id,
    c.customer_name,
    c.annual_revenue_potential
ORDER BY revenue_realization_pct DESC;


-- ============================================================================================
-- 4) Booking mix by customer
-- Purpose:
-- Analyze customer booking behavior by splitting load volume into Spot,
-- Contract, and Dedicated booking types.
-- This helps understand revenue stability and customer operating model.
-- ============================================================================================
SELECT
    customer_id,
    SUM(CASE WHEN booking_type = 'Spot' THEN 1 ELSE 0 END) AS spot_loads,
    SUM(CASE WHEN booking_type = 'Contract' THEN 1 ELSE 0 END) AS contract_loads,
    SUM(CASE WHEN booking_type = 'Dedicated' THEN 1 ELSE 0 END) AS dedicated_loads
FROM loads
GROUP BY customer_id;


-- ============================================================================================
-- 5) Late deliveries by customer
-- Purpose:
-- Measure customer-level service risk by calculating total deliveries,
-- late deliveries, and late-delivery percentage.
-- This helps identify customers receiving weak service performance.
-- ============================================================================================
SELECT
    l.customer_id,
    COUNT(*) AS total_deliveries,
    SUM(CASE WHEN d.actual_datetime > d.scheduled_datetime THEN 1 ELSE 0 END) AS late_deliveries,
    ROUND(
        100.0 * SUM(CASE WHEN d.actual_datetime > d.scheduled_datetime THEN 1 ELSE 0 END)
        / COUNT(*),
        2
    ) AS late_delivery_pct
FROM loads l
JOIN delivery_events d
    ON l.load_id = d.load_id
WHERE d.event_type = 'Delivery'
GROUP BY l.customer_id
ORDER BY late_delivery_pct DESC;


-- ============================================================================================
-- 6) Route revenue per planned mile
-- Purpose:
-- Evaluate route monetization efficiency by dividing route revenue
-- by planned route miles across all loads on that route.
-- This is a revenue-efficiency proxy, not true route margin.
-- ============================================================================================
SELECT
    l.route_id,
    COUNT(*) AS total_loads,
    SUM(l.revenue) AS total_revenue,
    ROUND(
        SUM(l.revenue) * 1.0 / NULLIF(COUNT(*) * r.typical_distance_miles, 0),
        4
    ) AS revenue_per_planned_mile
FROM loads l
JOIN routes r
    ON l.route_id = r.route_id
GROUP BY l.route_id, r.typical_distance_miles
ORDER BY revenue_per_planned_mile DESC;
