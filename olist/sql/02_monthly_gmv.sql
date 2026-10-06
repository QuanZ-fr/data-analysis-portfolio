-- Olist 02: monthly GMV
--
-- Question: what was the item-price GMV each month?
-- Definitions (same as notebooks/03-monthly-gmv.ipynb):
--   GMV:    sum of order_items.price; freight_value is kept separate
--   Time:   orders.order_purchase_timestamp, truncated to month
--   Status: canceled and unavailable orders are excluded
--   Grain:  order_items has several rows per order, so items are aggregated
--           to one row per order BEFORE joining to orders; otherwise amounts
--           would be counted more than once
--
-- Usage: start psql from the repository root, then
--   \i olist/sql/02_monthly_gmv.sql
-- Only TEMP tables are created and dropped (the DROP statements are limited to
-- the pg_temp schema), so nothing permanent is written or removed.

-- ========== 1. Load orders and order_items into temp tables ==========
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

DROP TABLE IF EXISTS pg_temp.olist_items;
CREATE TEMP TABLE olist_items (
    order_id             text,
    order_item_id        int,
    product_id           text,
    seller_id            text,
    shipping_limit_date  timestamp,
    price                numeric(12,2),
    freight_value        numeric(12,2)
);
\copy olist_items FROM 'olist/data/raw/olist_order_items_dataset.csv' CSV HEADER

-- Load check: orders 99441 rows; items 112650 rows, 98666 distinct order_id
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT order_id) AS n_orders FROM olist_orders;
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT order_id) AS n_orders FROM olist_items;

-- ========== 2. Monthly GMV ==========
WITH order_gmv AS (                                    -- one row per order
    SELECT order_id,
           SUM(price) AS order_gmv                     -- item price only, no freight
    FROM olist_items
    GROUP BY order_id
)
SELECT
    date_trunc('month', o.order_purchase_timestamp)::date AS purchase_month,
    COALESCE(SUM(g.order_gmv), 0)                         AS gmv
FROM olist_orders AS o
LEFT JOIN order_gmv AS g ON g.order_id = o.order_id    -- keep orders that have no item rows
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY date_trunc('month', o.order_purchase_timestamp)
ORDER BY purchase_month;

-- ========== 3. Checks ==========
-- order_id must still be unique after the join: n_rows = n_orders
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT o.order_id) AS n_orders
FROM olist_orders AS o
LEFT JOIN (SELECT order_id, SUM(price) AS order_gmv FROM olist_items GROUP BY order_id) AS g
       ON g.order_id = o.order_id;

-- The monthly values must add up to the pandas total under the same
-- definitions: 13494400.74
SELECT SUM(g.order_gmv) AS total_gmv
FROM olist_orders AS o
JOIN (SELECT order_id, SUM(price) AS order_gmv FROM olist_items GROUP BY order_id) AS g
  ON g.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable');
