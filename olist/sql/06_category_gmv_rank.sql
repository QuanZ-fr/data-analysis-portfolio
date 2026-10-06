-- Olist 06: GMV by product category, with rank and share
--
-- Questions: how much item-price GMV does each category account for, where
-- does it rank, and what share of the total is it?
-- Definitions (same as notebooks/08-category-gmv.ipynb):
--   GMV:      sum of order_items.price, no freight
--   Orders:   canceled and unavailable orders are excluded
--   Category: products.product_category_name; products without a category
--             are grouped into one row, '(missing)'
--
-- Usage: start psql from the repository root, then
--   \i olist/sql/06_category_gmv_rank.sql
-- Only TEMP tables are created and dropped (the DROP statements are limited to
-- the pg_temp schema), so nothing permanent is written or removed.

-- ========== 1. Load three tables into temp tables ==========
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

DROP TABLE IF EXISTS pg_temp.olist_products;
CREATE TEMP TABLE olist_products (
    product_id                  text,
    product_category_name       text,
    product_name_lenght         numeric,
    product_description_lenght  numeric,
    product_photos_qty          numeric,
    product_weight_g            numeric,
    product_length_cm           numeric,
    product_height_cm           numeric,
    product_width_cm            numeric
);
\copy olist_products FROM 'olist/data/raw/olist_products_dataset.csv' CSV HEADER

-- Load check: orders 99441 rows; items 112650 rows; products 32951 rows,
-- 32951 distinct product_id, 610 without a category
SELECT COUNT(*) AS n_orders FROM olist_orders;
SELECT COUNT(*) AS n_items FROM olist_items;
SELECT COUNT(*) AS n_products, COUNT(DISTINCT product_id) AS n_product_ids,
       COUNT(*) - COUNT(product_category_name) AS n_missing_category
FROM olist_products;

-- ========== 2. Category GMV, rank and share (top 10) ==========
WITH category_gmv AS (                                        -- one row per category
    SELECT
        COALESCE(p.product_category_name, '(missing)') AS category,
        SUM(i.price)                                   AS gmv
    FROM olist_items AS i
    LEFT JOIN olist_products AS p                              -- keep every item row; product_id is unique in products
        ON p.product_id = i.product_id
    WHERE i.order_id IN (                                      -- items of valid orders only
        SELECT order_id
        FROM olist_orders
        WHERE order_status NOT IN ('canceled', 'unavailable')
    )
    GROUP BY COALESCE(p.product_category_name, '(missing)')
)
SELECT
    category,
    gmv,
    RANK() OVER (ORDER BY gmv DESC)               AS rnk,
    ROUND(gmv * 100.0 / SUM(gmv) OVER (), 1)      AS pct      -- share of the total across all categories
FROM category_gmv
ORDER BY gmv DESC
LIMIT 10;

-- ========== 3. Checks against the pandas result ==========
-- 74 rows in total (73 categories plus '(missing)'), GMV total 13494400.74.
-- Top three: beleza_saude 1255695.13 (9.3%), relogios_presentes 1198185.21 (8.9%),
--            cama_mesa_banho 1035964.06 (7.7%).
-- '(missing)': 178572.55, 1.3%, rank 21.
