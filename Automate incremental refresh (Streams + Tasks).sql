CREATE STREAM raw.orders_stream ON TABLE raw.orders;

CREATE TASK analytics.refresh_fact_orders
  WAREHOUSE = poe_wh
  SCHEDULE = 'USING CRON 0 6 * * * America/Sao_Paulo'
WHEN SYSTEM$STREAM_HAS_DATA('raw.orders_stream')
AS
INSERT INTO analytics.fact_orders
SELECT
  o.order_id, o.customer_id, oi.product_id, oi.seller_id,
  o.order_purchase_timestamp::DATE, o.order_delivered_customer_date::DATE,
  o.order_estimated_delivery_date::DATE, oi.price, oi.freight_value, r.review_score,
  CASE WHEN o.order_status = 'delivered' AND o.order_delivered_customer_date <= o.order_estimated_delivery_date THEN 1 ELSE 0 END,
  CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END,
  CASE WHEN o.order_status = 'delivered' AND o.order_delivered_customer_date <= o.order_estimated_delivery_date AND r.review_score >= 4 THEN 1 ELSE 0 END
FROM raw.orders_stream o
JOIN raw.order_items oi ON o.order_id = oi.order_id
LEFT JOIN raw.order_reviews r ON o.order_id = r.order_id;

ALTER TASK analytics.refresh_fact_orders RESUME;


SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY()) ORDER BY scheduled_time DESC LIMIT 10;

ALTER USER PLOGMADE SET PASSWORD ='Nzekweebuka123';