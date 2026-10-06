-- Olist 05: month-over-month change and cumulative GMV (window functions)
--
-- Questions: how much did item-price GMV change from the previous month,
-- and how much had been sold in total up to each month?
-- Definitions: monthly GMV as in 02_monthly_gmv.sql (sum of price, no freight;
-- by purchase month; canceled and unavailable orders excluded).
--
-- Usage: start psql from the repository root, then
--   \i olist/sql/05_monthly_gmv_growth.sql
-- Only TEMP tables are created and dropped (the DROP statements are limited to
-- the pg_temp schema), so nothing permanent is written or removed.

-- ========== 1. Load tables and store monthly GMV as a temp table ==========
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

-- Monthly GMV (same query as 02), one row per month: purchase_month, gmv
DROP TABLE IF EXISTS pg_temp.monthly_gmv;
CREATE TEMP TABLE monthly_gmv AS
WITH order_gmv AS (
    SELECT order_id, SUM(price) AS order_gmv
    FROM olist_items
    GROUP BY order_id
)
SELECT
    date_trunc('month', o.order_purchase_timestamp)::date AS purchase_month,
    COALESCE(SUM(g.order_gmv), 0)                         AS gmv
FROM olist_orders AS o
LEFT JOIN order_gmv AS g ON g.order_id = o.order_id
WHERE o.order_status NOT IN ('canceled', 'unavailable')
GROUP BY date_trunc('month', o.order_purchase_timestamp);

-- Check: expect 24 rows and a GMV total of 13494400.74
SELECT COUNT(*) AS n_months, SUM(gmv) AS total_gmv FROM monthly_gmv;

-- ========== 2. Month-over-month change and cumulative GMV ==========
-- Output columns:
--   purchase_month
--   gmv        item-price GMV of the month
--   prev_gmv   GMV of the previous row (NULL for the first month)
--   mom_pct    (gmv - prev_gmv) / prev_gmv * 100, one decimal
--   cum_gmv    running total from the first month
SELECT
    purchase_month,
    gmv,
    LAG(gmv) OVER (ORDER BY purchase_month) AS prev_gmv,
    ROUND(
        (gmv - LAG(gmv) OVER (ORDER BY purchase_month)) * 100.0
        / NULLIF(LAG(gmv) OVER (ORDER BY purchase_month), 0)                -- NULL instead of a division by zero
    , 1)                                    AS mom_pct,
    SUM(gmv) OVER (ORDER BY purchase_month) AS cum_gmv
FROM monthly_gmv
ORDER BY purchase_month;

-- ========== 3. Checks ==========
-- The last cum_gmv must equal 13494400.74.
-- prev_gmv and mom_pct are NULL on the first row.
-- Caveat: 2016-11 has no orders, so the table has no row for it and LAG gives
-- 2016-12 the value of 2016-10. Month-over-month figures are only meaningful
-- inside the observation period 2017-01 to 2018-08.
