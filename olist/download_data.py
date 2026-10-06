"""Download the public Kaggle dataset "Brazilian E-Commerce Public Dataset by Olist"
and copy its CSV files to data/raw.

Source:  https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce
License: CC BY-NC-SA 4.0. data/raw is in .gitignore; the raw data is not committed.
Usage:   from the repository root, run `python olist/download_data.py`
"""

import shutil
from pathlib import Path

import kagglehub

RAW_DIR = Path(__file__).resolve().parent / "data" / "raw"
EXPECTED_CSV_FILES = {
    "olist_customers_dataset.csv",
    "olist_geolocation_dataset.csv",
    "olist_order_items_dataset.csv",
    "olist_order_payments_dataset.csv",
    "olist_order_reviews_dataset.csv",
    "olist_orders_dataset.csv",
    "olist_products_dataset.csv",
    "olist_sellers_dataset.csv",
    "product_category_name_translation.csv",
}


def main() -> None:
    src = Path(kagglehub.dataset_download("olistbr/brazilian-ecommerce"))
    csv_files = sorted(src.glob("*.csv"))
    missing = EXPECTED_CSV_FILES - {f.name for f in csv_files}
    if missing:
        raise FileNotFoundError(f"Dataset download is incomplete; missing CSV files: {sorted(missing)}")
    RAW_DIR.mkdir(parents=True, exist_ok=True)
    for f in csv_files:
        shutil.copy2(f, RAW_DIR / f.name)
    print(f"Cache location: {src}")
    print(f"Copied {len(csv_files)} CSV files to {RAW_DIR}")
    for f in csv_files:
        print(f"  {f.name}  {f.stat().st_size / 1e6:.1f} MB")


if __name__ == "__main__":
    main()
