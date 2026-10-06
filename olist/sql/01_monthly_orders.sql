-- Olist 01: monthly order count
--
-- Question: how many orders were placed each month?
-- Definitions (same as notebooks/02-monthly-orders.ipynb):
--   Time:   order_purchase_timestamp, truncated to month
--   Status: canceled and unavailable orders are excluded
--   Unit:   one row per order in orders; count distinct order_id
--
-- Usage: start psql from the repository root (\copy paths are relative to
-- the directory psql was started in), connected to any PostgreSQL database:
--   \i olist/sql/01_monthly_orders.sql
-- Only TEMP tables are created and dropped (the DROP statements are limited to
-- the pg_temp schema), so nothing permanent is written or removed.
-- The CSV files live in olist/data/raw/ (not committed); run
-- olist/download_data.py to fetch them.

-- ========== 1. Load orders into a temp table ==========
-- Stop immediately if a load or query fails.
\set ON_ERROR_STOP on

DROP TABLE IF EXISTS pg_temp.olist_orders;
CREATE TEMP TABLE olist_orders (
    order_id                       text,
    customer_id                    text,
    order_status                   text,
    order_purchase_timestamp       timestamp,
    order_approved_at              timestamp,
    order_delivered_carrier_date   timestamp,
    order_delivered_customer_date  timestamp,
    order_estimated_delivery_date  timestamp
);

\copy olist_orders FROM 'olist/data/raw/olist_orders_dataset.csv' CSV HEADER

-- Load check: expect 99441 rows and 99441 distinct order_id
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT order_id) AS n_orders FROM olist_orders;

-- ========== 2. Monthly order count ==========
SELECT
    date_trunc('month', order_purchase_timestamp)::date AS purchase_month,
    COUNT(DISTINCT order_id)                            AS n_orders
FROM olist_orders
WHERE order_status NOT IN ('canceled', 'unavailable')
GROUP BY date_trunc('month', order_purchase_timestamp)
ORDER BY purchase_month;


-- ========== 3. Checks against the pandas result ==========
-- Total           98207
-- 2016-09         2
-- 2016-10         293
-- 2016-11         no orders (the month does not appear in the result)
-- 2016-12         1
-- 2017-11         7423 (peak)
-- 2018-08         6421
-- 2018-09         1
-- 24 months have at least one order.

-- Expect total = 98207 and n_months = 24
SELECT SUM(n_orders) AS total, COUNT(*) AS n_months
FROM (
    SELECT date_trunc('month', order_purchase_timestamp) AS purchase_month,
           COUNT(DISTINCT order_id)                      AS n_orders
    FROM olist_orders
    WHERE order_status NOT IN ('canceled', 'unavailable')
    GROUP BY date_trunc('month', order_purchase_timestamp)
) AS m;
