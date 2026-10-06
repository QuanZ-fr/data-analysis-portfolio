# Data analysis portfolio

Two end-to-end projects on public datasets. Each one states its definitions, checks its numbers against a second method, and reports the limits of what the data can show.

| Project | Question | Tools | Headline result |
|---|---|---|---|
| [Olist e-commerce](olist/README.md) | How did sales evolve, which categories carry them, and how do late deliveries relate to review scores? | PostgreSQL, pandas, Tableau | Item-price GMV grew 138% between January–August 2017 and the same months of 2018; the top 10 of 73 categories hold 62.4% of GMV; 62.4% of late deliveries received a review score of 2 or less, against 9.3% of on-time deliveries |
| [Telco customer churn](telco-customer-churn/README.md) | Which customer groups churn most, and how well can a simple model flag likely churners? | pandas, scikit-learn, SciPy | Logistic-regression Pipeline with a threshold chosen on validation data and frozen before the final evaluation: ROC-AUC 0.839 and churn-class F1 0.638 on 1,409 test customers |

All results describe public sample data. They are not estimates for a real company's current business.

## How the work is organised

- **Definitions first.** Every metric states its scope, its denominator and how missing values are treated before any number is reported.
- **Two methods, one number.** Olist's monthly orders, monthly GMV, orders by state, delivery time and category GMV are computed in SQL and in pandas and reconciled. The delivery/review comparison is computed in pandas. GMV breakdowns add up to the same control total.
- **Selection kept apart from evaluation.** In the churn project the model and threshold are chosen on validation data, frozen with a file hash, and only then evaluated on the test set.
- **Associations are reported as associations.** Neither project claims a causal effect.

## Running the code

Tested with Python 3.14, pandas 3.0, scikit-learn 1.9 and PostgreSQL 18.

```bash
python -m venv .venv
.venv/bin/pip install -r requirements.txt

# Raw data is not committed; both scripts download it through kagglehub
.venv/bin/python olist/download_data.py
.venv/bin/python telco-customer-churn/scripts/download_data.py
```

Each project README explains how to run its notebooks, SQL files and scripts.

## Data sources and licences

- [Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce), licensed CC BY-NC-SA 4.0. The three summary files in `olist/data/exports/` are derived from it and are shared under the same licence.
- [Telco Customer Churn](https://www.kaggle.com/datasets/blastchar/telco-customer-churn) on Kaggle.

The raw files of both datasets are left out of the repository and are fetched by the download scripts.
