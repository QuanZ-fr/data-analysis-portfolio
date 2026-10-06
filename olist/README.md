# Olist E-commerce: Sales, Categories, Delivery and Reviews

This project analyses about 100,000 public orders from Olist, a Brazilian e-commerce marketplace, using PostgreSQL, pandas and Tableau. It answers three business questions, with figures traceable to the SQL or pandas analysis and the dashboard. Between January–August 2017 and January–August 2018, item-price GMV in this sample grew by **138%**; the top 10 of 73 product categories account for **62.4%** of GMV; and among reviewed orders, **62.4%** of late deliveries received a score of 2 or less, against **9.3%** of on-time deliveries. These are descriptive results on a public sample, not estimates for Olist's whole business.

## Questions and data

1. How did sales volume change over time?
2. Which product categories contribute most of the item-price GMV?
3. How do review scores differ between late and on-time deliveries?

The data is Kaggle's [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), licensed **CC BY-NC-SA 4.0** (non-commercial use, attribution, share-alike). It was downloaded on 2026-09-29. The raw CSV files are **not committed**; [`download_data.py`](download_data.py) fetches them into `data/raw/`.

Six of the nine tables are used:

| Table | Grain | Rows | Key facts |
|---|---|---:|---|
| orders | one row per order | 99,441 | `order_id` unique |
| customers | one row per customer record | 99,441 | `customer_id` unique (one per order); 96,096 distinct `customer_unique_id` |
| order_items | one row per item sold | 112,650 | key is (`order_id`, `order_item_id`); up to 21 items per order |
| products | one row per product | 32,951 | `product_id` unique; 610 products have no category |
| category translation | one row per category | 71 | 2 of the 73 categories have no English name |
| order_reviews | one row per review | 99,224 | 547 orders have more than one review; 768 orders have none |

## Definitions

- **Valid orders**: all orders except `canceled` and `unavailable` — 98,207 of 99,441.
- **GMV**: sum of `order_items.price`, in Brazilian reais (BRL). Freight (2,241,126.29 in total) is kept separate. GMV here is not company revenue.
- **Month**: the month of `order_purchase_timestamp`.
- **Observation period for trends**: January 2017 to August 2018 (20 months). September, October and December 2016 and September 2018 hold only a handful of orders, and November 2016 has none, so they are excluded from trend statements.
- **Late delivery**: status `delivered`, a delivery timestamp present, and the delivery **date** after the estimated delivery date. The estimate carries no time of day, so comparing timestamps would wrongly count 1,292 same-day deliveries as late.
- **Low score**: a review score of 2 or less. When an order has several reviews, the latest one is used.

## Method

Monthly orders, monthly GMV, orders by state, delivery time and category GMV were each computed twice, once in SQL and once in pandas, and the two results were reconciled. The comparison of late deliveries and review scores exists in pandas only (notebook 07 and the export script).

- **Join discipline.** `order_items` has several rows per order. Monthly GMV joins orders to item totals already aggregated by order; SQL 07 joins item rows and then groups by order to build a base table with one row per order. Row counts, unique order IDs and control totals are checked in the analysis. A left join of orders to items yields 113,425 rows for 99,441 orders; counting those rows as orders would overstate volume by 14%.
- **Control totals.** Every breakdown of GMV must sum to **13,494,400.74**. The export script asserts this for the monthly and category files before writing them; the order-level base table in `sql/07_order_base.sql`, which the state figures are built on, is checked against the same total.
- **Missing values kept visible.** Products without a category are grouped as `(missing)` rather than dropped (178,572.55, 1.3% of GMV). Orders without a review stay in the order counts but not in review-score denominators.
- **Window functions** are used for month-over-month change (`LAG`), running totals (`SUM() OVER`), ranking (`RANK`) and top-row-per-group (`ROW_NUMBER() OVER (PARTITION BY ...)`).

## Findings

**1. Volume more than doubled in a year, then levelled off.** GMV for January–August rose from 3,080,851 in 2017 to 7,341,037 in 2018 (+138.3%), and valid orders from 22,562 to 53,531 (+137.3%). GMV per order barely moved, from 136.55 to 137.14 (+0.4%), so the growth in this sample comes almost entirely from more orders, not larger ones. The single highest month is November 2017 at 1,003,862, up 52.1% on October, followed by a 26.1% drop in December. From January to August 2018 monthly GMV stayed between 837,895 and 993,593.
*Limit:* the November peak coincides with Black Friday in Brazil, but the data does not identify the cause, and the sample is not Olist's full order book.

**2. GMV is concentrated in a few categories.** The top three — health_beauty (9.3%), watches_gifts (8.9%) and bed_bath_table (7.7%) — make up 25.9% of GMV, and the top ten 62.4%. Only 26 categories reach 1% each; the bottom half of the list (37 categories) totals 3.7%.
*Limit:* this ranks by item value, not units sold or margin, and covers all 24 months rather than the 20-month observation period (the four excluded months hold 0.3% of GMV).

**3. Late deliveries go with much lower review scores.** Of 96,470 delivered orders, 6,534 (6.8%) arrived after the estimated date. Among reviewed orders, 62.4% of late deliveries (3,982 of 6,381) scored 2 or less, with an average of 2.27; for on-time deliveries the share is 9.3% (8,290 of 89,443), with an average of 4.29.
*Limit:* this is an association, not a causal effect — late orders may share other problems such as stock-outs, slow sellers or remote destinations. A further 1,729 orders had passed their estimated date with no delivery record at the end of the data; they are not in the late rate.

**Also observed.** São Paulo state (SP) accounts for 41.9% of valid orders and 38.3% of GMV, yet has the lowest average order value of the 27 states (125.56 against 137.41 overall). The highest averages belong to states with very few orders (PB 216.34 on 531 orders), so they are not reliable on their own.

## Dashboard

The Tableau dashboard *Overview* is built from the three files in `data/exports/` and holds three sheets:

| Sheet | Shows | Source file | Scope |
|---|---|---|---|
| Monthly GMV | monthly item-price GMV | `data/exports/monthly_gmv.csv` | Jan 2017 – Aug 2018 |
| Top categories | top 10 categories by GMV, with share of total | `data/exports/category_gmv.csv` | all 24 months |
| Delay and reviews | low-score share, on-time vs late, with sample sizes | `data/exports/delay_review.csv` | delivered orders |

The three sheets cover different scopes and grains, so the dashboard has no shared date filter.

Live dashboard: [Tableau Public](https://public.tableau.com/app/profile/quan.zhou8823/viz/olist_gmv_overview_recovered/Overview). The packaged workbook is in this folder as `olist_gmv_overview_recovered.twbx`.

## Repository layout

```
olist/
├── download_data.py        fetch the raw CSVs into data/raw/ (not committed)
├── export_tableau.py       rebuild the three CSVs used by Tableau, with checks
├── data/exports/           monthly_gmv.csv, category_gmv.csv, delay_review.csv
├── notebooks/              01 data checks · 02 monthly orders · 03 monthly GMV · 04 orders by state
│                           05 delivery time · 06 monthly orders chart · 07 delay and reviews · 08 category GMV
├── sql/                    01 monthly orders · 02 monthly GMV · 03 orders by state · 04 delivery days
│                           05 GMV growth (LAG, running total) · 06 category rank · 07 order-level base table
└── reports/                findings.md
```

## How to run

Run everything from the repository root. Tested with Python 3.14, pandas 3.0 and PostgreSQL 18.

```bash
# 1. Python environment
python -m venv .venv
.venv/bin/pip install -r requirements.txt

# 2. Raw data (about 120 MB, public download through kagglehub)
.venv/bin/python olist/download_data.py

# 3. Rebuild the Tableau exports; fails loudly if a control total is off
.venv/bin/python olist/export_tableau.py
```

Expected output of step 3:

```
monthly_gmv.csv: (24, 7) total 13494400.74
category_gmv.csv: (74, 5) total 13494400.74
delay_review.csv: (2, 6) orders 96470
```

The SQL files run in `psql` against any PostgreSQL database. Start `psql` from the repository root, because the `\copy` paths are relative to it. Each file loads the CSVs it needs into temporary tables, so nothing permanent is created, and their `DROP` statements are limited to the `pg_temp` schema so that no existing table can be removed:

```bash
psql -X -v ON_ERROR_STOP=1 your_database -f olist/sql/06_category_gmv_rank.sql
```

The notebooks use the same `.venv` kernel and locate the project folder on their own.

## Limitations

- The dataset is a public sample released by Olist; totals describe this sample only.
- GMV is item price. It excludes freight and does not account for commissions, refunds or returns — the dataset has no refund table.
- All comparisons are descriptive. Nothing here measures the effect of changing delivery times, prices or assortment.
- Category names come from the dataset's own translation table; two categories have no English name and keep their Portuguese one.
- Customer-level analysis (repeat purchase, cohorts), payments and seller performance are not covered in this version.
