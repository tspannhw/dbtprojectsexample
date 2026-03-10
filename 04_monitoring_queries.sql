-- ==============================================================================
-- dbt Projects on Snowflake - Monitoring Queries
-- ==============================================================================
-- Useful queries for monitoring dbt project executions
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE COURSE_DB;
USE WAREHOUSE DBT_WH;

-- ==============================================================================
-- SECTION 1: View Recent Executions
-- ==============================================================================

-- Get all recent dbt project executions
SELECT
    query_id,
    object_name AS project_name,
    object_database || '.' || object_schema AS location,
    query_text,
    query_start_time,
    query_end_time,
    DATEDIFF('second', query_start_time, query_end_time) AS duration_seconds,
    execution_status,
    error_message
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY query_start_time DESC
LIMIT 50;

-- ==============================================================================
-- SECTION 2: Get Latest Query ID for a Project
-- ==============================================================================

SET latest_query_id = (
    SELECT query_id
    FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
    WHERE object_name = 'COURSE_DBT_PROJECT'
    ORDER BY query_end_time DESC
    LIMIT 1
);

SELECT $latest_query_id AS latest_execution_query_id;

-- ==============================================================================
-- SECTION 3: View Logs for Latest Execution
-- ==============================================================================

SELECT SYSTEM$GET_DBT_LOG($latest_query_id) AS dbt_logs;

-- ==============================================================================
-- SECTION 4: Locate Artifacts
-- ==============================================================================

-- Get folder path to artifacts
SELECT SYSTEM$LOCATE_DBT_ARTIFACTS($latest_query_id) AS artifacts_path;

-- Get ZIP archive URL
SELECT SYSTEM$LOCATE_DBT_ARCHIVE($latest_query_id) AS archive_url;

-- ==============================================================================
-- SECTION 5: Daily Execution Statistics
-- ==============================================================================

SELECT
    DATE(query_start_time) AS run_date,
    object_name AS project,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN execution_status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN execution_status = 'FAILED' THEN 1 ELSE 0 END) AS failed,
    ROUND(AVG(DATEDIFF('second', query_start_time, query_end_time)), 2) AS avg_duration_sec,
    MIN(DATEDIFF('second', query_start_time, query_end_time)) AS min_duration_sec,
    MAX(DATEDIFF('second', query_start_time, query_end_time)) AS max_duration_sec
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY 1 DESC, 2;

-- ==============================================================================
-- SECTION 6: Failed Executions Report
-- ==============================================================================

SELECT
    query_id,
    object_name AS project,
    query_start_time,
    DATEDIFF('second', query_start_time, query_end_time) AS duration_sec,
    error_message
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE execution_status = 'FAILED'
    AND query_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY query_start_time DESC;

-- ==============================================================================
-- SECTION 7: Execution by Command Type
-- ==============================================================================

SELECT
    REGEXP_SUBSTR(query_text, 'ARGS\\s*=\\s*''([a-z]+)', 1, 1, 'ie') AS dbt_command,
    COUNT(*) AS execution_count,
    SUM(CASE WHEN execution_status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN execution_status = 'FAILED' THEN 1 ELSE 0 END) AS failed,
    ROUND(AVG(DATEDIFF('second', query_start_time, query_end_time)), 2) AS avg_duration_sec
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 2 DESC;

-- ==============================================================================
-- SECTION 8: Task Execution History
-- ==============================================================================

SELECT
    name AS task_name,
    scheduled_time,
    completed_time,
    state,
    DATEDIFF('second', query_start_time, completed_time) AS duration_sec,
    error_message
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 100
))
WHERE DATABASE_NAME = 'COURSE_DB'
    AND SCHEMA_NAME = 'DBT_PROJECTS'
ORDER BY scheduled_time DESC;

-- ==============================================================================
-- SECTION 9: Cost Analysis (Warehouse Usage)
-- ==============================================================================

SELECT
    DATE(start_time) AS usage_date,
    warehouse_name,
    SUM(credits_used) AS total_credits,
    SUM(credits_used_compute) AS compute_credits,
    SUM(credits_used_cloud_services) AS cloud_credits
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name = 'DBT_WH'
    AND start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY 1 DESC;

-- ==============================================================================
-- SECTION 10: Create Monitoring Views
-- ==============================================================================

-- View for execution summary
CREATE OR REPLACE VIEW COURSE_DB.DBT_PROJECTS.V_DBT_EXECUTION_SUMMARY AS
SELECT
    query_id,
    object_name AS project_name,
    object_database || '.' || object_schema AS full_path,
    query_text,
    REGEXP_SUBSTR(query_text, 'ARGS\\s*=\\s*''([^'']+)''', 1, 1, 'e') AS dbt_args,
    query_start_time,
    query_end_time,
    DATEDIFF('second', query_start_time, query_end_time) AS duration_seconds,
    execution_status,
    error_message
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY());

-- View for daily stats
CREATE OR REPLACE VIEW COURSE_DB.DBT_PROJECTS.V_DBT_DAILY_STATS AS
SELECT
    DATE(query_start_time) AS run_date,
    project_name,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN execution_status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful_runs,
    SUM(CASE WHEN execution_status = 'FAILED' THEN 1 ELSE 0 END) AS failed_runs,
    ROUND(AVG(duration_seconds), 2) AS avg_duration_sec,
    MIN(duration_seconds) AS min_duration_sec,
    MAX(duration_seconds) AS max_duration_sec
FROM COURSE_DB.DBT_PROJECTS.V_DBT_EXECUTION_SUMMARY
GROUP BY 1, 2;

-- ==============================================================================
-- SECTION 11: Show All dbt Projects
-- ==============================================================================

SHOW DBT PROJECTS IN ACCOUNT;

SHOW DBT PROJECTS IN DATABASE COURSE_DB;

-- ==============================================================================
-- Complete!
-- ==============================================================================

SELECT 'Monitoring queries ready to use!' AS status;
