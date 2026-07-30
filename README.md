# Perfect Order Experience (POE) Analytics Pipeline
### Portfolio Project: Supply Chain KPIs on Snowflake — Olist Brazilian E-Commerce Dataset

---

## Business scenario

"Perfect Order Experience" is a standard supply-chain/logistics KPI framework: an order counts as "perfect" only if it's delivered on time, matches what was ordered, and the customer is satisfied with it. This project builds the analytics layer a logistics or e-commerce ops team would use to track that — on-time delivery rate, customer satisfaction rate, and a composite perfect-order rate, sliced by seller, product category, and region.

**Dataset:** [Olist Brazilian E-Commerce Public Dataset](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — ~100k real anonymized orders (2016–2018), 9 CSV files covering orders, order items, customers, sellers, products, payments, reviews, and geolocation.

This is a batch/historical dataset rather than a live API, which is why the architecture leans on Snowflake's native batch-loading and incremental-processing features (stages, `COPY INTO`, Streams, Tasks) instead of the Airflow-daily pattern from the sales reporting project — good for showing a different orchestration model in your portfolio.

---

## Architecture

```
Olist CSV files (Kaggle)
        │
  Python loader (boto3)
        │
   S3 raw zone
        │
  Snowflake external stage
  (storage integration + COPY INTO)
        │
   Raw tables (Snowflake)
        │
  SQL transforms: staging → star schema
        │
  fact_orders + dim_customer/seller/product/date
        │
  Snowflake Stream + Task
  (incremental refresh on new data)
        │
   Power BI dashboard
```

---

## Prerequisites

- Snowflake account (30-day free trial covers this comfortably — [signup.snowflake.com](https://signup.snowflake.com))
- AWS account (S3 only for this project)
- AWS CLI configured
- Kaggle account (to download the dataset) or `kaggle` CLI
- Power BI Desktop

---

## Step 1 — Get the dataset into S3

Download the 9 CSVs from Kaggle, then upload:

```bash
aws s3 mb s3://your-name-poe-pipeline --region eu-west-1

aws s3 cp ./olist_orders_dataset.csv s3://your-name-poe-pipeline/raw/
aws s3 cp ./olist_order_items_dataset.csv s3://your-name-poe-pipeline/raw/
aws s3 cp ./olist_customers_dataset.csv s3://your-name-poe-pipeline/raw/
aws s3 cp ./olist_sellers_dataset.csv s3://your-name-poe-pipeline/raw/
aws s3 cp ./olist_products_dataset.csv s3://your-name-poe-pipeline/raw/
aws s3 cp ./olist_order_reviews_dataset.csv s3://your-name-poe-pipeline/raw/
aws s3 cp ./olist_order_payments_dataset.csv s3://your-name-poe-pipeline/raw/
```

---

## Step 2 — Connect Snowflake to S3 (storage integration)

This is the Snowflake-specific piece worth understanding well for interviews — it's how Snowflake reads from your bucket without you ever handing it an AWS access key.

**In Snowflake:**
```sql
CREATE STORAGE INTEGRATION s3_poe_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::<your-account-id>:role/SnowflakePOERole'
  STORAGE_ALLOWED_LOCATIONS = ('s3://your-name-poe-pipeline/raw/');

DESC INTEGRATION s3_poe_integration;
```

`DESC INTEGRATION` returns `STORAGE_AWS_IAM_USER_ARN` and `STORAGE_AWS_EXTERNAL_ID` — copy both.

**In AWS**, create an IAM role (`SnowflakePOERole`) with a trust policy using those two values:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "<STORAGE_AWS_IAM_USER_ARN from Snowflake>" },
      "Action": "sts:AssumeRole",
      "Condition": {
        "StringEquals": { "sts:ExternalId": "<STORAGE_AWS_EXTERNAL_ID from Snowflake>" }
      }
    }
  ]
}
```
Attach a policy granting `s3:GetObject` and `s3:ListBucket` on `your-name-poe-pipeline`.

---

## Step 3 — File format, stage, warehouse, database

```sql
CREATE WAREHOUSE poe_wh WITH WAREHOUSE_SIZE = 'XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;
CREATE DATABASE poe_db;
CREATE SCHEMA poe_db.raw;
CREATE SCHEMA poe_db.analytics;
USE DATABASE poe_db;

CREATE FILE FORMAT raw.csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL');

CREATE STAGE raw.poe_stage
  URL = 's3://your-name-poe-pipeline/raw/'
  STORAGE_INTEGRATION = s3_poe_integration
  FILE_FORMAT = raw.csv_format;
```

`AUTO_SUSPEND = 60` matters for cost — the warehouse stops billing after 60 seconds idle, which is the single biggest lever for keeping a portfolio project free/cheap on Snowflake.

Confirm the stage can see your files:
```sql
LIST @raw.poe_stage;
```

---

## Step 4 — Load raw tables

```sql
CREATE TABLE raw.orders (
  order_id STRING, customer_id STRING, order_status STRING,
  order_purchase_timestamp TIMESTAMP, order_approved_at TIMESTAMP,
  order_delivered_carrier_date TIMESTAMP, order_delivered_customer_date TIMESTAMP,
  order_estimated_delivery_date TIMESTAMP
);

CREATE TABLE raw.order_items (
  order_id STRING, order_item_id INT, product_id STRING, seller_id STRING,
  shipping_limit_date TIMESTAMP, price FLOAT, freight_value FLOAT
);

CREATE TABLE raw.customers (
  customer_id STRING, customer_unique_id STRING, customer_zip_code_prefix STRING,
  customer_city STRING, customer_state STRING
);

CREATE TABLE raw.sellers (
  seller_id STRING, seller_zip_code_prefix STRING, seller_city STRING, seller_state STRING
);

CREATE TABLE raw.products (
  product_id STRING, product_category_name STRING, product_weight_g FLOAT,
  product_length_cm FLOAT, product_height_cm FLOAT, product_width_cm FLOAT
);

CREATE TABLE raw.order_reviews (
  review_id STRING, order_id STRING, review_score INT,
  review_comment_title STRING, review_comment_message STRING, review_creation_date TIMESTAMP
);

COPY INTO raw.orders FROM @raw.poe_stage/olist_orders_dataset.csv;
COPY INTO raw.order_items FROM @raw.poe_stage/olist_order_items_dataset.csv;
COPY INTO raw.customers FROM @raw.poe_stage/olist_customers_dataset.csv;
COPY INTO raw.sellers FROM @raw.poe_stage/olist_sellers_dataset.csv;
COPY INTO raw.products FROM @raw.poe_stage/olist_products_dataset.csv;
COPY INTO raw.order_reviews FROM @raw.poe_stage/olist_order_reviews_dataset.csv;
```

Sanity check row counts:
```sql
SELECT 'orders' AS tbl, COUNT(*) FROM raw.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM raw.order_items
UNION ALL SELECT 'customers', COUNT(*) FROM raw.customers;
```

---

## Step 5 — Star schema (analytics schema)

```sql
CREATE TABLE analytics.dim_customer AS
SELECT DISTINCT customer_id, customer_city, customer_state FROM raw.customers;

CREATE TABLE analytics.dim_seller AS
SELECT DISTINCT seller_id, seller_city, seller_state FROM raw.sellers;

CREATE TABLE analytics.dim_product AS
SELECT DISTINCT product_id, product_category_name FROM raw.products;

CREATE TABLE analytics.dim_date AS
SELECT
  DATEADD(day, seq4(), '2016-01-01') AS date_key,
  YEAR(date_key) AS year, MONTH(date_key) AS month, DAY(date_key) AS day,
  DAYNAME(date_key) AS day_of_week
FROM TABLE(GENERATOR(ROWCOUNT => 1200));

CREATE TABLE analytics.fact_orders AS
SELECT
  o.order_id,
  o.customer_id,
  oi.product_id,
  oi.seller_id,
  o.order_purchase_timestamp::DATE AS order_date,
  o.order_delivered_customer_date::DATE AS delivered_date,
  o.order_estimated_delivery_date::DATE AS estimated_delivery_date,
  oi.price,
  oi.freight_value,
  r.review_score,
  CASE WHEN o.order_status = 'delivered'
        AND o.order_delivered_customer_date <= o.order_estimated_delivery_date
       THEN 1 ELSE 0 END AS on_time_flag,
  CASE WHEN r.review_score >= 4 THEN 1 ELSE 0 END AS satisfied_flag,
  CASE WHEN o.order_status = 'delivered'
        AND o.order_delivered_customer_date <= o.order_estimated_delivery_date
        AND r.review_score >= 4
       THEN 1 ELSE 0 END AS perfect_order_flag
FROM raw.orders o
JOIN raw.order_items oi ON o.order_id = oi.order_id
LEFT JOIN raw.order_reviews r ON o.order_id = r.order_id;
```

`satisfied_flag` uses review score ≥4 as a proxy for "order matched expectations" — Olist doesn't have an explicit wrong-item flag, so this is a modeling decision worth being able to explain in an interview: what you'd use instead with a richer dataset (return/refund reason codes, damage claims), and why the proxy is reasonable here.

---

## Step 6 — POE KPI queries

```sql
-- Headline KPIs
SELECT
  ROUND(100.0 * SUM(on_time_flag) / COUNT(*), 2)      AS on_time_delivery_pct,
  ROUND(100.0 * SUM(satisfied_flag) / COUNT(*), 2)     AS satisfaction_pct,
  ROUND(100.0 * SUM(perfect_order_flag) / COUNT(*), 2) AS perfect_order_pct
FROM analytics.fact_orders;

-- By seller
SELECT
  s.seller_id, s.seller_state,
  COUNT(*) AS total_orders,
  ROUND(100.0 * SUM(f.perfect_order_flag) / COUNT(*), 2) AS perfect_order_pct
FROM analytics.fact_orders f
JOIN analytics.dim_seller s ON f.seller_id = s.seller_id
GROUP BY s.seller_id, s.seller_state
ORDER BY total_orders DESC
LIMIT 20;

-- By product category
SELECT
  p.product_category_name,
  COUNT(*) AS total_orders,
  ROUND(100.0 * SUM(f.on_time_flag) / COUNT(*), 2) AS on_time_pct
FROM analytics.fact_orders f
JOIN analytics.dim_product p ON f.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY total_orders DESC;
```

---

## Step 7 — Automate incremental refresh (Streams + Tasks)

This is the Snowflake-native equivalent of an Airflow DAG — a Stream tracks new rows landing in `raw.orders`, and a Task runs on a schedule but only actually does work when the stream has data.

```sql
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
```

Tasks are created suspended by default — `RESUME` is what actually turns the schedule on. Worth checking task history while testing:
```sql
SELECT * FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY()) ORDER BY scheduled_time DESC LIMIT 10;
```

---

## Step 8 — Connect Power BI

1. Power BI Desktop → Get Data → **Snowflake**
2. Server: `<account_identifier>.snowflakecomputing.com`
3. Warehouse: `poe_wh`, Database: `poe_db`, Schema: `analytics`
4. Import `fact_orders`, `dim_customer`, `dim_seller`, `dim_product`, `dim_date`; build relationships in Model view

**Suggested visuals:**
- KPI cards: perfect order %, on-time delivery %, satisfaction %
- Bar chart: perfect order rate by seller state
- Bar chart: on-time delivery rate by product category
- Line chart: perfect order rate trend over time (`dim_date`)
- Table: worst-performing sellers by perfect order rate (a real ops team would use this to flag underperforming partners)

---

## Cost control

- `AUTO_SUSPEND = 60` on the warehouse is the main lever — confirm it's actually applied: `SHOW WAREHOUSES;`
- X-Small warehouse is more than enough for ~100k rows; never scale up for this dataset size
- Suspend the warehouse manually when you're done demoing: `ALTER WAREHOUSE poe_wh SUSPEND;`
- Snowflake's free trial credits comfortably cover a project this size if auto-suspend is working

---

## Repo structure

```
sql/
  01_storage_integration.sql
  02_stage_and_formats.sql
  03_raw_tables_and_load.sql
  04_star_schema.sql
  05_kpi_queries.sql
  06_stream_and_task.sql
docs/
  architecture.png
  dashboard_screenshot.png
README.md
```
7. KPI queries — sanity check the numbers look plausible before building the dashboard on top
8. Stream + Task for automated refresh
9. Power BI dashboard
10. README + GitHub + LinkedIn writeup
