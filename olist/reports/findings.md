# Olist: findings

Every number below comes from the queries, notebooks and exports in this project and was recomputed from the raw data.

**Common definitions**
- Valid orders: all orders except `canceled` and `unavailable`, 98,207 of 99,441.
- GMV: sum of `order_items.price`, without freight, in Brazilian reais (BRL). Total over the whole period: 13,494,400.74.
- Orders are assigned to the month of purchase. Trends are read only from 2017-01 to 2018-08 (20 months): 2016-09, 2016-10, 2016-12 and 2018-09 hold very few orders, and 2016-11 has none.

---

## Finding 1: volume more than doubled in a year, then levelled off in 2018

- GMV for January–August was 7,341,037 in 2018 against 3,080,851 in 2017, an increase of **138.3%**. Valid orders rose from 22,562 to 53,531, an increase of 137.3%.
- GMV per order was 136.55 in January–August 2017 and 137.14 in the same months of 2018, up 0.4%. The growth comes almost entirely from more orders, not from larger ones.
- The highest single month is November 2017: 1,003,862, up 52.1% on October, with 7,423 orders (4,547 the month before). December fell back by 26.1%.
- From January to August 2018 monthly GMV stayed between 837,895 and 993,593, about 917,630 on average, without rising further.

Sources: Tableau sheet `Monthly GMV`; [SQL 02](../sql/02_monthly_gmv.sql), [SQL 05](../sql/05_monthly_gmv_growth.sql); [notebook 03](../notebooks/03-monthly-gmv.ipynb).

Limits:
- The data does not give the reason for the November 2017 peak. Black Friday in Brazil falls in late November, which fits the timing, but this was not tested and cannot be stated as "because of a promotion".
- This is a public sample of orders, not all of Olist's business. "Growth" means growth within this dataset.
- GMV is not company revenue: it excludes freight and does not deduct commissions or refunds.

## Finding 2: GMV is concentrated in a few categories; the top 10 hold 62.4%

- There are 73 categories plus one group of products without a category. The top three are health_beauty (1,255,695, 9.3%), watches_gifts (1,198,185, 8.9%) and bed_bath_table (1,035,964, 7.7%), together 25.9%.
- The top 10 add up to 8,416,564, or **62.4%**. Only 26 categories reach 1% each; the bottom half of the list (37 categories) totals 3.7%.
- Products without a category add up to 178,573, or 1.3%, and rank 21st. They are shown as their own row, not dropped.

Sources: Tableau sheet `Top categories`; [SQL 06](../sql/06_category_gmv_rank.sql); [notebook 08](../notebooks/08-category-gmv.ipynb).

Limits:
- This chart covers all 24 months, unlike the 20-month range of finding 1. The four months left out there hold about 44,871, or 0.3%, which does not affect the ranking.
- The denominator of each share is the total across all categories, not the total of the top 10.
- Ranking by value is not ranking by units sold or by profit: categories with high unit prices, such as watches, rank high on value without necessarily selling many items.
- Two categories have no English name in the dataset's translation table (pc_gamer, portateis_cozinha_e_preparadores_de_alimentos) and keep their original name. Both are small.

## Finding 3: the share of low review scores is almost seven times higher for late deliveries

- 96,470 orders were delivered and have a delivery timestamp. 6,534 of them arrived after the estimated date, a late rate of **6.8%** (compared by date; delivery on the estimated day is not late).
- Among reviewed orders, **62.4%** of late deliveries scored 2 or less (3,982 of 6,381), with a mean score of 2.27. For on-time deliveries the share is **9.3%** (8,290 of 89,443), with a mean of 4.29.
- Review coverage is high in both groups: 99.5% of on-time orders and 97.7% of late orders have a review.

Sources: Tableau sheet `Delay and reviews`; [notebook 07](../notebooks/07-delay-reviews.ipynb); section 3 of [export_tableau.py](../export_tableau.py).

Limits:
- This is an association, not a causal effect. Late orders may share other problems (stock-outs, slow dispatch by the seller, remote destinations) that are not controlled for. It does not follow that reducing delays would raise the score to 4.29.
- Another 1,729 orders had passed their estimated date with no delivery record when the data ends, and are not in the late rate. Counting them as not delivered on time would make the problem larger than 6.8%. No delivery record does not prove the customer received nothing; the status may simply not have been updated.
- When an order has several reviews, the latest is used. Only 547 orders have more than one, under 1%, so another rule would change the result very little.
- Lateness is compared by date. Comparing timestamps would add the 1,292 orders delivered on the estimated day and give a late rate of 8.1%.

## Also observed: the state with the most orders has the lowest average order value

- São Paulo state (SP) has 41,127 orders, 41.9% of all valid orders, and 38.3% of GMV, the largest of any state. Its average order value, 125.56, is the **lowest** of the 27 states; the overall average is 137.41.
- The top three states by GMV (SP, RJ, MG) hold 63.4% of GMV and 66.5% of orders.
- The highest average order values belong to PB (216.34 on 531 orders), AP (198.15 on 68 orders) and AC (197.32 on 81 orders), all with small volumes.

Sources: query 3 of [SQL 07](../sql/07_order_base.sql); [SQL 03](../sql/03_orders_by_state.sql); [notebook 04](../notebooks/04-orders-by-state.ipynb). There is no Tableau sheet for this one.

Limits:
- This is a description only. Possible explanations, such as higher freight to remote states encouraging fewer, larger purchases, or a few large orders in states with little volume, were not tested.
- AP and AC have only a few dozen orders each, so their averages are unstable and should not be read on their own.
- The state is the customer's delivery state, not the seller's location.
