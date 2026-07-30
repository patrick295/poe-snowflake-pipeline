

— automation

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





Here's what each part does:

**1. Stream (Change Data Capture)**
```sql
CREATE STREAM raw.orders_stream ON TABLE raw.orders;
```
A stream tracks changes (inserts, updates, deletes) to `raw.orders` since the last time it was consumed. It's like a "what's new" queue on the table.

**2. Task (Scheduled Automation)**
```sql
CREATE TASK analytics.refresh_fact_orders ...
```
This creates a scheduled job that:
- **Runs daily at 6:00 AM São Paulo time** (`CRON 0 6 * * *`)
- **Only executes if there's new data** in the stream (`SYSTEM$STREAM_HAS_DATA`)
- **Inserts only the new/changed rows** into `fact_orders` (not a full rebuild) — this is the "incremental" part
- Computes the same KPI flags (`on_time_flag`, `satisfied_flag`, `perfect_order_flag`) for new rows

**3. Resume the Task**
```sql
ALTER TASK analytics.refresh_fact_orders RESUME;
```
Tasks are created in a suspended state. This activates it so it actually runs on schedule.

**4. Check Task History**
```sql
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY()) ...
```
Shows recent task executions — useful for confirming it ran and checking for errors.

**5. Password Reset** — this sets your login password.

**Important warning:** You have your password in plain text in this file (`Nzekweebuka123`). You should remove that line before pushing to GitHub or sharing this file — anyone who sees it can log into your account. I'd recommend removing it and changing your password.
