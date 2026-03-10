# Quick Reference Card: dbt Projects on Snowflake

*Print this page for easy reference during development*

---

## SQL Commands

### CREATE DBT PROJECT
```sql
CREATE [ OR REPLACE ] DBT PROJECT <name>
    FROM '<source_location>'
    [ DBT_VERSION = '1.9.4' | '1.10.15' ]
    [ DEFAULT_TARGET = '<target>' ]
    [ EXTERNAL_ACCESS_INTEGRATIONS = (integration_name) ]
    [ COMMENT = 'description' ];

-- Example
CREATE DBT PROJECT course_db.dbt_projects.my_project
    FROM '@course_db.integrations.git_repo/branches/main'
    DBT_VERSION = '1.10.15'
    DEFAULT_TARGET = 'prod';
```

### ALTER DBT PROJECT
```sql
-- Add new version
ALTER DBT PROJECT <name> ADD VERSION <alias> FROM '<source>';

-- Set default version
ALTER DBT PROJECT <name> SET DEFAULT_VERSION = '<version>';

-- Update settings
ALTER DBT PROJECT <name> SET DBT_VERSION = '1.10.15';
ALTER DBT PROJECT <name> SET DEFAULT_TARGET = 'prod';

-- Rename
ALTER DBT PROJECT <name> RENAME TO <new_name>;

-- Drop version
ALTER DBT PROJECT <name> DROP VERSION <version_name>;
```

### EXECUTE DBT PROJECT
```sql
EXECUTE DBT PROJECT <name>
    [ VERSION = '<version>' ]
    [ WAREHOUSE = '<warehouse>' ]
    [ ARGS = '<dbt_command>' ];

-- Examples
EXECUTE DBT PROJECT my_project ARGS = 'build';
EXECUTE DBT PROJECT my_project ARGS = 'run --select staging.*';
EXECUTE DBT PROJECT my_project ARGS = 'test --select dim_customers';
EXECUTE DBT PROJECT my_project VERSION = 'v2' ARGS = 'run';
```

### DROP DBT PROJECT
```sql
DROP DBT PROJECT [ IF EXISTS ] <name>;
```

### SHOW / DESCRIBE
```sql
SHOW DBT PROJECTS IN DATABASE <database>;
SHOW DBT PROJECTS IN SCHEMA <database.schema>;
SHOW VERSIONS IN DBT PROJECT <name>;
DESCRIBE DBT PROJECT <name>;
```

---

## Snowflake CLI Commands

### Deploy
```bash
snow dbt deploy <project_name> \
    --source <local_path> \
    --database <database> \
    --schema <schema> \
    [--force]
```

### Execute
```bash
snow dbt execute <project_name> <command> \
    --database <database> \
    --schema <schema> \
    [--select "<pattern>"] \
    [--target <target>] \
    [--vars '{"key": "value"}']
```

### List
```bash
snow dbt list --database <database> [--schema <schema>]
```

---

## dbt Commands (use in ARGS)

| Command | Purpose | Example |
|---------|---------|---------|
| `build` | Run + test + seed + snapshot | `ARGS = 'build'` |
| `run` | Execute models | `ARGS = 'run'` |
| `test` | Run data tests | `ARGS = 'test'` |
| `seed` | Load CSV files | `ARGS = 'seed'` |
| `snapshot` | Run SCD Type 2 | `ARGS = 'snapshot'` |
| `compile` | Generate SQL only | `ARGS = 'compile'` |
| `list` | List resources | `ARGS = 'list'` |
| `show` | Preview data | `ARGS = 'show --select model --limit 10'` |
| `run-operation` | Execute macro | `ARGS = 'run-operation macro_name'` |

---

## Selection Syntax

| Pattern | Meaning | Example |
|---------|---------|---------|
| `model` | Single model | `--select dim_customers` |
| `model+` | Model + downstream | `--select stg_customers+` |
| `+model` | Model + upstream | `--select +fct_orders` |
| `+model+` | Both directions | `--select +dim_customers+` |
| `n+model` | n levels up | `--select 2+fct_orders` |
| `model+n` | n levels down | `--select stg_customers+2` |
| `folder.*` | All in folder | `--select staging.*` |
| `tag:name` | By tag | `--select tag:daily` |
| `@model` | Model + parents | `--select @fct_orders` |

**Modifiers:**
- `--exclude <pattern>` - Exclude models
- `--full-refresh` - Rebuild incremental models
- `--target <name>` - Use specific target
- `--vars '{"key": "val"}'` - Pass variables

---

## Monitoring Functions

```sql
-- Get execution logs
SELECT SYSTEM$GET_DBT_LOG('<query_id>');

-- Get artifacts path
SELECT SYSTEM$LOCATE_DBT_ARTIFACTS('<query_id>');

-- Get archive URL
SELECT SYSTEM$LOCATE_DBT_ARCHIVE('<query_id>');

-- Execution history
SELECT * FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP());
```

---

## Task Scheduling

### Create Task
```sql
CREATE OR REPLACE TASK <task_name>
    WAREHOUSE = <warehouse>
    SCHEDULE = 'USING CRON <expr> <timezone>'
AS
    EXECUTE DBT PROJECT <project> ARGS = '<command>';

ALTER TASK <task_name> RESUME;
```

### CRON Expression
```
┌───────────── minute (0-59)
│ ┌───────────── hour (0-23)
│ │ ┌───────────── day of month (1-31)
│ │ │ ┌───────────── month (1-12)
│ │ │ │ ┌───────────── day of week (0-6)
│ │ │ │ │
* * * * * timezone

Examples:
0 6 * * * UTC         Daily at 6 AM UTC
0 8 * * 1-5 US/Eastern Weekdays 8 AM ET
*/15 * * * * UTC      Every 15 minutes
0 0 1 * * UTC         First of month midnight
```

### Task DAG
```sql
CREATE TASK child_task
    WAREHOUSE = wh
    AFTER parent_task
AS EXECUTE DBT PROJECT proj ARGS = 'test';

-- Resume order: children first, then parents
ALTER TASK child_task RESUME;
ALTER TASK parent_task RESUME;
```

---

## Required Privileges

```sql
-- Minimum grants for dbt developer
GRANT CREATE DBT PROJECT ON SCHEMA <schema> TO ROLE <role>;
GRANT USAGE ON WAREHOUSE <wh> TO ROLE <role>;
GRANT USAGE ON SCHEMA <source_schema> TO ROLE <role>;
GRANT SELECT ON ALL TABLES IN SCHEMA <source_schema> TO ROLE <role>;
GRANT CREATE TABLE ON SCHEMA <output_schema> TO ROLE <role>;
GRANT CREATE VIEW ON SCHEMA <output_schema> TO ROLE <role>;
```

---

## Enable Monitoring

```sql
ALTER SCHEMA <schema> SET LOG_LEVEL = 'INFO';
ALTER SCHEMA <schema> SET TRACE_LEVEL = 'ALWAYS';
ALTER SCHEMA <schema> SET METRIC_LEVEL = 'ALL';
```

---

## Model Materializations

| Type | Use Case | Storage |
|------|----------|---------|
| `view` | Staging, light transforms | None |
| `table` | Marts, heavy queries | Full |
| `incremental` | Large, append-mostly | Delta |
| `ephemeral` | CTEs, intermediate | None |

---

## Naming Conventions

| Layer | Prefix | Example |
|-------|--------|---------|
| Staging | `stg_` | `stg_customers` |
| Intermediate | `int_` | `int_customer_orders` |
| Dimension | `dim_` | `dim_customers` |
| Fact | `fct_` | `fct_orders` |
| Aggregate | `agg_` | `agg_daily_sales` |
| Snapshot | `snap_` | `snap_products` |

---

## Essential Tests

```yaml
columns:
  - name: id
    tests:
      - unique
      - not_null
  - name: status
    tests:
      - accepted_values:
          values: ['active', 'inactive']
  - name: customer_id
    tests:
      - relationships:
          to: ref('dim_customers')
          field: customer_id
```

---

## Project Structure

```
dbt_project/
├── dbt_project.yml     # Project config (REQUIRED)
├── packages.yml        # Dependencies
├── models/
│   ├── staging/        # Bronze layer
│   │   ├── sources.yml
│   │   └── stg_*.sql
│   ├── intermediate/   # Silver layer
│   │   └── int_*.sql
│   └── marts/          # Gold layer
│       ├── dim_*.sql
│       └── fct_*.sql
├── macros/             # Reusable SQL
├── tests/              # Singular tests
├── seeds/              # CSV files
└── snapshots/          # SCD Type 2
```

---

## Source Locations

| Type | Format |
|------|--------|
| Git repo | `@db.schema.repo/branches/main` |
| Git tag | `@db.schema.repo/tags/v1.0` |
| Stage | `@db.schema.stage/folder` |
| Project | `snow://dbt/db.schema.proj/versions/last` |
| Workspace | `snow://workspace/ns."Name"/versions/live` |

---

## Supported dbt Versions

| Version | Status |
|---------|--------|
| 1.9.4 | Supported |
| 1.10.15 | Supported |

Check: `SELECT SYSTEM$SUPPORTED_DBT_VERSIONS();`

---

## Common Errors & Fixes

| Error | Fix |
|-------|-----|
| "Object does not exist" | Check path, run `LIST @stage/` |
| "Insufficient privileges" | Grant CREATE DBT PROJECT on schema |
| "Invalid YAML" | Validate with `dbt parse` locally |
| "Unable to fetch package" | Set up EXTERNAL_ACCESS_INTEGRATIONS |
| "No models to run" | Check --select pattern and model path |

---

## Quick Debug

```sql
-- 1. Check project exists
SHOW DBT PROJECTS LIKE 'MY_PROJECT' IN DATABASE COURSE_DB;

-- 2. Find failed execution
SELECT query_id, error_message
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE execution_status = 'FAILED'
ORDER BY query_start_time DESC LIMIT 1;

-- 3. Get logs
SELECT SYSTEM$GET_DBT_LOG('<query_id>');

-- 4. Check compiled SQL
SELECT SYSTEM$LOCATE_DBT_ARTIFACTS('<query_id>');
```

---

## Resources

- **Snowflake Docs**: [docs.snowflake.com/dbt-projects](https://docs.snowflake.com/en/user-guide/dbt-projects/overview)
- **dbt Docs**: [docs.getdbt.com](https://docs.getdbt.com)
- **CLI Docs**: [docs.snowflake.com/snowflake-cli](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/index)
- **dbt Slack**: [getdbt.com/community](https://www.getdbt.com/community/)
