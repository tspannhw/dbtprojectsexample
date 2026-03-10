# dbt Projects on Snowflake - Comprehensive Course

A complete **40-minute training course** on building, deploying, and monitoring dbt Projects on Snowflake. Learn to run dbt Core transformations as native Snowflake objects without external infrastructure.

---

## What is dbt Projects on Snowflake?

dbt Projects on Snowflake enables you to deploy and run **dbt Core** transformations as native Snowflake objects. No external servers, no dbt Cloud subscription required - everything runs inside Snowflake using your existing warehouses and security model.

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        dbt Projects on Snowflake                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   ┌─────────────┐    ┌─────────────┐    ┌─────────────┐                    │
│   │   Git Repo  │───►│  Workspace  │───►│ DBT PROJECT │                    │
│   │   (Source)  │    │   (IDE)     │    │  (Object)   │                    │
│   └─────────────┘    └─────────────┘    └──────┬──────┘                    │
│                                                │                            │
│                           ┌────────────────────┼────────────────────┐       │
│                           │                    │                    │       │
│                           ▼                    ▼                    ▼       │
│                    ┌───────────┐        ┌───────────┐        ┌───────────┐ │
│                    │  EXECUTE  │        │ Snowflake │        │ Snowsight │ │
│                    │    DBT    │        │   Tasks   │        │ Monitoring│ │
│                    │  PROJECT  │        │ (Schedule)│        │    UI     │ │
│                    └───────────┘        └───────────┘        └───────────┘ │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Key Benefits

| Traditional dbt | dbt Projects on Snowflake |
|----------------|---------------------------|
| External server required | Runs inside Snowflake |
| Separate credentials | Native Snowflake RBAC |
| Multiple billing sources | Single Snowflake bill |
| Network connectivity needed | No egress required |
| dbt Cloud subscription | No additional subscription |

---

## Course Overview

| Section | Duration | Topics | Document |
|---------|----------|--------|----------|
| **Section 1** | 10 min | Introduction, Architecture, Setup | [01-introduction-setup.md](docs/01-introduction-setup.md) |
| **Section 2** | 10 min | Workspaces, Models, Sources, Tests, Macros | [02-development-models.md](docs/02-development-models.md) |
| **Section 3** | 10 min | Deployment, EXECUTE, Tasks, Versioning | [03-transformation-deployment.md](docs/03-transformation-deployment.md) |
| **Section 4** | 10 min | Monitoring, Cost Control, Best Practices | [04-monitoring-best-practices.md](docs/04-monitoring-best-practices.md) |

### Additional Resources

| Resource | Description |
|----------|-------------|
| [Quick Reference Card](docs/quick-reference-card.md) | One-page cheat sheet with all commands |
| [Troubleshooting Guide](docs/troubleshooting-guide.md) | Solutions to common problems |
| [Course Overview](docs/00-course-overview.md) | Detailed course structure |

---

## What You'll Learn

- **Deploy** dbt Core projects as native Snowflake objects
- **Develop** using Snowflake Workspaces (Git-connected IDE)
- **Master** all dbt Core commands (build, run, test, seed, snapshot, etc.)
- **Schedule** dbt executions with Snowflake Tasks
- **Monitor** executions via Snowsight and programmatic APIs
- **Optimize** costs with incremental models and resource monitors
- **Build** a Streamlit monitoring dashboard

---

## Quick Start (5 minutes)

### Prerequisites

- Snowflake account with appropriate privileges
- [Snowflake CLI](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation) installed (`snow --version`)
- Basic SQL knowledge

### Step 1: Set Up Snowflake Objects

```sql
-- Create database and schemas
CREATE DATABASE IF NOT EXISTS COURSE_DB;
CREATE SCHEMA IF NOT EXISTS COURSE_DB.DBT_PROJECTS;
CREATE SCHEMA IF NOT EXISTS COURSE_DB.RAW;
CREATE SCHEMA IF NOT EXISTS COURSE_DB.STAGING;
CREATE SCHEMA IF NOT EXISTS COURSE_DB.SILVER;
CREATE SCHEMA IF NOT EXISTS COURSE_DB.GOLD;

-- Create warehouse
CREATE WAREHOUSE IF NOT EXISTS DBT_WH 
    WITH WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE;

-- Enable monitoring
ALTER SCHEMA COURSE_DB.DBT_PROJECTS SET LOG_LEVEL = 'INFO';
ALTER SCHEMA COURSE_DB.DBT_PROJECTS SET TRACE_LEVEL = 'ALWAYS';
```

> **Tip**: Run the full setup script at `scripts/01_setup_snowflake_objects.sql` for complete sample data.

### Step 2: Deploy the dbt Project

```bash
# Using Snowflake CLI
snow dbt deploy course_dbt_project \
    --source ./dbt_project \
    --database COURSE_DB \
    --schema DBT_PROJECTS \
    --force
```

Or using SQL:
```sql
-- Upload files to stage first, then:
CREATE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
    FROM '@COURSE_DB.DBT_PROJECTS.DBT_STAGE/course_dbt_project'
    DBT_VERSION = '1.10.15'
    DEFAULT_TARGET = 'prod';
```

### Step 3: Execute the Pipeline

```bash
# Build all models (run + test + seed + snapshot)
snow dbt execute course_dbt_project build \
    --database COURSE_DB \
    --schema DBT_PROJECTS
```

Or using SQL:
```sql
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
    WAREHOUSE = 'DBT_WH'
    ARGS = 'build';
```

### Step 4: Schedule Daily Runs

```sql
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DAILY_DBT_BUILD
    WAREHOUSE = DBT_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_DBT_PROJECT
        ARGS = 'build --target prod';

ALTER TASK COURSE_DB.DBT_PROJECTS.DAILY_DBT_BUILD RESUME;
```

### Step 5: Monitor Execution

```sql
-- View recent executions
SELECT 
    query_id,
    object_name,
    execution_status,
    DATEDIFF('second', query_start_time, query_end_time) AS duration_sec
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
ORDER BY query_start_time DESC
LIMIT 10;

-- Get logs from last run
SELECT SYSTEM$GET_DBT_LOG(
    (SELECT query_id FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
     ORDER BY query_start_time DESC LIMIT 1)
);
```

---

## Project Structure

```
VoyaDBTProjectsCourse/
├── README.md                              # This file
│
├── docs/                                  # Course documentation
│   ├── 00-course-overview.md             # Course introduction
│   ├── 01-introduction-setup.md          # Section 1: Architecture & Setup
│   ├── 02-development-models.md          # Section 2: Models & Development
│   ├── 03-transformation-deployment.md   # Section 3: Deployment & Tasks
│   ├── 04-monitoring-best-practices.md   # Section 4: Monitoring & Optimization
│   ├── quick-reference-card.md           # Command cheat sheet
│   └── troubleshooting-guide.md          # Problem-solving guide
│
├── dbt_project/                           # Complete working dbt project
│   ├── dbt_project.yml                   # Project configuration
│   ├── profiles.yml.example              # Connection template
│   ├── packages.yml                      # Package dependencies
│   ├── models/
│   │   ├── staging/                      # Bronze layer (views)
│   │   │   ├── sources.yml               # Source definitions
│   │   │   ├── stg_customers.sql
│   │   │   ├── stg_orders.sql
│   │   │   ├── stg_products.sql
│   │   │   └── stg_order_items.sql
│   │   ├── intermediate/                 # Silver layer (tables)
│   │   │   ├── int_customer_orders.sql
│   │   │   └── int_order_details.sql
│   │   └── marts/                        # Gold layer (tables)
│   │       ├── dim_customers.sql
│   │       ├── dim_products.sql
│   │       ├── fct_orders.sql
│   │       ├── fct_order_items.sql
│   │       └── agg_monthly_sales.sql
│   ├── macros/                           # Reusable SQL
│   │   ├── generate_surrogate_key.sql
│   │   ├── operations.sql
│   │   └── utility_macros.sql
│   ├── tests/                            # Data quality tests
│   │   ├── test_order_totals_match_items.sql
│   │   ├── test_no_future_order_dates.sql
│   │   └── test_customer_segment_consistency.sql
│   ├── seeds/                            # CSV reference data
│   │   ├── country_codes.csv
│   │   └── order_statuses.csv
│   └── snapshots/                        # SCD Type 2
│       ├── snap_customers.sql
│       └── snap_products.sql
│
├── scripts/                               # SQL & Bash scripts
│   ├── 01_setup_snowflake_objects.sql    # Create DB, schemas, sample data
│   ├── 02_deploy_project.sh              # Automated deployment
│   ├── 03_schedule_tasks.sql             # Task scheduling
│   └── 04_monitoring_queries.sql         # Monitoring queries
│
└── streamlit/                             # Monitoring dashboard
    ├── dbt_monitor_dashboard.py          # Streamlit app
    ├── requirements.txt                  # Python dependencies
    └── secrets.toml.example              # Connection template
```

---

## dbt Commands Reference

### Essential Commands

| Command | Purpose | Example |
|---------|---------|---------|
| `build` | Run + test + seed + snapshot | `ARGS = 'build'` |
| `run` | Execute models | `ARGS = 'run'` |
| `test` | Run data tests | `ARGS = 'test'` |
| `seed` | Load CSV files | `ARGS = 'seed'` |
| `snapshot` | Run SCD Type 2 | `ARGS = 'snapshot'` |
| `compile` | Generate SQL (no execution) | `ARGS = 'compile'` |
| `list` | List project resources | `ARGS = 'list'` |

### Selection Syntax

| Pattern | Meaning | Example |
|---------|---------|---------|
| `model` | Single model | `--select dim_customers` |
| `model+` | Model + downstream | `--select stg_customers+` |
| `+model` | Model + upstream | `--select +fct_orders` |
| `folder.*` | All in folder | `--select staging.*` |
| `tag:name` | By tag | `--select tag:daily` |

### SQL Command Examples

```sql
-- Run all models
EXECUTE DBT PROJECT my_project ARGS = 'run';

-- Run specific folder
EXECUTE DBT PROJECT my_project ARGS = 'run --select staging.*';

-- Run with downstream dependencies
EXECUTE DBT PROJECT my_project ARGS = 'run --select stg_customers+';

-- Full refresh incremental models
EXECUTE DBT PROJECT my_project ARGS = 'run --full-refresh';

-- Test specific models
EXECUTE DBT PROJECT my_project ARGS = 'test --select dim_customers fct_orders';
```

---

## SQL Reference

| Command | Purpose | Example |
|---------|---------|---------|
| `CREATE DBT PROJECT` | Create new project | `CREATE DBT PROJECT name FROM '@stage'` |
| `ALTER DBT PROJECT` | Modify/add versions | `ALTER DBT PROJECT name ADD VERSION v2 FROM '...'` |
| `EXECUTE DBT PROJECT` | Run dbt commands | `EXECUTE DBT PROJECT name ARGS = 'build'` |
| `DROP DBT PROJECT` | Remove project | `DROP DBT PROJECT IF EXISTS name` |
| `SHOW DBT PROJECTS` | List all projects | `SHOW DBT PROJECTS IN DATABASE db` |
| `DESCRIBE DBT PROJECT` | View project details | `DESCRIBE DBT PROJECT name` |

---

## Monitoring

### Quick Monitoring Queries

```sql
-- Recent executions
SELECT * FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY query_start_time DESC;

-- Get execution logs
SELECT SYSTEM$GET_DBT_LOG('<query_id>');

-- Get artifacts (compiled SQL, manifest)
SELECT SYSTEM$LOCATE_DBT_ARTIFACTS('<query_id>');
```

### Enable Monitoring

```sql
ALTER SCHEMA <schema> SET LOG_LEVEL = 'INFO';
ALTER SCHEMA <schema> SET TRACE_LEVEL = 'ALWAYS';
ALTER SCHEMA <schema> SET METRIC_LEVEL = 'ALL';
```

### Streamlit Dashboard

A complete monitoring dashboard is included at `streamlit/dbt_monitor_dashboard.py`:

```bash
cd streamlit
pip install -r requirements.txt
streamlit run dbt_monitor_dashboard.py
```

---

## Supported dbt Versions

| Version | Status |
|---------|--------|
| 1.9.4 | Supported |
| 1.10.15 | Supported (Latest) |

Check supported versions:
```sql
SELECT SYSTEM$SUPPORTED_DBT_VERSIONS();
```

---

## Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| "Insufficient privileges" | Grant `CREATE DBT PROJECT` on **schema** (not database) |
| "Object does not exist" | Check path with `LIST @stage/path/` |
| "Invalid YAML" | Validate locally with `dbt parse` |
| "Unable to fetch packages" | Set up `EXTERNAL_ACCESS_INTEGRATIONS` |

See the full [Troubleshooting Guide](docs/troubleshooting-guide.md) for detailed solutions.

### Quick Debug

```sql
-- 1. Check project exists
SHOW DBT PROJECTS LIKE '%PROJECT_NAME%' IN DATABASE COURSE_DB;

-- 2. Find failed runs
SELECT query_id, error_message
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE execution_status = 'FAILED'
ORDER BY query_start_time DESC LIMIT 1;

-- 3. Get logs
SELECT SYSTEM$GET_DBT_LOG('<query_id_from_above>');
```

---

## Resources

### Official Documentation

| Resource | Link |
|----------|------|
| dbt Projects on Snowflake | [docs.snowflake.com](https://docs.snowflake.com/en/user-guide/dbt-projects/overview) |
| dbt Core Documentation | [docs.getdbt.com](https://docs.getdbt.com/) |
| Snowflake CLI | [docs.snowflake.com/cli](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/index) |
| dbt Best Practices | [docs.getdbt.com/best-practices](https://docs.getdbt.com/best-practices) |

### Community

| Resource | Link |
|----------|------|
| dbt Slack | [getdbt.com/community](https://www.getdbt.com/community/) |
| dbt Discourse | [discourse.getdbt.com](https://discourse.getdbt.com/) |
| Snowflake Community | [community.snowflake.com](https://community.snowflake.com/) |

### Course Reference Links

- [CI/CD Tutorial](https://docs.snowflake.com/en/user-guide/tutorials/dbt-projects-on-snowflake-ci-cd-tutorial)
- [Monitoring & Observability](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake-monitoring-observability)
- [Developer Guide](https://www.snowflake.com/en/developers/guides/dbt-projects-on-snowflake/)

---

## License

This course material is provided for educational purposes.

---

*Built with [Cortex Code](https://docs.snowflake.com/en/user-guide/cortex-code/cortex-code) - Snowflake's AI-powered development assistant*
