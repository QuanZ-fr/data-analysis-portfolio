"""Export the three summary CSV files used by the Tableau workbook.

Definitions match sql/05_monthly_gmv_growth.sql, sql/06_category_gmv_rank.sql,
notebooks/07-delay-reviews.ipynb and notebooks/08-category-gmv.ipynb:
GMV = sum of price, no freight; valid orders only (canceled and unavailable
orders are excluded).

Usage (from the repository root):
    python olist/export_tableau.py
Output:
    olist/data/exports/monthly_gmv.csv
    olist/data/exports/category_gmv.csv
    olist/data/exports/delay_review.csv
"""

from pathlib import Path

import pandas as pd

ROOT = Path(__file__).resolve().parent
RAW = ROOT / "data" / "raw"
OUT = ROOT / "data" / "exports"
EXPECTED_TOTAL = 13494400.74

orders = pd.read_csv(RAW / "olist_orders_dataset.csv", parse_dates=["order_purchase_timestamp"])
items = pd.read_csv(RAW / "olist_order_items_dataset.csv")
products = pd.read_csv(RAW / "olist_products_dataset.csv")
translation = pd.read_csv(RAW / "product_category_name_translation.csv")
reviews = pd.read_csv(RAW / "olist_order_reviews_dataset.csv")

valid_orders = orders[~orders["order_status"].isin(["canceled", "unavailable"])]
valid_items = items[items["order_id"].isin(valid_orders["order_id"])]

# ---------- 1. Monthly GMV: month, GMV, previous month, MoM change, running total ----------
order_gmv = valid_items.groupby("order_id")["price"].sum().rename("order_gmv").reset_index()
base = valid_orders.merge(order_gmv, on="order_id", how="left")
base["purchase_month"] = base["order_purchase_timestamp"].dt.to_period("M").dt.to_timestamp()

monthly = base.groupby("purchase_month")["order_gmv"].sum().reset_index(name="gmv")
monthly = monthly.sort_values("purchase_month").reset_index(drop=True)
monthly["prev_gmv"] = monthly["gmv"].shift(1)
monthly["mom_pct"] = ((monthly["gmv"] - monthly["prev_gmv"]) / monthly["prev_gmv"] * 100).round(1)
monthly["cum_gmv"] = monthly["gmv"].cumsum().round(2)
monthly["gmv"] = monthly["gmv"].round(2)
monthly["prev_gmv"] = monthly["prev_gmv"].round(2)
# Observation period: 2017-01 to 2018-08 (months outside it have very few orders; 2016-11 has none)
monthly["in_observation_period"] = monthly["purchase_month"].between("2017-01-01", "2018-08-01")
# MoM is valid only when both this row and the previous one are in the observation period
monthly["mom_valid"] = monthly["in_observation_period"] & monthly["in_observation_period"].shift(1, fill_value=False)
monthly["purchase_month"] = monthly["purchase_month"].dt.strftime("%Y-%m-%d")

# ---------- 2. Category GMV: category, English name, GMV, rank, share ----------
merged = valid_items.merge(products[["product_id", "product_category_name"]], on="product_id", how="left")
assert len(merged) == len(valid_items), "item row count changed after the join"
merged["category"] = merged["product_category_name"].fillna("(missing)")

category = merged.groupby("category")["price"].sum().reset_index(name="gmv")
category = category.merge(
    translation.rename(columns={"product_category_name": "category", "product_category_name_english": "category_english"}),
    on="category",
    how="left",
)
# Categories absent from the translation table keep their original name
category["category_english"] = category["category_english"].fillna(category["category"])
category = category.sort_values("gmv", ascending=False).reset_index(drop=True)
category["rnk"] = category["gmv"].rank(method="min", ascending=False).astype(int)
category["pct"] = (category["gmv"] / category["gmv"].sum() * 100).round(1)
category["gmv"] = category["gmv"].round(2)
category = category[["rnk", "category", "category_english", "gmv", "pct"]]

# ---------- 3. Delay and reviews: one row for late orders, one for on-time orders ----------
# Same definitions as notebooks/07-delay-reviews.ipynb: delivered orders with a delivery
# timestamp; late = actual delivery date after the estimated date (compared by date);
# the latest review is kept when an order has several; a low score is 2 or less.
orders["delivered_ts"] = pd.to_datetime(orders["order_delivered_customer_date"], errors="coerce")
orders["estimated_ts"] = pd.to_datetime(orders["order_estimated_delivery_date"], errors="coerce")
kept = orders[(orders["order_status"] == "delivered") & orders["delivered_ts"].notna()].copy()
kept["is_late"] = kept["delivered_ts"].dt.normalize() > kept["estimated_ts"]

reviews["review_creation_ts"] = pd.to_datetime(reviews["review_creation_date"], errors="coerce")
reviews["review_answer_ts"] = pd.to_datetime(reviews["review_answer_timestamp"], errors="coerce")
review_per_order = reviews.sort_values(["review_creation_ts", "review_answer_ts"]).drop_duplicates(
    subset="order_id", keep="last"
)

delay = kept.merge(review_per_order[["order_id", "review_score"]], on="order_id", how="left")
assert len(delay) == len(kept), "order row count changed after the join"
delay["low_score"] = delay["review_score"] <= 2
reviewed = delay[delay["review_score"].notna()]          # reviewed orders only: the denominator of the share

summary = delay.groupby("is_late").agg(
    n_orders=("order_id", "count"),
    n_reviewed=("review_score", "count"),
    avg_score=("review_score", "mean"),
)
summary["n_low"] = reviewed.groupby("is_late")["low_score"].sum()
summary["low_pct"] = reviewed.groupby("is_late")["low_score"].mean() * 100

delay_review = summary.reset_index()
delay_review["group"] = delay_review["is_late"].map({False: "On time", True: "Late"})
delay_review["avg_score"] = delay_review["avg_score"].round(2)
delay_review["low_pct"] = delay_review["low_pct"].round(1)
delay_review = delay_review[["group", "n_orders", "n_reviewed", "n_low", "avg_score", "low_pct"]]

# ---------- 4. Check and write ----------
assert round(monthly["gmv"].sum(), 2) == EXPECTED_TOTAL, monthly["gmv"].sum()
assert round(category["gmv"].sum(), 2) == EXPECTED_TOTAL, category["gmv"].sum()
assert delay_review["n_orders"].sum() == 96470, delay_review["n_orders"].sum()

OUT.mkdir(parents=True, exist_ok=True)
monthly.to_csv(OUT / "monthly_gmv.csv", index=False)
category.to_csv(OUT / "category_gmv.csv", index=False)
delay_review.to_csv(OUT / "delay_review.csv", index=False)

print("monthly_gmv.csv:", monthly.shape, "total", round(monthly["gmv"].sum(), 2))
print("category_gmv.csv:", category.shape, "total", round(category["gmv"].sum(), 2))
print("delay_review.csv:", delay_review.shape, "orders", delay_review["n_orders"].sum())
