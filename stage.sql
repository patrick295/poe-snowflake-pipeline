  CREATE STAGE raw.poe_stage
  URL = 's3://poe-test-analytics/raw/'
  STORAGE_INTEGRATION = s3_poe_integration
  FILE_FORMAT = raw.csv_format;

  LIST @raw.poe_stage;

  DESC INTEGRATION s3_poe_integration;

--DROP STAGE raw.poe_stage;

  