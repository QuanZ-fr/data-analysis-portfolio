-- Olist 04: delivery time
--
-- Question: how many days pass, on average, between purchase and delivery?
-- Shown by month.
-- Definitions (same as notebooks/05-delivery-time.ipynb):
--   Orders:        status delivered, with both timestamps present
--   Delivery days: order_delivered_customer_date - order_purchase_timestamp
--   Month:         the month of purchase; an order counts in the month it was
--                  placed even if it was delivered in the next one
--
-- Usage: start psql from the repository root, then
--   \i olist/sql/04_delivery_days.sql
-- Only TEMP tables are created and dropped (the DROP statements are limited to
-- the pg_temp schema), so nothing permanent is written or removed.

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

-- Load check: expect 99441 rows
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT order_id) AS n_orders FROM olist_orders;

-- ========== 2. Average delivery days by month ==========
-- n_orders is shown next to the average because months with very few orders
-- do not support a conclusion.
WITH delivered AS (
    SELECT
        order_id,
        date_trunc('month', order_purchase_timestamp)::date AS purchase_month,
        EXTRACT(EPOCH FROM (order_delivered_customer_date - order_purchase_timestamp)) / 86400 AS delivery_days  -- interval -> seconds -> days
    FROM olist_orders
    WHERE order_status = 'delivered'
      AND order_delivered_customer_date IS NOT NULL          -- 8 delivered orders have no delivery timestamp
      AND order_purchase_timestamp IS NOT NULL
)
SELECT
    purchase_month,
    COUNT(*)                              AS n_orders,
    ROUND(AVG(delivery_days)::numeric, 2) AS avg_days
FROM delivered
GROUP BY purchase_month
ORDER BY purchase_month;

-- ========== 3. Checks against the pandas result ==========
-- Orders in scope: 96470 (96478 delivered - 8 without a delivery timestamp);
-- overall average 12.56 days.
-- The monthly n_orders add up to 96470 across 23 months.
-- Spot checks: 2017-01 750 orders, 12.65 days; 2017-11 7288 orders, 15.16 days;
--              2018-02 6555 orders, 16.95 days; 2018-08 6351 orders, 7.73 days.
