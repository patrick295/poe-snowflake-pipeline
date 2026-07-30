SELECT 
   ROUND (100.0 * SUM(on_time_flag) / COUNT(*),2) AS on_time_delivery_pct,
   ROUND(100.0 * SUM(satisfied_flag) / COUNT(*), 2)     AS satisfaction_pct,
   ROUND (100.0 * SUM(perfect_order_flag) / COUNT(*),2) AS perfect_order_pct,
FROM analytics.fact_orders;


This query calculates three company-wide KPI percentages from your fact table:

on_time_delivery_pct — What % of orders were delivered on or before the estimated delivery date
satisfaction_pct — What % of orders received a review score of 4 or 5 (satisfied customers)
perfect_order_pct — What % of orders achieved BOTH (on time AND satisfied) — the "perfect order" metric
How it works:

Each flag column (on_time_flag, satisfied_flag, perfect_order_flag) is either 1 or 0. SUM(flag) / COUNT(*) gives the ratio, multiplied by 100 for a percentage, rounded to 2 decimal places.

Note: There's a syntax error — there's a trailing comma after the last column (perfect_order_pct,) before FROM. That comma needs to be removed or it will fail.
   
