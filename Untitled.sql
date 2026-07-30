CREATE STORAGE INTEGRATION s3_poe_integration
  TYPE = EXTERNAL_STAGE
  STORAGE_PROVIDER = 'S3'
  ENABLED = TRUE
  STORAGE_AWS_ROLE_ARN = 'arn:aws:iam::358454002000:role/SnowflakePoeRole'
  STORAGE_ALLOWED_LOCATIONS = ('s3://poe-test-analytics/raw/');

DESC INTEGRATION s3_poe_integration;

--DROP STORAGE INTEGRATION s3_poe_integration
