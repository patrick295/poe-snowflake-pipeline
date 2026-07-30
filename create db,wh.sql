-- Create POE warehouse, database, schemas, file format, and stage
-- Co-authored with CoCo
CREATE WAREHOUSE IF NOT EXISTS poe_wh WITH WAREHOUSE_SIZE ='XSMALL' AUTO_SUSPEND = 60 AUTO_RESUME = TRUE;
CREATE DATABASE IF NOT EXISTS poe_db;
CREATE SCHEMA IF NOT EXISTS poe_db.raw;
CREATE SCHEMA IF NOT EXISTS poe_db.analytis;
USE DATABASE poe_db;
USE SCHEMA raw;
USE WAREHOUSE poe_wh;

CREATE FILE FORMAT raw.csv_format
  TYPE = 'CSV'
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  NULL_IF = ('', 'NULL');

 CREATE STAGE raw.poe_stage
  URL = 's3://poe-test-analytics/raw/'
  STORAGE_INTEGRATION = s3_poe_integration
  FILE_FORMAT = raw.csv_format;

  LIST @raw.poe_stage;


--DROP STAGE IF EXISTS raw.poe_stage;
-- To avoid hitting this repeatedly, set a default context for your user once:
ALTER USER PLOGMADE SET DEFAULT_WAREHOUSE= poe_wh DEFAULT_NAMESPACE = 'poe_db.raw';




