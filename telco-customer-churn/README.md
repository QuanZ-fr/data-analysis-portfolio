# Telco Customer Churn: Analysis and Prediction

This project explores customer churn in a public telecom sample and builds a logistic-regression classifier to identify customers who may leave. The final, frozen model achieved a **0.6382 F1 score for churn (`Yes`)** and **0.8386 ROC-AUC** on the 1,409-customer test partition. These are sample-data results, not an estimate of performance for a live operator.

## Question and data

How does churn vary across customer groups, and how accurately can a model flag likely churners? The dataset is Kaggle's [Telco Customer Churn](https://www.kaggle.com/datasets/blastchar/telco-customer-churn), file `WA_Fn-UseC_-Telco-Customer-Churn.csv`. It contains **7,043 customers and 21 columns**, one row per `customerID`. The target is `Churn` (`Yes` for churn, `No` otherwise): 1,869 customers (26.54%) churned. The raw CSV is not committed; its expected SHA-256 and shape are recorded in the [dataset manifest](data/dataset_manifest.json).

The data checks found no duplicate customer IDs or complete records. `TotalCharges` arrives as text, with 11 blank entries, all for customers with zero tenure. For descriptive analysis, those entries were treated as zero. For modeling, they were converted to missing values and imputed using the median learned from the current training portion only. The raw file was not changed.

## Exploratory findings

| Customer group | Customers | Churned | Churn rate |
|---|---:|---:|---:|
| Month-to-month contract | 3,875 | 1,655 | 42.71% |
| Two-year contract | 1,695 | 48 | 2.83% |
| Tenure of 0–12 months | 2,186 | 1,037 | 47.44% |
| Tenure of 49–72 months | 2,239 | 213 | 9.51% |
| Fiber-optic internet | 3,096 | 1,297 | 41.89% |
| DSL internet | 2,421 | 459 | 18.96% |

The electronic-check group had 2,365 customers and 1,071 churners (45.29%). These are **descriptive associations**, not evidence that a contract type, service, or payment method causes churn. The group calculations and charts are in [02-eda.ipynb](notebooks/02-eda.ipynb).

## Modeling and decision rule

- A stratified 80/20 split (`random_state=2002`) produced **5,634 training** and **1,409 test** customers. Development used an additional split of the original training partition into **4,507 fitting** and **1,127 validation** customers. The original test partition was not used to choose the final model or threshold.
- The 19 input features exclude `customerID` and `Churn`. A `ColumnTransformer` selects three numeric columns by name (`tenure`, `MonthlyCharges`, `TotalCharges`) for median imputation and standard scaling; 16 categorical columns use `OneHotEncoder(handle_unknown="ignore")`. These steps and `LogisticRegression(max_iter=2800, solver="lbfgs", C=1.0, class_weight=None)` form one Pipeline. Each fitted transformation learns only from the relevant training fold or partition.
- Three-fold stratified cross-validation on the original training partition produced ROC-AUC scores of **0.8419, 0.8463, and 0.8524** (mean **0.8468**). The [Pipeline and CV notebook](notebooks/05-pipeline-cv.ipynb) also checks feature routing, an unseen categorical value, and errors by contract group.
- On the validation partition, scanning thresholds at 0.001 intervals gave the highest observed churn-class F1 at **0.409**: F1 **0.6745**, TP **202**, FP **98**, FN **97**, TN **730**. A threshold of 0.469 would limit predicted `Yes` cases to 250, but no 250-contact business limit was confirmed, so it was **not** selected. The features, model settings, threshold, and recipe hash were saved in the [frozen plan](reports/final-plan.json) before final evaluation.

## Final evaluation

An **unfitted Pipeline recipe** was exported as [`pipeline-recipe.joblib`](artifacts/pipeline-recipe.joblib). A clone of this recipe was fitted once on all 5,634 original training customers and evaluated on the 1,409-customer test partition using the frozen **0.409** threshold. The results are saved in [final-metrics.json](reports/final-metrics.json) and the [final-evaluation notebook](notebooks/06-final-evaluation.ipynb).

| Test metric | Result |
|---|---:|
| Actual churners / predicted churners | 374 / 400 |
| True negatives (TN) / false positives (FP) | 882 / 153 |
| False negatives (FN) / true positives (TP) | 127 / 247 |
| Churn-class precision / recall / F1 | 0.6175 / 0.6604 / 0.6382 |
| Accuracy / ROC-AUC | 0.8013 / 0.8386 |

At this threshold, 247 of the 400 flagged customers actually churned; 153 were false alarms, while 127 churners were missed. The dataset does not provide contact costs or a confirmed outreach capacity, so it cannot establish whether this is the best operational policy.

## Further analysis on the training set

- **Odds ratios** ([notebook 07](notebooks/07-odds-ratios.ipynb)). The frozen recipe fitted on the training set gives an odds ratio of 1.77 for month-to-month contracts and 0.46 for two-year contracts, a ratio of about 3.8 with the other features held constant. `tenure` has an odds ratio of 0.22 per standard deviation (about 24.6 months). `TotalCharges` is not interpreted on its own because it is collinear with `tenure`.
- **Effect size and risk profile** ([notebook 08](notebooks/08-effect-size-risk-profile.ipynb)). Cramér's V with churn is 0.41 for contract type, 0.35 for tenure band, 0.32 for internet service and 0.30 for payment method, against 0.02 for gender. Month-to-month customers with a tenure of 12 months or less number 1,597 in the training set and have a churn rate of 51.8%, against 6.7% for the 2,520 customers on one-year or two-year contracts.

Both are associations measured on the training set. Neither uses the test set, and neither shows what would happen if a customer's contract were changed.

## Files and reproducibility

From the repository root, install the dependencies in [requirements.txt](../requirements.txt), then fetch the CSV:

```bash
python telco-customer-churn/scripts/download_data.py
```

The script stores the CSV in `telco-customer-churn/data/raw/` and checks its SHA-256 against the [dataset manifest](data/dataset_manifest.json). The notebooks are [01 data understanding](notebooks/01-data-understanding.ipynb), [02 EDA](notebooks/02-eda.ipynb), [03 baseline modeling](notebooks/03-modeling.ipynb), [04 validation and thresholds](notebooks/04-validation-threshold.ipynb), [05 Pipeline and CV](notebooks/05-pipeline-cv.ipynb), [06 final evaluation](notebooks/06-final-evaluation.ipynb), [07 odds ratios](notebooks/07-odds-ratios.ipynb) and [08 effect size and risk profile](notebooks/08-effect-size-risk-profile.ipynb). They are run from the `notebooks/` directory.

Two safeguards keep the frozen plan and the reported result stable:

1. **The recipe cannot be overwritten by accident.** The export switch in notebook 05 is off, and notebooks 06 and 07 verify the recipe's SHA-256 against [final-plan.json](reports/final-plan.json) before using it.
2. **The final evaluation reproduces the saved record instead of replacing it.** Notebook 06 refits the frozen recipe on the 5,634 training customers, evaluates it on the 1,409 test customers, and asserts that all 18 values equal those in [final-metrics.json](reports/final-metrics.json). It does not write that file. The numbers reconcile by hand as well: `882 + 153 + 127 + 247 = 1,409`, `247 + 127 = 374` actual churners, and `247 + 153 = 400` predicted churners.

A reproduction in a separate environment has not been recorded.

## Limitations

This is a public teaching dataset, and group differences do not establish causation or generalize automatically to current telecom customers. The original test partition was viewed once during an earlier baseline experiment, so it is **not a fully untouched holdout**. The later Pipeline and threshold were selected using development data and frozen before the reported final evaluation; the test result has not been used to revise that choice. The validation F1 (0.6745) and final-test F1 (0.6382) differ, which is another reason not to promise a particular result on new customers.
