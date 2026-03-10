# Section 4: Monitoring & Best Practices (10 minutes)

## Learning Objectives

By the end of this section, you will:
- Enable and configure monitoring features for dbt projects
- Use Snowsight monitoring UI effectively
- Access logs and artifacts programmatically
- Implement cost control strategies
- Apply production best practices
- Build a Streamlit monitoring dashboard
- Troubleshoot common issues

---

## 4.1 Enable Monitoring Features

To capture logging, tracing, and metrics for dbt project executions, configure the schema where your dbt projects reside:

```sql
-- ============================================
-- Enable comprehensive monitoring
-- ============================================

-- Set logging level (captures dbt stdout)
ALTER SCHEMA COURSE_DB.DBT_PROJECTS 
    SET LOG_LEVEL = 'INFO';

-- Enable tracing (captures execution details)
ALTER SCHEMA COURSE_DB.DBT_PROJECTS 
    SET TRACE_LEVEL = 'ALWAYS';

-- Capture all metrics
ALTER SCHEMA COURSE_DB.DBT_PROJECTS 
    SET METRIC_LEVEL = 'ALL';

-- Optional: Set on database level for all schemas
ALTER DATABASE COURSE_DB 
    SET LOG_LEVEL = 'INFO'
    TRACE_LEVEL = 'ALWAYS'
    METRIC_LEVEL = 'ALL';
```

### Monitoring Levels Explained

| Setting | Options | Description | Recommendation |
|---------|---------|-------------|----------------|
| `LOG_LEVEL` | OFF, ERROR, WARN, INFO, DEBUG | Verbosity of logs captured | **INFO** for production, **DEBUG** for troubleshooting |
| `TRACE_LEVEL` | OFF, ALWAYS, ON_EVENT | When to capture execution traces | **ALWAYS** for full visibility |
| `METRIC_LEVEL` | NONE, ALL | Whether to capture performance metrics | **ALL** for cost tracking |

> **💡 TIP: Log Level Selection**
> 
> | Level | Use Case | Performance Impact |
> |-------|----------|-------------------|
> | OFF | Maximum performance, no debugging | None |
> | ERROR | Production, only critical issues | Minimal |
> | WARN | Production, warnings + errors | Low |
> | INFO | Recommended default | Low |
> | DEBUG | Development/troubleshooting only | Higher |

> **⚠️ WARNING: DEBUG Level in Production**
> 
> Avoid using `DEBUG` log level in production:
> - Significantly increases log volume
> - May expose sensitive query patterns
> - Increases storage costs
> - Use only temporarily for troubleshooting

### Verify Settings

```sql
-- Check current settings on schema
SHOW PARAMETERS LIKE '%LEVEL%' IN SCHEMA COURSE_DB.DBT_PROJECTS;

-- Check settings on database
SHOW PARAMETERS LIKE '%LEVEL%' IN DATABASE COURSE_DB;

-- Verify settings are applied
SELECT 
    'LOG_LEVEL' AS parameter,
    SYSTEM$GET_LOG_LEVEL('COURSE_DB.DBT_PROJECTS') AS value
UNION ALL
SELECT 
    'TRACE_LEVEL',
    SYSTEM$GET_TRACE_LEVEL('COURSE_DB.DBT_PROJECTS')
UNION ALL
SELECT 
    'METRIC_LEVEL',
    SYSTEM$GET_METRIC_LEVEL('COURSE_DB.DBT_PROJECTS');
```

> **📚 REFERENCE: Monitoring Configuration**
> - [Snowflake Logging and Tracing](https://docs.snowflake.com/en/developer-guide/logging-tracing/logging-tracing-overview)
> - [Setting Log Levels](https://docs.snowflake.com/en/sql-reference/parameters#log-level)

---

## 4.2 Snowsight Monitoring UI

### Accessing dbt Monitoring

Snowsight provides a dedicated UI for monitoring dbt project executions:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Snowsight Navigation                                 │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   1. Navigate to: Data Engineering → dbt Projects                           │
│      (Or: Transformation → dbt Projects in older UI)                        │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  dbt Projects                                           [Refresh]   │  │
│   │  ─────────────                                                      │  │
│   │                                                                     │  │
│   │  [Histogram showing run frequency over time - last 7 days]         │  │
│   │  ████ ██ ████████ ██████ ████ ██████ ████████                      │  │
│   │                                                                     │  │
│   │  Filter: [All Databases ▼] [All Schemas ▼] [Last 7 days ▼]        │  │
│   │                                                                     │  │
│   │  PROJECT          LAST COMMAND  STATUS   LAST RUN    HISTORY       │  │
│   │  ───────────────  ────────────  ──────   ─────────   ──────────    │  │
│   │  course_project   build         ✓ Pass   2m ago      ✓✓✓✓✗✓✓✓     │  │
│   │  sales_pipeline   run           ✓ Pass   1h ago      ✓✓✓✓✓✓✓✓     │  │
│   │  marketing_dbt    test          ✗ Fail   30m ago     ✓✓✗✓✓✗✓✓     │  │
│   │                                                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   2. Click on a project row to see execution details                       │
│   3. Click on a specific run in HISTORY to see that run's details         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Run Details View

For each dbt project execution, click to view comprehensive details:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│  Run Details: course_project - build                                        │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  [Job Details] [dbt Output] [Output] [Trace]                               │
│                                                                             │
│  ┌─ JOB DETAILS ───────────────────────────────────────────────────────┐   │
│  │                                                                      │   │
│  │  Status:        ✓ SUCCESS                                           │   │
│  │  Start Time:    2024-03-05 10:15:23 UTC                            │   │
│  │  End Time:      2024-03-05 10:16:05 UTC                            │   │
│  │  Duration:      42 seconds                                          │   │
│  │  Warehouse:     DBT_WH (XSMALL)                                    │   │
│  │  Query ID:      01bf51c1-0000-1234-0000-00012345abcd               │   │
│  │  dbt Version:   1.10.15                                            │   │
│  │                                                                      │   │
│  │  SQL Statement:                                                     │   │
│  │  EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT         │   │
│  │      ARGS = 'build --target prod';                                  │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
│  ┌─ dbt OUTPUT ────────────────────────────────────────────────────────┐   │
│  │                                                                      │   │
│  │  Models: 8 passed, 0 failed, 0 skipped                             │   │
│  │  Tests:  12 passed, 0 failed, 0 skipped                            │   │
│  │  Seeds:  2 passed, 0 failed, 0 skipped                             │   │
│  │                                                                      │   │
│  │  Model                    Time     Status                           │   │
│  │  ─────────────────────    ────     ──────                           │   │
│  │  stg_customers            1.2s     ✓ OK                             │   │
│  │  stg_orders               1.5s     ✓ OK                             │   │
│  │  stg_products             1.1s     ✓ OK                             │   │
│  │  int_customer_orders      3.2s     ✓ OK                             │   │
│  │  dim_customers            2.8s     ✓ OK                             │   │
│  │  fct_orders               4.1s     ✓ OK                             │   │
│  │                                                                      │   │
│  └──────────────────────────────────────────────────────────────────────┘   │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

| Tab | Information | Use Case |
|-----|-------------|----------|
| **Job Details** | Status, timestamps, warehouse, Query ID, SQL text | Quick overview |
| **dbt Output** | Model execution details, pass/fail counts, timing | Performance analysis |
| **Output** | Raw stdout from dbt execution | Debugging |
| **Trace** | Execution trace with timing breakdown | Deep performance analysis |

> **💡 TIP: Using Query ID for Deep Dives**
> 
> From any run, click the **Query ID** to access:
> - **Query Details**: Full SQL statement and metadata
> - **Query Profile**: Visual execution plan with step timings
> - **Query Telemetry**: Spilling, partition pruning, scan efficiency
> 
> This is invaluable for optimizing slow-running models.

> **💡 TIP: Quick Filters**
> 
> Use the filter dropdowns to quickly find:
> - Runs from a specific database or schema
> - Runs within a time range
> - Only failed runs (click the filter icon on Status column)

---

## 4.3 Programmatic Access to Logs & Artifacts

### System Functions Overview

| Function | Returns | Use Case |
|----------|---------|----------|
| `SYSTEM$GET_DBT_LOG(query_id)` | Log text (VARCHAR) | Quick debugging, alerting |
| `SYSTEM$LOCATE_DBT_ARTIFACTS(query_id)` | Folder path (VARCHAR) | Browse compiled SQL, manifest |
| `SYSTEM$LOCATE_DBT_ARCHIVE(query_id)` | ZIP file URL (VARCHAR) | Download all artifacts |

### Get Latest Query ID

```sql
-- ============================================
-- Find most recent execution for a project
-- ============================================
SELECT 
    query_id,
    object_name AS project_name,
    query_start_time,
    execution_status
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE UPPER(object_name) = 'COURSE_PROJECT'
ORDER BY query_end_time DESC
LIMIT 5;

-- Store in session variable
SET latest_query_id = (
    SELECT query_id
    FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
    WHERE UPPER(object_name) = 'COURSE_PROJECT'
    ORDER BY query_end_time DESC
    LIMIT 1
);

SELECT $latest_query_id AS latest_query_id;

-- ============================================
-- Find most recent FAILED execution
-- ============================================
SET failed_query_id = (
    SELECT query_id
    FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
    WHERE execution_status = 'FAILED'
    ORDER BY query_end_time DESC
    LIMIT 1
);
```

### View Logs

```sql
-- ============================================
-- Get dbt run logs (quick debugging)
-- ============================================
SELECT SYSTEM$GET_DBT_LOG($latest_query_id) AS dbt_log;

-- Parse log for specific patterns
SELECT 
    VALUE AS log_line,
    CASE 
        WHEN VALUE LIKE '%ERROR%' THEN 'ERROR'
        WHEN VALUE LIKE '%WARN%' THEN 'WARNING'
        WHEN VALUE LIKE '%OK%' THEN 'SUCCESS'
        ELSE 'INFO'
    END AS log_level
FROM TABLE(SPLIT_TO_TABLE(SYSTEM$GET_DBT_LOG($latest_query_id), '\n'))
WHERE VALUE != '';
```

**Sample log output:**
```
[0m15:14:53.100781 [info ] [Dummy-1 ]: Running with dbt=1.9.4
[0m15:14:53.234567 [info ] [Dummy-1 ]: Found 8 models, 12 tests, 2 seeds, 2 snapshots
[0m15:14:55.456789 [info ] [Dummy-1 ]: 
[0m15:14:55.456789 [info ] [Dummy-1 ]: Concurrency: 4 threads (target='prod')
[0m15:14:55.456789 [info ] [Dummy-1 ]: 
[0m15:14:56.123456 [info ] [Dummy-1 ]: 1 of 8 START view model STAGING.stg_customers
[0m15:14:57.234567 [info ] [Dummy-1 ]: 1 of 8 OK created view model STAGING.stg_customers [SUCCESS in 1.11s]
...
[0m15:15:35.198545 [info ] [Dummy-1 ]: Finished running 8 views, 12 tests in 42.10s.
[0m15:15:35.198545 [info ] [Dummy-1 ]: 
[0m15:15:35.198545 [info ] [Dummy-1 ]: Completed successfully
```

> **💡 TIP: Parsing Logs for Monitoring**
> 
> ```sql
> -- Extract model timing from logs
> SELECT 
>     REGEXP_SUBSTR(VALUE, '(stg_|int_|dim_|fct_|agg_)[a-z_]+', 1, 1, 'i') AS model_name,
>     REGEXP_SUBSTR(VALUE, '\\[SUCCESS in ([0-9.]+)s\\]', 1, 1, 'e') AS duration_seconds,
>     CASE 
>         WHEN VALUE LIKE '%OK%' THEN 'SUCCESS'
>         WHEN VALUE LIKE '%ERROR%' THEN 'ERROR'
>         ELSE NULL
>     END AS status
> FROM TABLE(SPLIT_TO_TABLE(SYSTEM$GET_DBT_LOG($latest_query_id), '\n'))
> WHERE VALUE LIKE '%OK%' OR VALUE LIKE '%ERROR%';
> ```

### Locate Artifacts

```sql
-- ============================================
-- Get artifacts folder path
-- ============================================
SELECT SYSTEM$LOCATE_DBT_ARTIFACTS($latest_query_id) AS artifacts_path;

-- Returns path like:
-- snow://dbt/COURSE_DB.DBT_PROJECTS.COURSE_PROJECT/results/01bf51c1-0000-1234.../
```

### List and Access Artifact Files

```sql
-- ============================================
-- List all files in artifacts folder
-- ============================================
-- First, get the path
SET artifacts_path = (SELECT SYSTEM$LOCATE_DBT_ARTIFACTS($latest_query_id));

-- List contents
LIST @course_db.dbt_projects.course_project/results/;

-- Common artifact files:
-- ├── manifest.json        (Project metadata, dependencies)
-- ├── run_results.json     (Execution results)
-- ├── catalog.json         (Documentation catalog)
-- ├── compiled/            (Compiled SQL for each model)
-- │   └── models/
-- │       ├── staging/
-- │       ├── intermediate/
-- │       └── marts/
-- └── logs/
--     └── dbt.log
```

> **💡 TIP: Key Artifact Files**
> 
> | File | Contents | Use Case |
> |------|----------|----------|
> | `manifest.json` | Full project graph, node definitions | CI/CD validation, lineage |
> | `run_results.json` | Execution status for each node | Automated monitoring |
> | `catalog.json` | Documentation for dbt docs | Documentation generation |
> | `compiled/*.sql` | Actual SQL executed | Debugging, auditing |

### Download Artifacts

```sql
-- ============================================
-- Get ZIP archive URL for bulk download
-- ============================================
SELECT SYSTEM$LOCATE_DBT_ARCHIVE($latest_query_id) AS archive_url;

-- ============================================
-- Copy artifacts to your own stage
-- ============================================
-- Create destination stage
CREATE OR REPLACE STAGE dbt_artifacts_stage
    ENCRYPTION = (TYPE = 'SNOWFLAKE_SSE')
    COMMENT = 'Storage for dbt artifacts';

-- Copy all artifacts
COPY FILES INTO @dbt_artifacts_stage/executions/
    FROM (SELECT SYSTEM$LOCATE_DBT_ARTIFACTS($latest_query_id));

-- List copied files
LIST @dbt_artifacts_stage/executions/;
```

### Using Snowflake CLI for Artifacts

```bash
# Get logs via CLI
snow sql -q "SELECT SYSTEM\$GET_DBT_LOG('01bf51c1-0000-1234-0000-00012345abcd')"

# Get artifacts path
snow sql -q "SELECT SYSTEM\$LOCATE_DBT_ARTIFACTS('01bf51c1-0000-1234-0000-00012345abcd')"

# Download manifest.json
snow stage get \
    'snow://dbt/COURSE_DB.DBT_PROJECTS.COURSE_PROJECT/results/01bf51c1.../manifest.json' \
    ./artifacts/

# Download all artifacts
snow stage get \
    'snow://dbt/COURSE_DB.DBT_PROJECTS.COURSE_PROJECT/results/01bf51c1.../' \
    ./artifacts/ \
    --recursive
```

> **📚 REFERENCE: Artifacts**
> - [dbt Artifacts Documentation](https://docs.getdbt.com/reference/artifacts/dbt-artifacts)
> - [Manifest Reference](https://docs.getdbt.com/reference/artifacts/manifest-json)

---

## 4.4 Execution History Queries

### DBT_PROJECT_EXECUTION_HISTORY Table Function

This is your primary tool for monitoring dbt executions:

```sql
-- ============================================
-- View recent executions with full details
-- ============================================
SELECT
    query_id,
    object_name AS project_name,
    object_database || '.' || object_schema AS project_path,
    REGEXP_SUBSTR(query_text, 'ARGS\\s*=\\s*''([^'']+)''', 1, 1, 'e') AS dbt_command,
    query_start_time,
    query_end_time,
    DATEDIFF('second', query_start_time, query_end_time) AS duration_seconds,
    execution_status,
    CASE 
        WHEN execution_status = 'SUCCESS' THEN '✓'
        WHEN execution_status = 'FAILED' THEN '✗'
        ELSE '?'
    END AS status_icon,
    error_message
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY query_start_time DESC
LIMIT 50;
```

### Execution Statistics Dashboard Queries

```sql
-- ============================================
-- Daily execution summary
-- ============================================
SELECT
    DATE(query_start_time) AS run_date,
    object_name AS project,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN execution_status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful,
    SUM(CASE WHEN execution_status = 'FAILED' THEN 1 ELSE 0 END) AS failed,
    ROUND(100.0 * SUM(CASE WHEN execution_status = 'SUCCESS' THEN 1 ELSE 0 END) / COUNT(*), 1) AS success_rate_pct,
    ROUND(AVG(DATEDIFF('second', query_start_time, query_end_time)), 2) AS avg_duration_sec,
    MIN(DATEDIFF('second', query_start_time, query_end_time)) AS min_duration_sec,
    MAX(DATEDIFF('second', query_start_time, query_end_time)) AS max_duration_sec
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY 1 DESC, 2;

-- ============================================
-- Hourly execution pattern (find peak hours)
-- ============================================
SELECT
    HOUR(query_start_time) AS hour_of_day,
    COUNT(*) AS run_count,
    AVG(DATEDIFF('second', query_start_time, query_end_time)) AS avg_duration
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 1;

-- ============================================
-- Command breakdown (which commands run most)
-- ============================================
SELECT
    COALESCE(
        REGEXP_SUBSTR(query_text, 'ARGS\\s*=\\s*''([a-z]+)', 1, 1, 'ei'),
        'run'
    ) AS dbt_command,
    COUNT(*) AS execution_count,
    SUM(CASE WHEN execution_status = 'SUCCESS' THEN 1 ELSE 0 END) AS successful,
    ROUND(AVG(DATEDIFF('second', query_start_time, query_end_time)), 1) AS avg_duration_sec
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -30, CURRENT_TIMESTAMP())
GROUP BY 1
ORDER BY 2 DESC;
```

### Failed Executions Report

```sql
-- ============================================
-- View failed runs with error details and logs
-- ============================================
SELECT
    query_id,
    object_name AS project,
    query_start_time,
    REGEXP_SUBSTR(query_text, 'ARGS\\s*=\\s*''([^'']+)''', 1, 1, 'e') AS command,
    DATEDIFF('second', query_start_time, query_end_time) AS duration_sec,
    error_message,
    LEFT(SYSTEM$GET_DBT_LOG(query_id), 2000) AS log_preview
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE execution_status = 'FAILED'
    AND query_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY query_start_time DESC;

-- ============================================
-- Failure trend analysis
-- ============================================
SELECT
    DATE(query_start_time) AS date,
    object_name AS project,
    COUNT(*) AS total_runs,
    SUM(CASE WHEN execution_status = 'FAILED' THEN 1 ELSE 0 END) AS failures,
    ROUND(100.0 * SUM(CASE WHEN execution_status = 'FAILED' THEN 1 ELSE 0 END) / COUNT(*), 1) AS failure_rate_pct
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -14, CURRENT_TIMESTAMP())
GROUP BY 1, 2
HAVING failures > 0
ORDER BY 1 DESC, 5 DESC;
```

> **💡 TIP: Create Monitoring Views**
> 
> Create persistent views for easy monitoring:
> ```sql
> CREATE OR REPLACE VIEW v_dbt_executions AS
> SELECT * FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY());
> 
> -- Then query simply:
> SELECT * FROM v_dbt_executions WHERE execution_status = 'FAILED';
> ```

---

## 4.5 Cost Control Strategies

### 1. Warehouse Sizing Guidelines

```sql
-- ============================================
-- Create appropriately sized warehouses
-- ============================================

-- Development/Testing (minimal cost)
CREATE WAREHOUSE IF NOT EXISTS DBT_WH_DEV
    WITH 
        WAREHOUSE_SIZE = 'XSMALL'
        AUTO_SUSPEND = 60
        AUTO_RESUME = TRUE
        INITIALLY_SUSPENDED = TRUE
        COMMENT = 'Development dbt runs - minimal size';

-- Production (balanced)
CREATE WAREHOUSE IF NOT EXISTS DBT_WH_PROD
    WITH 
        WAREHOUSE_SIZE = 'SMALL'
        AUTO_SUSPEND = 120
        AUTO_RESUME = TRUE
        MIN_CLUSTER_COUNT = 1
        MAX_CLUSTER_COUNT = 2
        SCALING_POLICY = 'ECONOMY'
        COMMENT = 'Production dbt runs';

-- Heavy workloads (performance)
CREATE WAREHOUSE IF NOT EXISTS DBT_WH_LARGE
    WITH 
        WAREHOUSE_SIZE = 'MEDIUM'
        AUTO_SUSPEND = 60
        AUTO_RESUME = TRUE
        COMMENT = 'Large dbt runs and full refreshes';
```

> **💡 TIP: Warehouse Sizing Decision Matrix**
> 
> | Scenario | Warehouse Size | Reason |
> |----------|---------------|--------|
> | Development runs | XSMALL | Low cost, sufficient for testing |
> | Daily incremental | SMALL | Balance of cost/speed |
> | Full refreshes | MEDIUM-LARGE | Large data scans |
> | Initial loads | LARGE+ | Bulk processing |
> | Ad-hoc queries | XSMALL-SMALL | Interactive use |

> **⚠️ WARNING: Auto-Suspend Settings**
> 
> - **60 seconds**: Good default for most dbt workloads
> - **0 (never suspend)**: Avoid unless you have continuous runs
> - **Longer suspension**: Only for highly interactive scenarios
> 
> Every minute idle costs credits!

### 2. Use Incremental Models

Incremental models process only new/changed data, dramatically reducing costs:

```sql
-- models/marts/fct_orders_incremental.sql
{{
    config(
        materialized='incremental',
        unique_key='order_id',
        incremental_strategy='merge',  -- or 'delete+insert' or 'append'
        cluster_by=['order_date']
    )
}}

WITH source_data AS (
    SELECT
        order_id,
        customer_id,
        order_date,
        status,
        total_amount,
        created_at,
        updated_at
    FROM {{ ref('stg_orders') }}
    
    {% if is_incremental() %}
    -- Only process new/updated records
    WHERE updated_at > (
        SELECT COALESCE(MAX(updated_at), '1900-01-01') 
        FROM {{ this }}
    )
    {% endif %}
)

SELECT
    {{ generate_surrogate_key(['order_id']) }} AS order_key,
    *,
    CURRENT_TIMESTAMP() AS dbt_updated_at
FROM source_data
```

> **💡 TIP: Incremental Strategy Selection**
> 
> | Strategy | Use Case | Performance |
> |----------|----------|-------------|
> | `merge` | Updates + inserts | Best for most cases |
> | `delete+insert` | Simpler, no updates | Good for append-mostly |
> | `append` | Insert only, no updates | Fastest, event data |
> | `insert_overwrite` | Partition replacement | Large partition updates |

### 3. Resource Monitors

Set spending limits to prevent runaway costs:

```sql
-- ============================================
-- Create resource monitor for dbt workloads
-- ============================================
CREATE OR REPLACE RESOURCE MONITOR dbt_cost_monitor
    WITH 
        CREDIT_QUOTA = 500           -- Monthly credit limit
        FREQUENCY = MONTHLY
        START_TIMESTAMP = IMMEDIATELY
        TRIGGERS
            ON 50 PERCENT DO NOTIFY   -- Email at 50%
            ON 75 PERCENT DO NOTIFY   -- Email at 75%
            ON 90 PERCENT DO NOTIFY   -- Email at 90%
            ON 100 PERCENT DO SUSPEND -- Stop warehouse at 100%
            ON 110 PERCENT DO SUSPEND_IMMEDIATE;  -- Force stop

-- Assign to dbt warehouse
ALTER WAREHOUSE DBT_WH_PROD SET RESOURCE_MONITOR = dbt_cost_monitor;

-- View monitor status
SHOW RESOURCE MONITORS LIKE 'dbt%';

-- Check credit usage
SELECT * FROM TABLE(INFORMATION_SCHEMA.RESOURCE_MONITOR_USAGE_HISTORY())
WHERE monitor_name = 'DBT_COST_MONITOR';
```

> **⚠️ WARNING: Resource Monitor Gotchas**
> 
> - **SUSPEND**: Queued queries complete, new queries blocked
> - **SUSPEND_IMMEDIATE**: All queries terminated immediately
> - Set SUSPEND_IMMEDIATE at 110%+ to allow graceful completion
> - Monitors only track compute credits, not storage

### 4. Query Tags for Cost Attribution

Track costs by project, environment, and team:

```yaml
# profiles.yml - Add query tags
course_dbt_project:
  target: prod
  outputs:
    prod:
      type: snowflake
      # ... connection settings ...
      query_tag: 'dbt_project=course_project;env=prod;team=analytics'
```

```sql
-- Or set dynamically in models
{{ config(query_tag='model=dim_customers;layer=mart') }}
```

### 5. Cost Tracking Queries

```sql
-- ============================================
-- Track dbt costs by project (using query tags)
-- ============================================
SELECT
    DATE(start_time) AS query_date,
    TRY_PARSE_JSON(query_tag):dbt_project::STRING AS dbt_project,
    TRY_PARSE_JSON(query_tag):env::STRING AS environment,
    COUNT(*) AS query_count,
    SUM(total_elapsed_time) / 1000 AS total_seconds,
    SUM(credits_used_cloud_services) AS cloud_credits,
    -- Estimated cost (adjust rate for your contract)
    ROUND(SUM(credits_used_cloud_services) * 2.5, 2) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_tag LIKE '%dbt_project=%'
    AND start_time >= DATEADD('month', -1, CURRENT_TIMESTAMP())
GROUP BY 1, 2, 3
ORDER BY 1 DESC, estimated_cost_usd DESC;

-- ============================================
-- Warehouse credit usage for dbt
-- ============================================
SELECT
    DATE(start_time) AS usage_date,
    warehouse_name,
    SUM(credits_used) AS compute_credits,
    SUM(credits_used_cloud_services) AS cloud_credits,
    SUM(credits_used + credits_used_cloud_services) AS total_credits,
    ROUND(SUM(credits_used + credits_used_cloud_services) * 2.5, 2) AS estimated_cost_usd
FROM SNOWFLAKE.ACCOUNT_USAGE.WAREHOUSE_METERING_HISTORY
WHERE warehouse_name LIKE 'DBT%'
    AND start_time >= DATEADD('month', -1, CURRENT_TIMESTAMP())
GROUP BY 1, 2
ORDER BY 1 DESC, total_credits DESC;

-- ============================================
-- Most expensive dbt queries
-- ============================================
SELECT
    query_id,
    query_text,
    total_elapsed_time / 1000 AS duration_seconds,
    credits_used_cloud_services AS credits,
    partitions_scanned,
    bytes_scanned / 1e9 AS gb_scanned
FROM SNOWFLAKE.ACCOUNT_USAGE.QUERY_HISTORY
WHERE query_text LIKE '%EXECUTE DBT PROJECT%'
    AND start_time >= DATEADD('week', -1, CURRENT_TIMESTAMP())
ORDER BY credits_used_cloud_services DESC
LIMIT 20;
```

> **📚 REFERENCE: Cost Management**
> - [Resource Monitors](https://docs.snowflake.com/en/user-guide/resource-monitors)
> - [Credit Usage](https://docs.snowflake.com/en/user-guide/credits)
> - [Query Tags](https://docs.snowflake.com/en/sql-reference/parameters#query-tag)

---

## 4.6 Best Practices

### Project Organization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Best Practices Summary                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. NAMING CONVENTIONS                                                      │
│     ─────────────────                                                       │
│     Staging:      stg_<source>__<entity>     stg_salesforce__accounts      │
│     Intermediate: int_<entity>__<transform>  int_orders__aggregated        │
│     Dimensions:   dim_<entity>               dim_customers                  │
│     Facts:        fct_<entity>               fct_orders                     │
│     Aggregates:   agg_<entity>__<grain>      agg_sales__daily              │
│     Snapshots:    snap_<entity>              snap_products                  │
│                                                                             │
│  2. MATERIALIZATION STRATEGY                                                │
│     ───────────────────────                                                 │
│     Layer          Materialization    Why                                   │
│     ─────          ───────────────    ───                                   │
│     Staging        VIEW               No storage cost, always fresh         │
│     Intermediate   TABLE/INCREMENTAL  Balance performance/freshness         │
│     Marts          TABLE              Fast queries for BI tools             │
│     Aggregates     TABLE              Pre-computed for dashboards           │
│                                                                             │
│  3. TESTING REQUIREMENTS                                                    │
│     ────────────────────                                                    │
│     Minimum tests per model:                                                │
│     • Primary key: unique + not_null                                       │
│     • Foreign keys: relationships (at least warn severity)                 │
│     • Business rules: accepted_values for status/category columns          │
│                                                                             │
│  4. DOCUMENTATION STANDARDS                                                 │
│     ───────────────────────                                                 │
│     • Every model MUST have a description                                  │
│     • Document business logic in model description                         │
│     • Document columns with business context, not just technical           │
│     • Keep sources.yml updated when sources change                         │
│     • Use meta: for ownership, PII flags, SLA info                        │
│                                                                             │
│  5. GIT WORKFLOW                                                            │
│     ────────────                                                            │
│     • main/master: Production code only                                    │
│     • develop: Integration branch                                          │
│     • feature/*: Individual features                                       │
│     • Tag releases: v1.0.0, v1.1.0                                        │
│     • Require PR reviews before merge                                      │
│     • Run dbt build in CI before allowing merge                           │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Model Development Checklist

```markdown
Before deploying any model, verify:

[ ] Model has a description in YAML
[ ] Primary key has unique + not_null tests
[ ] Foreign keys have relationship tests
[ ] Status/category columns have accepted_values tests
[ ] Model compiles without errors (dbt compile)
[ ] Model runs successfully (dbt run --select model_name)
[ ] Tests pass (dbt test --select model_name)
[ ] Documentation is updated
[ ] No hardcoded values (use vars or ref)
[ ] Follows naming conventions
```

### Environment Strategy

```sql
-- ============================================
-- Multi-environment setup
-- ============================================

-- Development: Each developer gets own schema
-- Naming: DEV_<USERNAME>_<layer>
CREATE SCHEMA IF NOT EXISTS COURSE_DB.DEV_JSMITH_STAGING;
CREATE SCHEMA IF NOT EXISTS COURSE_DB.DEV_JSMITH_SILVER;
CREATE SCHEMA IF NOT EXISTS COURSE_DB.DEV_JSMITH_GOLD;

-- Staging: Shared testing environment
CREATE SCHEMA IF NOT EXISTS COURSE_DB.STG_STAGING;
CREATE SCHEMA IF NOT EXISTS COURSE_DB.STG_SILVER;
CREATE SCHEMA IF NOT EXISTS COURSE_DB.STG_GOLD;

-- Production: Protected, limited access
CREATE SCHEMA IF NOT EXISTS COURSE_DB.STAGING;
CREATE SCHEMA IF NOT EXISTS COURSE_DB.SILVER;
CREATE SCHEMA IF NOT EXISTS COURSE_DB.GOLD;
```

> **💡 TIP: Environment-Specific generate_schema_name**
> 
> ```sql
> -- macros/generate_schema_name.sql
> {% macro generate_schema_name(custom_schema_name, node) -%}
>     {%- set default_schema = target.schema -%}
>     
>     {%- if target.name == 'prod' -%}
>         {# Production: Use schema name directly #}
>         {{ custom_schema_name | trim if custom_schema_name else default_schema }}
>     {%- else -%}
>         {# Dev/Staging: Prefix with target schema #}
>         {{ default_schema }}_{{ custom_schema_name | trim if custom_schema_name else '' }}
>     {%- endif -%}
> {%- endmacro %}
> ```

---

## 4.7 Troubleshooting Guide

### Common Issues and Solutions

| Issue | Symptoms | Solution |
|-------|----------|----------|
| **Permission denied** | "Insufficient privileges" error | Grant CREATE DBT PROJECT on schema (not database) |
| **Model not found** | "Object does not exist" | Check schema name, case sensitivity, target |
| **Test failures** | Tests fail after deployment | Run `dbt test` locally first, check data quality |
| **Slow execution** | Runs taking too long | Check warehouse size, use incremental models |
| **Package errors** | "Unable to fetch package" | Set up EXTERNAL_ACCESS_INTEGRATIONS |
| **Version mismatch** | Unexpected behavior | Check DBT_VERSION setting on project |

### Debugging Steps

```sql
-- ============================================
-- Step 1: Check project exists and settings
-- ============================================
SHOW DBT PROJECTS LIKE 'COURSE_PROJECT' IN DATABASE COURSE_DB;

DESCRIBE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT;

-- ============================================
-- Step 2: Get logs from failed execution
-- ============================================
-- Find the failed query
SELECT query_id, query_start_time, error_message
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE execution_status = 'FAILED'
ORDER BY query_start_time DESC
LIMIT 1;

-- Get full logs
SELECT SYSTEM$GET_DBT_LOG('<query_id_from_above>');

-- ============================================
-- Step 3: Check compiled SQL
-- ============================================
-- Get artifacts path
SELECT SYSTEM$LOCATE_DBT_ARTIFACTS('<query_id>');

-- View compiled SQL for specific model
-- Navigate to: <artifacts_path>/compiled/course_dbt_project/models/marts/dim_customers.sql

-- ============================================
-- Step 4: Verify source data
-- ============================================
SELECT COUNT(*) FROM COURSE_DB.RAW.CUSTOMERS;
SELECT * FROM COURSE_DB.RAW.CUSTOMERS LIMIT 5;

-- ============================================
-- Step 5: Test model manually
-- ============================================
-- Copy compiled SQL and run it directly in worksheet
```

### Error Message Reference

| Error Message | Cause | Fix |
|---------------|-------|-----|
| `Object 'X' does not exist` | Wrong schema/database in ref() | Check model path and target |
| `Compilation Error` | Jinja syntax error | Use `dbt compile` to debug |
| `Database Error` | SQL syntax or permission | Check compiled SQL manually |
| `Relation already exists` | View exists, trying to create table | Add `--full-refresh` or change config |
| `Unable to connect` | Network/auth issue | Verify connection settings |

> **💡 TIP: Debug Locally First**
> 
> Before deploying to Snowflake:
> ```bash
> # Parse and validate project
> dbt parse
> 
> # Compile all models (generates SQL)
> dbt compile
> 
> # Run with debug output
> dbt run --debug --select my_model
> 
> # Test locally
> dbt test --select my_model
> ```

---

## 4.8 Streamlit Monitoring Dashboard

A complete Streamlit dashboard for monitoring dbt projects is included at `streamlit/dbt_monitor_dashboard.py`.

### Dashboard Features

- Real-time execution history
- Success/failure visualization
- Duration trends over time
- Interactive log viewer
- Project filtering
- Cost estimates

### Dashboard Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    Streamlit dbt Monitor Dashboard                          │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  HEADER                                                             │  │
│   │  dbt Projects Monitor           [Refresh] [Settings]                │  │
│   │  Connection: ● Connected | Database: COURSE_DB | Last: 10:30 AM    │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌────────────┐  ┌────────────┐  ┌────────────┐  ┌────────────┐          │
│   │ Total Runs │  │ Successful │  │   Failed   │  │ Success %  │          │
│   │    156     │  │    148     │  │     8      │  │   94.9%    │          │
│   │   ↑ 12%    │  │   ↑ 15%    │  │   ↓ 20%   │  │   ↑ 2.1%   │          │
│   └────────────┘  └────────────┘  └────────────┘  └────────────┘          │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  CHART: Daily Execution Trend                                       │  │
│   │                                                                     │  │
│   │  Runs │    ██                                                       │  │
│   │   30  │    ██ ██       ██                                          │  │
│   │   20  │ ██ ██ ██ ██ ██ ██ ██                                       │  │
│   │   10  │ ██ ██ ██ ██ ██ ██ ██                                       │  │
│   │       └─────────────────────                                        │  │
│   │         M  T  W  T  F  S  S                                        │  │
│   │                                                                     │  │
│   │  Legend: ██ Success  ██ Failed                                     │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  TABLE: Recent Executions                                           │  │
│   │  Filter: [All Projects ▼] [All Status ▼] [Last 7 days ▼]          │  │
│   │                                                                     │  │
│   │  Project       Command   Status    Duration   Timestamp             │  │
│   │  ───────────   ───────   ──────    ────────   ─────────────────    │  │
│   │  course_proj   build     ✓ Pass    42s        2024-03-05 10:15     │  │
│   │  course_proj   test      ✓ Pass    15s        2024-03-05 10:16     │  │
│   │  sales_proj    run       ✗ Fail    28s        2024-03-05 09:00     │  │
│   │                                                                     │  │
│   │  [View Logs] [View Query Profile] [Download Artifacts]             │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
│   ┌─────────────────────────────────────────────────────────────────────┐  │
│   │  LOG VIEWER (click row above to load)                               │  │
│   │  ─────────────────────────────────────────────────────────────────  │  │
│   │  15:14:53 [info] Running with dbt=1.10.15                          │  │
│   │  15:14:53 [info] Found 8 models, 12 tests, 2 seeds                 │  │
│   │  15:14:55 [info] Running model staging.stg_customers               │  │
│   │  15:14:56 [info] OK created view STAGING.STG_CUSTOMERS             │  │
│   │  ...                                                                │  │
│   └─────────────────────────────────────────────────────────────────────┘  │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Running the Dashboard

```bash
# Navigate to streamlit directory
cd streamlit

# Install requirements
pip install -r requirements.txt

# Configure connection (create from template)
cp secrets.toml.example .streamlit/secrets.toml
# Edit secrets.toml with your connection details

# Run the dashboard
streamlit run dbt_monitor_dashboard.py

# Or deploy to Snowflake (Streamlit in Snowflake)
snow streamlit deploy
```

> **💡 TIP: Deploy to Snowflake for Always-On Monitoring**
> 
> You can deploy this dashboard directly to Snowflake's Streamlit hosting:
> ```bash
> snow streamlit deploy dbt_monitor_dashboard \
>     --database COURSE_DB \
>     --schema DBT_PROJECTS
> ```
> 
> Benefits:
> - No external hosting needed
> - Uses Snowflake authentication
> - Always available
> - No egress charges

---

## 4.9 Alerting and Notifications

### Create Alert Table

```sql
-- ============================================
-- Create alert logging table
-- ============================================
CREATE TABLE IF NOT EXISTS COURSE_DB.DBT_PROJECTS.DBT_ALERTS (
    alert_id INTEGER AUTOINCREMENT,
    alert_time TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    alert_type VARCHAR(50),
    severity VARCHAR(20),
    project_name VARCHAR(200),
    query_id VARCHAR(100),
    message TEXT,
    acknowledged BOOLEAN DEFAULT FALSE,
    acknowledged_by VARCHAR(100),
    acknowledged_at TIMESTAMP_NTZ
);
```

### Alert Task for Failures

```sql
-- ============================================
-- Create task to check for failures
-- ============================================
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.CHECK_DBT_FAILURES
    WAREHOUSE = DBT_WH
    SCHEDULE = '30 MINUTES'
    COMMENT = 'Check for dbt failures and log alerts'
AS
DECLARE
    failed_count INTEGER;
BEGIN
    -- Count failures in last 30 minutes
    SELECT COUNT(*) INTO :failed_count
    FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
    WHERE execution_status = 'FAILED'
        AND query_start_time >= DATEADD('minute', -30, CURRENT_TIMESTAMP());
    
    -- Log alert if failures found
    IF (:failed_count > 0) THEN
        INSERT INTO COURSE_DB.DBT_PROJECTS.DBT_ALERTS (
            alert_type, severity, message
        )
        SELECT 
            'EXECUTION_FAILURE',
            'HIGH',
            object_name || ' failed at ' || query_start_time::VARCHAR || ': ' || COALESCE(error_message, 'Unknown error')
        FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
        WHERE execution_status = 'FAILED'
            AND query_start_time >= DATEADD('minute', -30, CURRENT_TIMESTAMP());
    END IF;
END;

ALTER TASK COURSE_DB.DBT_PROJECTS.CHECK_DBT_FAILURES RESUME;
```

### Email Notification Integration

```sql
-- ============================================
-- Set up email notification
-- ============================================

-- Create notification integration (requires ACCOUNTADMIN)
CREATE OR REPLACE NOTIFICATION INTEGRATION dbt_email_alerts
    TYPE = EMAIL
    ENABLED = TRUE
    ALLOWED_RECIPIENTS = ('dbt-alerts@company.com', 'data-team@company.com');

-- Create alert procedure with email
CREATE OR REPLACE PROCEDURE COURSE_DB.DBT_PROJECTS.SEND_DBT_ALERT(
    p_subject VARCHAR,
    p_body VARCHAR
)
RETURNS VARCHAR
LANGUAGE SQL
AS
BEGIN
    CALL SYSTEM$SEND_EMAIL(
        'dbt_email_alerts',
        'dbt-alerts@company.com',
        :p_subject,
        :p_body
    );
    RETURN 'Email sent';
END;
```

> **📚 REFERENCE: Alerting**
> - [Email Notifications](https://docs.snowflake.com/en/user-guide/email-stored-procedures)
> - [Notification Integrations](https://docs.snowflake.com/en/sql-reference/sql/create-notification-integration)

---

## Summary

| Topic | Key Takeaway |
|-------|--------------|
| **Enable Monitoring** | Set LOG_LEVEL=INFO, TRACE_LEVEL=ALWAYS, METRIC_LEVEL=ALL on schema |
| **Snowsight UI** | Data Engineering → dbt Projects for visual monitoring |
| **Logs** | `SYSTEM$GET_DBT_LOG(query_id)` for quick debugging |
| **Artifacts** | `SYSTEM$LOCATE_DBT_ARTIFACTS(query_id)` for compiled SQL, manifest |
| **Execution History** | `INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY()` for queries |
| **Cost Control** | Warehouse sizing, incremental models, resource monitors, query tags |
| **Best Practices** | Naming conventions, testing, documentation, Git workflow |
| **Dashboard** | Streamlit app for real-time monitoring and alerting |

---

## Course Complete!

Congratulations on completing the **dbt Projects on Snowflake** course!

### What You Learned

| Section | Key Topics |
|---------|------------|
| **Section 1** | Architecture, setup, configuration, project structure |
| **Section 2** | Workspaces, models (staging→intermediate→marts), sources, tests, macros, all dbt commands |
| **Section 3** | Deployment (CREATE/ALTER/EXECUTE DBT PROJECT), CLI, Tasks scheduling, versioning, CI/CD |
| **Section 4** | Monitoring (logs, artifacts, history), cost control, best practices, Streamlit dashboard |

### Quick Reference Commands

```sql
-- Deploy from Git
CREATE DBT PROJECT db.schema.project
    FROM '@db.schema.git_repo/branches/main'
    DBT_VERSION = '1.10.15';

-- Execute build
EXECUTE DBT PROJECT db.schema.project ARGS = 'build';

-- Get logs
SELECT SYSTEM$GET_DBT_LOG('<query_id>');

-- Check execution history
SELECT * FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP());
```

```bash
# CLI commands
snow dbt deploy project --source ./dbt_project --database DB --schema SCHEMA
snow dbt execute project build --database DB --schema SCHEMA
snow dbt list --database DB
```

### Next Steps

1. **Build your first production dbt project**
   - Start with staging models from your sources
   - Add tests and documentation
   - Deploy with `snow dbt deploy`

2. **Set up CI/CD pipelines**
   - GitHub Actions or GitLab CI
   - Automated testing on PR
   - Automated deployment on merge

3. **Implement monitoring**
   - Deploy the Streamlit dashboard
   - Set up alerting for failures
   - Track costs by project

4. **Explore advanced features**
   - Incremental models for large tables
   - Snapshots for SCD Type 2
   - Custom packages for reusability

### Resources

| Resource | Link |
|----------|------|
| **Snowflake dbt Docs** | [docs.snowflake.com/dbt-projects](https://docs.snowflake.com/en/user-guide/dbt-projects/overview) |
| **dbt Core Docs** | [docs.getdbt.com](https://docs.getdbt.com/) |
| **Snowflake CLI** | [docs.snowflake.com/snowflake-cli](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/index) |
| **dbt Best Practices** | [docs.getdbt.com/best-practices](https://docs.getdbt.com/best-practices) |
| **dbt Discourse** | [discourse.getdbt.com](https://discourse.getdbt.com/) |
| **dbt Slack** | [getdbt.com/community](https://www.getdbt.com/community/) |
| **Snowflake Community** | [community.snowflake.com](https://community.snowflake.com/) |

---

**Happy transforming!** 

*This course was generated with Cortex Code.*
