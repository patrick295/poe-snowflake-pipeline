SELECT 
   ROUND (100.0 * SUM(on_time_flag) / COUNT(*),2) AS on_time_delivery_pct,
   ROUND(100.0 * SUM(satisfied_flag) / COUNT(*), 2)     AS satisfaction_pct,
   ROUND (100.0 * SUM(perfect_order_flag) / COUNT(*),2) AS perfect_order_pct,
FROM analytics.fact_orders;
   
