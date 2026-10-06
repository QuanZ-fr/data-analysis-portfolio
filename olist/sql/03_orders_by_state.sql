-- Olist 03: orders by state
--
-- Question: how many valid orders does each state have?
-- Definitions (same as notebooks/04-orders-by-state.ipynb):
--   Orders: canceled and unavailable orders are excluded
--   State:  olist_customers.customer_state, joined on customer_id
--   Unit:   count distinct order_id
--
-- Usage: start psql from the repository root, then
--   \i olist/sql/03_orders_by_state.sql
-- Only TEMP tables are created and dropped (the DROP statements are limited to
-- the pg_temp schema), so nothing permanent is written or removed.

-- ========== 1. Load orders and customers into temp tables ==========
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

DROP TABLE IF EXISTS pg_temp.olist_customers;
CREATE TEMP TABLE olist_customers (
    customer_id               text,
    customer_unique_id        text,
    customer_zip_code_prefix  text,
    customer_city             text,
    customer_state            text
);
\copy olist_customers FROM 'olist/data/raw/olist_customers_dataset.csv' CSV HEADER

-- Load check: orders 99441 rows; customers 99441 rows, 99441 distinct customer_id
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT order_id) AS n_orders FROM olist_orders;
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT customer_id) AS n_customer_ids FROM olist_customers;

-- ========== 2. Orders by state ==========
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS n_orders
FROM olist_orders AS o
JOIN olist_customers AS c
    ON o.customer_id = c.customer_id                       -- customer_id is unique in customers, so the join adds no rows
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY c.customer_state
ORDER BY n_orders DESC;

-- ========== 3. Checks against the pandas result ==========
-- The states add up to 98207 across 27 states.
-- Top three: SP 41127, RJ 12698, MG 11496.
