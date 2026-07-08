# Supply Chain & Logistics Analytics Project

## Project Overview

This project is an end-to-end **Supply Chain & Logistics Analytics** case study built using **SQL Server** and **Power BI**. The project is based on a **14-table logistics dataset** that simulates the operations of a trucking and freight company across multiple business areas such as loads, trips, trucks, drivers, customers, routes, maintenance, fuel purchases, delivery events, and safety incidents.

The objective of this project was to transform raw operational data into a **decision-focused reporting system** that helps monitor business performance across **revenue, fleet utilization, driver productivity, customer service, route performance, and operating cost trends**.

The final solution was structured into a **star schema model** and visualized through **four business dashboards**:

* Overview Dashboard
* Fleet Analysis Dashboard
* Driver Performance Dashboard
* Customer Analysis Dashboard

---

# 1. Project Objective

The main objective of this project was to analyze logistics and transportation operations data and build an interactive reporting solution that helps answer critical business questions such as:

* Is revenue growing consistently over time?
* Are fuel and maintenance costs reducing overall operating efficiency?
* Which trucks are underutilized, high-cost, or high-risk assets?
* Which drivers perform well in terms of trips, delivery performance, and operational productivity?
* Which customers generate the highest revenue, and where are service issues occurring?
* Which routes are strategically important from a revenue and operational perspective?

This project was designed to move beyond basic dashboarding and focus on **business performance analysis**, **KPI development**, and **decision-support reporting**.

---

# 2. Business Goals

The project was built around four core business goals:

## Goal 1 — Improve Revenue Visibility

Track total revenue, load volume, and revenue trends over time to understand commercial performance and overall business growth.

## Goal 2 — Control Operating Costs

Monitor fuel cost, maintenance cost, and truck-level maintenance burden to identify operational inefficiencies and cost pressure areas.

## Goal 3 — Improve Operational Efficiency

Measure truck utilization, driver productivity, on-time delivery performance, downtime, and idle hours to improve day-to-day logistics execution.

## Goal 4 — Strengthen Customer & Route Performance

Identify high-value customers, monitor service quality, analyze route-level revenue concentration, and support better customer and route management decisions.

---

# 3. Tools & Techniques Used

## Tools

* **SQL Server** — data exploration, KPI analysis, and query development
* **Power BI** — dashboard design, business reporting, and interactive visualization

## Data Modeling

* Built a **star schema** for dashboard reporting
* Organized operational data into reporting-friendly structures for KPI calculation and dashboard filtering

## SQL Techniques

* Joins across multiple operational tables
* CTEs for intermediate business logic
* Aggregations for KPI calculation
* CASE-based logic for delivery and performance metrics
* Monthly and yearly trend analysis
* Exploratory analysis before dashboard development

## Power BI Techniques

* KPI cards and business scorecards
* Trend analysis visuals
* Ranking charts and comparison visuals
* Scatter plots for customer and operational analysis
* Slicers and interactive dashboard navigation
* DAX measures for KPI calculations and ratio metrics

---

# 4. Dashboard Structure

## Dashboard 1 — Overview Dashboard

This dashboard provides a high-level business summary of company operations.

### Key focus areas:

* Total Revenue
* Total Loads
* Average Revenue per Load
* On-Time Delivery %
* Fuel Cost
* Maintenance Cost
* Revenue and cost trends over time

---

## Dashboard 2 — Driver Performance Dashboard

This dashboard focuses on driver productivity, delivery performance, and operational contribution.

### Key focus areas:

* Active Drivers
* Trips per Driver
* Revenue per Driver
* Idle Hours
* On-Time Delivery %
* Incident count and safety exposure

---

## Dashboard 3 — Fleet Analysis Dashboard

This dashboard focuses on truck utilization, efficiency, maintenance burden, and fleet risk.

### Key focus areas:

* Active vs Idle Trucks
* Truck Utilization
* Fuel Efficiency
* Maintenance Cost per Truck
* Downtime
* Incident exposure
* Underutilized truck identification

---

## Dashboard 4 — Customer Analysis Dashboard

This dashboard focuses on customer value, service quality, and route-level commercial performance.

### Key focus areas:

* Revenue by Customer
* Revenue Realization %
* Booking Mix
* Customer On-Time / Late Delivery %
* Route Revenue Concentration
* Revenue per Planned Mile

---

# 5. Analysis Performed

Before creating dashboards, exploratory analysis was done in SQL to understand the data and validate business metrics.

## Overview Analysis

* Total loads, revenue, and average revenue per load
* Monthly revenue trend
* On-time delivery %
* Fuel cost vs maintenance cost trend
* Revenue vs operating cost trend

## Driver Performance Analysis

* Active drivers
* Trips and revenue by driver
* Driver on-time delivery %
* Idle hours by driver
* Incidents and claims by driver
* Monthly driver productivity trend

## Fleet Analysis

* Active vs idle trucks
* Underutilized trucks with no trip activity
* Fuel efficiency by truck
* Maintenance cost and downtime by truck
* Truck age vs maintenance cost
* Incident exposure by truck

## Customer Analysis

* Top customers by revenue
* Revenue share by customer
* Revenue realization vs annual revenue potential
* Booking mix by customer
* Late deliveries by customer
* Route revenue per planned mile

---

# 6. Key Insights

The project produced several operational and business insights across revenue, fleet, drivers, and customers.

## Revenue & Operations Insights

* Revenue performance can be tracked effectively through monthly trend analysis rather than relying only on total revenue snapshots.
* On-time delivery performance is a critical service KPI because service failures directly affect customer experience and retention.
* Fuel and maintenance costs are two of the most important operating cost drivers and need to be monitored alongside revenue, not in isolation.

## Fleet Insights

* A portion of the fleet may remain idle or underutilized, which indicates inefficient asset usage and unnecessary fixed cost burden.
* Older trucks tend to require more maintenance attention and can create higher operational cost pressure over time.
* Truck-level maintenance cost, downtime, and incident exposure are useful indicators for identifying fleet risk and replacement candidates.

## Driver Insights

* Driver performance cannot be judged only by trip count; it should also include delivery timeliness, idle time, and incident exposure.
* High-trip drivers are not always the strongest performers if their service quality or safety metrics are weak.
* Driver-level visibility helps separate high performers from operational risk drivers.

## Customer & Route Insights

* Revenue is often concentrated among a smaller group of customers, which increases dependency risk if service quality drops.
* Revenue realization against customer potential helps identify accounts that are underpenetrated and may offer expansion opportunities.
* Route-level revenue concentration and revenue-per-mile metrics help highlight commercially important routes and support pricing or route strategy decisions.

---

# 7. Recommendations

## Recommendation 1 — Improve Fleet Utilization

Regularly track trucks with zero or very low trip activity and investigate whether they should be reassigned, repaired, retired, or removed from the active fleet plan.

## Recommendation 2 — Monitor Cost Drivers at the Truck Level

Use truck-level fuel efficiency, maintenance cost, and downtime metrics to identify high-cost vehicles and prioritize preventive maintenance or replacement decisions.

## Recommendation 3 — Build Driver Performance Reviews on Multiple KPIs

Evaluate drivers using a balanced scorecard that includes trips, on-time delivery %, idle hours, and incidents instead of only trip volume.

## Recommendation 4 — Protect High-Value Customers with Weak Service Levels

Cross-analyze customer revenue and on-time delivery performance to identify high-revenue accounts that are at service risk and may require operational attention.

## Recommendation 5 — Use Route Metrics for Commercial Decisions

Track route revenue concentration and revenue per planned mile to support pricing, route prioritization, and customer allocation decisions.

## Recommendation 6 — Use Dashboard Monitoring for Ongoing Operations Reviews

This reporting solution can be used by operations, fleet, and commercial teams as a recurring performance monitoring layer instead of one-time static analysis.

---

# 8. Outcome

This project demonstrates how logistics operations data can be transformed into a structured analytics solution using **SQL Server, data modeling, KPI analysis, and Power BI dashboards**. It highlights the full workflow from **exploratory SQL analysis** to **dashboard development**, while focusing on business questions related to **revenue, fleet utilization, driver performance, customer service, and operational efficiency**.

---

# 9. Skills Demonstrated

* SQL data analysis
* KPI development
* Business problem framing
* Logistics / supply chain analytics
* Data modeling with star schema
* Dashboard design in Power BI
* DAX-based reporting metrics
* Business insight generation and recommendation writing
