-- Create star schema dimension and fact tables in analytics schema
-- Co-authored with CoCo

-- =============================================================================
-- STAR SCHEMA BUILD: POE_DB.ANALYTICS
-- =============================================================================
-- PURPOSE:
--   Transform raw Olist e-commerce data (POE_DB.RAW) into a star schema
--   optimized for analytics and reporting (POE_DB.ANALYTICS).
--
-- WHAT IS A STAR SCHEMA?
--   - Dimension tables (dim_*): descriptive lookup tables with distinct entities
--   - Fact table (fact_orders): transactional data with metrics and foreign keys
--     pointing to dimensions. This is what you query for dashboards/reports.
--
-- TABLES CREATED:
--   dim_customer   — unique customers with city/state
--   dim_seller     — unique sellers with city/state
--   dim_product    — unique products with category
--   dim_date       — generated calendar (2016-01-01 to ~2019-04-14)
--   fact_orders    — one row per order-item, with price, review, and KPI flags
--
-- KPI FLAGS IN FACT TABLE:
--   on_time_flag       = 1 if delivered on or before estimated delivery date
--   satisfied_flag     = 1 if customer review score >= 4
--   perfect_order_flag = 1 if BOTH on time AND satisfied
--
-- HOW TO CONNECT FROM POWER BI:
--   Server:    anchjpk-va30289.snowflakecomputing.com
--   Warehouse: POE_WH
--   Database:  POE_DB
--   Schema:    ANALYTICS
--   Username:  PLOGMADE
-- =============================================================================

CREATE TABLE analytics.dim_customer AS
SELECT DISTINCT customer_id , customer_city, customer_state FROM raw.customers;



CREATE TABLE analytics.dim_seller AS
SELECT DISTINCT seller_id, seller_city, seller_state FROM raw.sellers;


CREATE TABLE analytics.dim_product AS
SELECT DISTINCT product_id, product_category_name FROM raw.products;


SELECT COUNT (*) FROM analytics.dim_customer;
SELECT COUNT(*) FROM analytics.dim_seller;
SELECT COUNT(*) FROM analytics.dim_product;

--dim_date — the one that looks like magic but isn't

CREATE TABLE analytics.dim_date AS
SELECT
  DATEADD(day, seq4(),'2016-01-01') AS date_key,
  YEAR(date_key) AS year, MONTH (date_key) AS month, DAY(date_key) AS day,
  DAYNAME(date_key) AS day_of_week
FROM TABLE(GENERATOR(ROWCOUNT=>1200));  

SELECT MIN(date_key), MAX(date_key), COUNT(*) FROM analytics.dim_date;

CREATE OR REPLACE TABLE analytics.fact_orders AS
SELECT
  o.order_id,
  o.customer_id,
  oi.product_id,
  oi.seller_id,
  o.order_status,
  o.order_purchase_timestamp,
  o.order_delivered_customer_date,
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


SELECT COUNT(*) FROM analytics.fact_orders;

SELECT order_id, order_delivered_customer_date, order_status, review_score, price, freight_value
FROM analytics.fact_orders
LIMIT 20;