CREATE TABLE raw.orders (
  order_id STRING, customer_id STRING, order_status STRING,
  order_purchase_timestamp TIMESTAMP, order_approved_at TIMESTAMP,
  order_delivered_carrier_date TIMESTAMP, order_delivered_customer_date TIMESTAMP,
  order_estimated_delivery_date TIMESTAMP
);
--This is the table that connects orders to specific products and sellers — you'll join through this to get from orders to dim_product/dim_seller in Step 5.

CREATE TABLE raw.order_items (
  order_id STRING, order_item_id INT, product_id STRING, seller_id STRING,
  shipping_limit_date TIMESTAMP, price FLOAT, freight_value FLOAT
);

--raw.customers, raw.sellers — straightforward dimension source tables, one row per entity.

CREATE TABLE raw.customers (
  customer_id STRING, customer_unique_id STRING, customer_zip_code_prefix STRING,
  customer_city STRING, customer_state STRING
);

CREATE TABLE raw.sellers (
  seller_id STRING, seller_zip_code_prefix STRING, seller_city STRING, seller_state STRING
);

---raw.products — includes physical dimensions (weight, length, height, width) that Olist collected but that this project doesn't currently use — they're in the table because dropping columns from a COPY INTO source is more error-prone than just carrying them through and ignoring them in your star schema build.

CREATE TABLE raw.products (
  product_id STRING, product_category_name STRING, product_weight_g FLOAT,
  product_length_cm FLOAT, product_height_cm FLOAT, product_width_cm FLOAT
);

--raw.order_reviews — this is the table satisfied_flag in your fact table depends on entirely; review_score is an integer 1–5.

CREATE TABLE raw.order_reviews (
  review_id STRING, order_id STRING, review_score INT,
  review_comment_title STRING, review_comment_message STRING, review_creation_date TIMESTAMP
);

COPY INTO raw.orders        FROM @raw.poe_stage/ecommerce/olist_orders_dataset.csv;
COPY INTO raw.order_items   FROM @raw.poe_stage/ecommerce/olist_order_items_dataset.csv;
COPY INTO raw.customers     FROM @raw.poe_stage/ecommerce/olist_customers_dataset.csv;
COPY INTO raw.sellers       FROM @raw.poe_stage/ecommerce/olist_sellers_dataset.csv;
COPY INTO raw.products      FROM @raw.poe_stage/ecommerce/olist_products_dataset.csv;
COPY INTO raw.order_reviews FROM @raw.poe_stage/ecommerce/olist_order_reviews_dataset.csv;


SELECT * FROM raw.orders LIMIT 20;
SELECT COUNT (*) FROM raw.orders;

--TRUNCATE TABLE raw.orders;

SELECT COUNT (*) FROM raw.order_items;
SELECT COUNT(*) FROM raw.customers;
SELECT COUNT(*) FROM raw.sellers;
SELECT COUNT(*) FROM raw.products;
SELECT COUNT(*) FROM raw.order_reviews;

--Verify everything landed correctly this time

SELECT 'orders' AS tbl, COUNT(*) FROM raw.orders
UNION ALL SELECT 'order_items', COUNT(*) FROM raw.order_items
UNION ALL SELECT 'customers', COUNT(*) FROM raw.customers
UNION ALL SELECT 'sellers', COUNT(*) FROM raw.sellers
UNION ALL SELECT 'products', COUNT(*) FROM raw.products
UNION ALL SELECT 'order_reviews', COUNT(*) FROM raw.order_reviews;