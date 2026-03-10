-- ==============================================================================
-- dbt Projects on Snowflake - Task Scheduling
-- ==============================================================================
-- Run this script to create Snowflake Tasks for automated dbt execution
-- ==============================================================================

USE ROLE ACCOUNTADMIN;
USE DATABASE COURSE_DB;
USE SCHEMA DBT_PROJECTS;
USE WAREHOUSE DBT_WH;

-- ==============================================================================
-- SECTION 1: Simple Scheduled Task (Every 6 Hours)
-- ==============================================================================

-- Create a task that runs dbt build every 6 hours
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_BUILD_SCHEDULED
    WAREHOUSE = DBT_WH
    SCHEDULE = '360 MINUTES'
    COMMENT = 'Scheduled dbt build task - runs every 6 hours'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
        ARGS = 'build --target dev';

-- ==============================================================================
-- SECTION 2: CRON Scheduled Task (Daily at 6 AM UTC)
-- ==============================================================================

CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_DAILY_BUILD
    WAREHOUSE = DBT_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
    COMMENT = 'Daily dbt build at 6 AM UTC'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
        ARGS = 'build --target dev';

-- ==============================================================================
-- SECTION 3: Task DAG - Run Then Test
-- ==============================================================================

-- Parent task: Run models
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_RUN_MODELS
    WAREHOUSE = DBT_WH
    SCHEDULE = 'USING CRON 0 7 * * * UTC'
    COMMENT = 'Run dbt models daily at 7 AM UTC'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
        ARGS = 'run --target dev';

-- Child task: Test after run
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_TEST_MODELS
    WAREHOUSE = DBT_WH
    AFTER COURSE_DB.DBT_PROJECTS.DBT_RUN_MODELS
    COMMENT = 'Run dbt tests after models complete'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
        ARGS = 'test --target dev';

-- ==============================================================================
-- SECTION 4: Complex Task DAG (Layered Execution)
-- ==============================================================================

-- Root task: Load seeds
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_SEED
    WAREHOUSE = DBT_WH
    SCHEDULE = 'USING CRON 0 5 * * * UTC'
    COMMENT = 'Load seed data at 5 AM UTC'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
        ARGS = 'seed';

-- Layer 1: Build staging models
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_STAGING
    WAREHOUSE = DBT_WH
    AFTER COURSE_DB.DBT_PROJECTS.DBT_LAYERED_SEED
    COMMENT = 'Build staging models after seeds'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
        ARGS = 'run --select staging.*';

-- Layer 2: Build intermediate models
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_INTERMEDIATE
    WAREHOUSE = DBT_WH
    AFTER COURSE_DB.DBT_PROJECTS.DBT_LAYERED_STAGING
    COMMENT = 'Build intermediate models after staging'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
        ARGS = 'run --select intermediate.*';

-- Layer 3: Build mart models
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_MARTS
    WAREHOUSE = DBT_WH
    AFTER COURSE_DB.DBT_PROJECTS.DBT_LAYERED_INTERMEDIATE
    COMMENT = 'Build mart models after intermediate'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
        ARGS = 'run --select marts.*';

-- Layer 4: Run tests
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_TEST
    WAREHOUSE = DBT_WH
    AFTER COURSE_DB.DBT_PROJECTS.DBT_LAYERED_MARTS
    COMMENT = 'Run all tests after marts complete'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
        ARGS = 'test';

-- ==============================================================================
-- SECTION 5: Enable Tasks
-- ==============================================================================

-- Enable simple scheduled task
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_BUILD_SCHEDULED RESUME;

-- Enable daily build task
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_DAILY_BUILD RESUME;

-- Enable run-then-test DAG (child first, then parent)
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_TEST_MODELS RESUME;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_RUN_MODELS RESUME;

-- Enable layered DAG (from leaves to root)
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_TEST RESUME;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_MARTS RESUME;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_INTERMEDIATE RESUME;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_STAGING RESUME;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_SEED RESUME;

-- ==============================================================================
-- SECTION 6: Task Management Queries
-- ==============================================================================

-- View all tasks
SHOW TASKS IN SCHEMA COURSE_DB.DBT_PROJECTS;

-- View task history (last 24 hours)
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP()),
    RESULT_LIMIT => 100
))
ORDER BY SCHEDULED_TIME DESC;

-- ==============================================================================
-- SECTION 7: Suspend Tasks (Run when needed)
-- ==============================================================================

-- To suspend all tasks, uncomment and run:
/*
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_BUILD_SCHEDULED SUSPEND;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_DAILY_BUILD SUSPEND;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_RUN_MODELS SUSPEND;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_TEST_MODELS SUSPEND;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_SEED SUSPEND;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_STAGING SUSPEND;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_INTERMEDIATE SUSPEND;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_MARTS SUSPEND;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_LAYERED_TEST SUSPEND;
*/

-- ==============================================================================
-- SECTION 8: Manual Task Execution
-- ==============================================================================

-- Manually trigger a task (uncomment to run)
-- EXECUTE TASK COURSE_DB.DBT_PROJECTS.DBT_BUILD_SCHEDULED;

SELECT 'Task scheduling setup complete!' AS status;
