-- Olist 07: order-level base table and state analysis
--
-- Four queries on the Olist tables. Query 2 builds the order-level base table
-- that queries 3 and 4 use.
-- Definitions: valid orders exclude canceled and unavailable;
-- GMV = sum of price, no freight.
--
-- Usage: start psql from the repository root, then
--   \i olist/sql/07_order_base.sql
-- Only TEMP tables are created and dropped (the DROP statements are limited to
-- the pg_temp schema), so nothing permanent is written or removed.

-- ========== 0. Load three tables into temp tables ==========
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

-- Load check: orders 99441 rows; customers 99441 rows; items 112650 rows
SELECT (SELECT COUNT(*) FROM olist_orders)    AS n_orders,
       (SELECT COUNT(*) FROM olist_customers) AS n_customers,
       (SELECT COUNT(*) FROM olist_items)     AS n_items;


-- ========== 1. Orders and share by status ==========
-- All orders, no status filter.
select order_status, count(*) as n_orders, round(count(*) * 100.0 / (select count(*) from olist_orders), 2) as pct
from olist_orders
group by order_status
order by n_orders desc;

-- Check: 8 rows; delivered 96478, 97.02; shipped 1107, 1.11; canceled 625, 0.63;
-- n_orders adds up to 99441.


-- ========== 2. Order-level base table ==========
-- One row per valid order, stored as the temp table order_base:
--   order_id
--   purchase_month   first day of the purchase month
--   customer_state
--   n_items          number of items; 0 for orders without item rows
--   items_price      item-price GMV of the order; 0 without item rows
--   freight          total freight of the order; 0 without item rows
-- order_items has several rows per order, so the item rows are aggregated
-- by order in the same step as the join.
drop table if exists pg_temp.order_base;
create temp table order_base as(
with t as (
    select order_id, date_trunc('month', order_purchase_timestamp)::date as purchase_month, customer_state
    from olist_orders
    left join olist_customers
    on olist_orders.customer_id = olist_customers.customer_id
    where order_status not in ('canceled', 'unavailable')
)
select t.order_id, purchase_month, customer_state, count(olist_items.order_id) as n_items, coalesce(sum(price), 0) as items_price, coalesce(sum(freight_value), 0) as freight
from t
left join olist_items
on t.order_id = olist_items.order_id
group by t.order_id, purchase_month, customer_state
);

-- Check:
SELECT COUNT(*) AS n_rows, COUNT(DISTINCT order_id) AS n_orders, SUM(n_items) AS n_items,
       SUM(items_price) AS items_price, SUM(freight) AS freight,
       COUNT(*) FILTER (WHERE n_items = 0) AS no_items, MAX(n_items) AS max_items
FROM order_base;
-- Expect: n_rows 98207, n_orders 98207, n_items 112101, items_price 13494400.74,
--         freight 2241126.29, no_items 8, max_items 21.


-- ========== 3. Average order value and two rankings by state ==========
-- Uses order_base only.
--   avg_order_value   GMV / number of orders, two decimals
--   rnk_gmv           rank by GMV, descending
--   rnk_aov           rank by average order value, descending
select customer_state,
       count(order_id) as n_orders,
       sum(items_price) as gmv,
       round(sum(items_price) / count(order_id), 2) as avg_order_value,
       rank() over (order by sum(items_price) desc) as rnk_gmv,
       rank() over (order by sum(items_price) / count(order_id) desc) as rnk_aov
from order_base
group by customer_state
order by gmv desc;

-- Check: 27 rows. SP: 41127 orders, 5163867.22, AOV 125.56, rnk_gmv 1, rnk_aov 27.
--        RJ: 12698 orders, 1811623.42, 142.67, rnk_gmv 2, rnk_aov 21.
--        Highest AOV is PB: 531 orders, 114874.10, 216.34.
-- SP ranks first by GMV and last by average order value.


-- ========== 4. Best month by GMV for each state ==========
-- Uses order_base only. One row per state: the month with its highest GMV.
with state_month as (                                   -- one row per state and month
    select customer_state, purchase_month, sum(items_price) as gmv
    from order_base
    group by customer_state, purchase_month
),
ranked as (                                             -- rank months inside each state
    select customer_state, purchase_month, gmv,
           row_number() over (partition by customer_state order by gmv desc) as rn
    from state_month
)
select customer_state, purchase_month, gmv              -- keep the top month per state
from ranked
where rn = 1
order by gmv desc;

-- Check: 27 rows. SP: 2018-05-01, 434116.39; RJ: 2017-11-01, 150222.04;
--        MG: 2017-11-01, 133533.66; RR: 2018-03-01, 2244.68.
--        For 8 of the 27 states the best month is 2017-11.
