# Troubleshooting Guide: dbt Projects on Snowflake

A comprehensive guide to diagnosing and resolving common issues with dbt Projects on Snowflake.

---

## Table of Contents

1. [Deployment Issues](#1-deployment-issues)
2. [Execution Issues](#2-execution-issues)
3. [Permission Issues](#3-permission-issues)
4. [Model Errors](#4-model-errors)
5. [Test Failures](#5-test-failures)
6. [Task/Scheduling Issues](#6-taskscheduling-issues)
7. [Performance Issues](#7-performance-issues)
8. [CLI Issues](#8-cli-issues)
9. [Package/Dependency Issues](#9-packagedependency-issues)
10. [Diagnostic Queries](#10-diagnostic-queries)

---

## 1. Deployment Issues

### Issue: "Object does not exist" when creating project

**Symptoms:**
```
SQL compilation error: Object 'DB.SCHEMA.GIT_REPO' does not exist or not authorized.
```

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Git repository not created | Create the Git repository object first |
| Wrong path in FROM clause | Verify path with `LIST @repo/branches/main/` |
| Case sensitivity | Snowflake uses UPPERCASE by default |
| Missing FETCH | Run `ALTER GIT REPOSITORY repo FETCH` |

**Diagnostic Steps:**
```sql
-- Check if Git repo exists
SHOW GIT REPOSITORIES IN DATABASE course_db;

-- List files in repository
LIST @course_db.integrations.my_git_repo/branches/main/;

-- Verify dbt_project.yml exists
LIST @course_db.integrations.my_git_repo/branches/main/dbt_project.yml;
```

---

### Issue: "Invalid dbt_project.yml"

**Symptoms:**
```
Error: Could not find dbt_project.yml file
Error: Invalid YAML syntax in dbt_project.yml
```

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| File not at root of source | Move dbt_project.yml to root or specify subdirectory path |
| YAML syntax error | Validate YAML locally with `dbt parse` |
| Incorrect indentation | Use spaces, not tabs; check nested structure |
| Missing required fields | Ensure `name` and `version` are present |

**Validation Steps:**
```bash
# Validate locally first
cd dbt_project
dbt parse

# Check YAML syntax
python -c "import yaml; yaml.safe_load(open('dbt_project.yml'))"
```

**Common YAML Mistakes:**
```yaml
# WRONG - tabs instead of spaces
models:
	my_project:    # <-- This is a tab!

# CORRECT - 2 spaces
models:
  my_project:

# WRONG - missing colon
models
  my_project:

# CORRECT
models:
  my_project:
```

---

### Issue: CREATE OR REPLACE fails

**Symptoms:**
```
Cannot replace DBT PROJECT because it is in use
Object already exists
```

**Solution:**
```sql
-- Option 1: Drop and recreate
DROP DBT PROJECT IF EXISTS course_db.dbt_projects.my_project;
CREATE DBT PROJECT course_db.dbt_projects.my_project ...;

-- Option 2: Add new version instead
ALTER DBT PROJECT course_db.dbt_projects.my_project
    ADD VERSION new_version
    FROM '@course_db.integrations.git_repo/branches/main';
```

---

## 2. Execution Issues

### Issue: "EXECUTE DBT PROJECT" hangs or times out

**Symptoms:**
- Query runs for extended period
- Eventually times out
- No output returned

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Warehouse too small | Use larger warehouse for big models |
| Complex model | Break into smaller models |
| Source table scan | Add WHERE clause or use incremental |
| Warehouse suspended | Verify warehouse is running |

**Diagnostic Steps:**
```sql
-- Check warehouse status
SHOW WAREHOUSES LIKE 'DBT%';

-- Check for running queries
SELECT * FROM TABLE(INFORMATION_SCHEMA.QUERY_HISTORY())
WHERE QUERY_TEXT LIKE '%EXECUTE DBT PROJECT%'
    AND QUERY_STATUS = 'RUNNING';

-- Increase timeout for large runs
EXECUTE DBT PROJECT my_project ARGS = 'build'
    QUERY_TAG = 'long_running=true';
```

---

### Issue: Model execution fails with "Object does not exist"

**Symptoms:**
```
Database Error: Object 'COURSE_DB.STAGING.STG_CUSTOMERS' does not exist
Compilation Error: Model 'stg_customers' does not exist
```

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| ref() pointing to non-existent model | Check model name spelling and path |
| Schema doesn't exist | Create schema before running |
| Wrong target | Verify target in profiles matches |
| Model in different project | Use fully qualified name |

**Diagnostic Steps:**
```sql
-- List schemas
SHOW SCHEMAS IN DATABASE COURSE_DB;

-- Check if table exists
SHOW TABLES LIKE '%CUSTOMERS%' IN DATABASE COURSE_DB;

-- Verify compiled SQL path
SELECT SYSTEM$LOCATE_DBT_ARTIFACTS('<query_id>');
```

---

### Issue: "No models to run"

**Symptoms:**
```
Nothing to do. Try checking your model configs and selection criteria.
```

**Causes & Solutions:**

| Cause | Solution |
|-------|----------|
| Wrong --select pattern | Verify model name/path matches |
| Model disabled | Check `enabled: false` in config |
| Empty folder | Ensure models exist in path |
| Case sensitivity | Try exact case as filename |

**Debug:**
```sql
-- List all models in project
EXECUTE DBT PROJECT my_project ARGS = 'list --resource-type model';

-- Check specific selection
EXECUTE DBT PROJECT my_project ARGS = 'list --select staging.*';
```

---

## 3. Permission Issues

### Issue: "Insufficient privileges to operate on schema"

**Symptoms:**
```
Insufficient privileges to operate on schema 'DBT_PROJECTS'
SQL access control error: Insufficient privileges
```

**Required Grants:**
```sql
-- Grant CREATE DBT PROJECT (schema-level, not database!)
GRANT CREATE DBT PROJECT ON SCHEMA course_db.dbt_projects TO ROLE dbt_role;

-- Grant schema usage
GRANT USAGE ON SCHEMA course_db.dbt_projects TO ROLE dbt_role;

-- Grant for model output schemas
GRANT USAGE ON SCHEMA course_db.staging TO ROLE dbt_role;
GRANT CREATE TABLE ON SCHEMA course_db.staging TO ROLE dbt_role;
GRANT CREATE VIEW ON SCHEMA course_db.staging TO ROLE dbt_role;

-- Grant warehouse usage
GRANT USAGE ON WAREHOUSE dbt_wh TO ROLE dbt_role;
GRANT OPERATE ON WAREHOUSE dbt_wh TO ROLE dbt_role;
```

**Common Mistake:**
```sql
-- WRONG: Database-level grant doesn't work
GRANT CREATE DBT PROJECT ON DATABASE course_db TO ROLE dbt_role;

-- CORRECT: Must be schema-level
GRANT CREATE DBT PROJECT ON SCHEMA course_db.dbt_projects TO ROLE dbt_role;
```

---

### Issue: Cannot read source tables

**Symptoms:**
```
SQL access control error: SELECT permission denied on table RAW.CUSTOMERS
```

**Solution:**
```sql
-- Grant SELECT on source schema
GRANT USAGE ON SCHEMA course_db.raw TO ROLE dbt_role;
GRANT SELECT ON ALL TABLES IN SCHEMA course_db.raw TO ROLE dbt_role;
GRANT SELECT ON FUTURE TABLES IN SCHEMA course_db.raw TO ROLE dbt_role;
```

---

### Issue: Cannot create tables in output schema

**Symptoms:**
```
Insufficient privileges to operate on table 'DIM_CUSTOMERS'
Cannot create table in schema 'GOLD'
```

**Solution:**
```sql
-- Grant full permissions on output schemas
GRANT ALL PRIVILEGES ON SCHEMA course_db.staging TO ROLE dbt_role;
GRANT ALL PRIVILEGES ON SCHEMA course_db.silver TO ROLE dbt_role;
GRANT ALL PRIVILEGES ON SCHEMA course_db.gold TO ROLE dbt_role;

-- Or be more specific
GRANT CREATE TABLE, CREATE VIEW ON SCHEMA course_db.gold TO ROLE dbt_role;
```

---

## 4. Model Errors

### Issue: Jinja compilation errors

**Symptoms:**
```
Compilation Error: 'ref' is undefined
Compilation Error: Unexpected end of template
```

**Common Causes:**

| Error | Cause | Fix |
|-------|-------|-----|
| `'ref' is undefined` | Missing `{{}}` | Use `{{ ref('model') }}` |
| `unexpected end` | Unclosed block | Match `{% if %}` with `{% endif %}` |
| `'variable' is undefined` | Typo in var name | Check spelling in `var()` |

**Debug:**
```bash
# Compile locally to see errors
dbt compile --select my_model

# Check compiled SQL
cat target/compiled/my_project/models/marts/dim_customers.sql
```

---

### Issue: SQL syntax errors

**Symptoms:**
```
SQL compilation error: syntax error line X at position Y
unexpected 'FROM'
```

**Common Causes:**

| Error | Cause | Fix |
|-------|-------|-----|
| Trailing comma | Extra comma before FROM | Remove comma |
| Missing comma | Between column definitions | Add comma |
| Reserved word | Using COLUMN, TABLE as alias | Rename or quote |
| Wrong function | Postgres syntax in Snowflake | Use Snowflake syntax |

**Debug - View compiled SQL:**
```sql
-- Get artifacts path
SELECT SYSTEM$LOCATE_DBT_ARTIFACTS('<query_id>');

-- Then browse to compiled/ folder to see actual SQL
```

---

### Issue: "Relation already exists" error

**Symptoms:**
```
Database Error: Cannot create table 'DIM_CUSTOMERS' because a view with that name already exists
```

**Solution:**
```sql
-- Option 1: Full refresh to rebuild
EXECUTE DBT PROJECT my_project ARGS = 'run --select dim_customers --full-refresh';

-- Option 2: Drop existing object manually
DROP VIEW IF EXISTS course_db.gold.dim_customers;

-- Option 3: Change materialization consistently
-- In model config:
{{ config(materialized='table') }}  -- Be consistent
```

---

## 5. Test Failures

### Issue: Tests fail but model ran successfully

**Symptoms:**
```
FAIL unique test on dim_customers.customer_id
FAIL not_null test on fct_orders.order_key
```

**Diagnostic Steps:**
```sql
-- Run tests with store_failures to see bad data
EXECUTE DBT PROJECT my_project 
    ARGS = 'test --select dim_customers --store-failures';

-- Query failed test results
SELECT * FROM course_db.dbt_test__audit.unique_dim_customers_customer_id;

-- Manual check
SELECT customer_id, COUNT(*)
FROM course_db.gold.dim_customers
GROUP BY customer_id
HAVING COUNT(*) > 1;
```

---

### Issue: Relationship test fails

**Symptoms:**
```
FAIL relationships test: some values do not exist in referenced table
```

**Diagnostic:**
```sql
-- Find orphan records
SELECT DISTINCT fct.customer_key
FROM course_db.gold.fct_orders fct
LEFT JOIN course_db.gold.dim_customers dim
    ON fct.customer_key = dim.customer_key
WHERE dim.customer_key IS NULL;
```

---

### Issue: Test takes too long

**Symptoms:**
- Test runs for extended period on large tables

**Solution:**
```yaml
# In schema.yml - limit test scope
- name: customer_id
  tests:
    - unique:
        config:
          where: "created_at >= DATEADD('day', -7, CURRENT_DATE())"
          limit: 1000  # Stop after finding 1000 failures
```

---

## 6. Task/Scheduling Issues

### Issue: Task not running

**Symptoms:**
- Task shows SUSPENDED state
- No executions in history

**Diagnostic & Solution:**
```sql
-- Check task state
SHOW TASKS LIKE 'DBT%' IN SCHEMA course_db.dbt_projects;

-- Resume task
ALTER TASK course_db.dbt_projects.dbt_build RESUME;

-- Check for errors
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'DBT_BUILD',
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -1, CURRENT_TIMESTAMP())
));
```

---

### Issue: Task runs but dbt fails

**Symptoms:**
- Task shows SUCCESS but dbt errors in output

**Debug:**
```sql
-- Get task's query IDs
SELECT 
    query_id,
    query_start_time,
    state
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    TASK_NAME => 'DBT_BUILD',
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -1, CURRENT_TIMESTAMP())
));

-- Check dbt logs for that query
SELECT SYSTEM$GET_DBT_LOG('<query_id>');
```

---

### Issue: Task DAG not running in order

**Symptoms:**
- Child tasks running before parent completes
- Tasks running out of order

**Common Mistakes:**
```sql
-- WRONG: Resuming in wrong order
ALTER TASK parent_task RESUME;
ALTER TASK child_task RESUME;  -- May not see parent yet!

-- CORRECT: Resume children first, then parent
ALTER TASK child_task RESUME;
ALTER TASK parent_task RESUME;
```

---

## 7. Performance Issues

### Issue: dbt build is slow

**Symptoms:**
- Build takes longer than expected
- Individual models timing out

**Solutions:**

| Issue | Solution |
|-------|----------|
| Large tables | Use incremental models |
| Many sequential models | Increase `threads` in profile |
| Complex joins | Pre-aggregate in intermediate layer |
| Table scans | Add clustering keys |
| Small warehouse | Scale up warehouse |

**Diagnostic:**
```sql
-- Find slowest models from logs
SELECT 
    REGEXP_SUBSTR(VALUE, '(stg_|int_|dim_|fct_)[a-z_]+', 1, 1, 'i') AS model,
    REGEXP_SUBSTR(VALUE, 'in ([0-9.]+)s', 1, 1, 'e')::FLOAT AS duration_sec
FROM TABLE(SPLIT_TO_TABLE(SYSTEM$GET_DBT_LOG('<query_id>'), '\n'))
WHERE VALUE LIKE '%OK%'
ORDER BY duration_sec DESC
LIMIT 10;
```

---

### Issue: Warehouse queuing

**Symptoms:**
- Queries waiting in queue
- Slow response times

**Solution:**
```sql
-- Enable multi-cluster
ALTER WAREHOUSE dbt_wh SET
    MIN_CLUSTER_COUNT = 1
    MAX_CLUSTER_COUNT = 3
    SCALING_POLICY = 'ECONOMY';

-- Or use dedicated warehouse for dbt
CREATE WAREHOUSE dbt_dedicated_wh
    WAREHOUSE_SIZE = 'MEDIUM'
    AUTO_SUSPEND = 120;
```

---

## 8. CLI Issues

### Issue: "snow: command not found"

**Solution:**
```bash
# Install Snowflake CLI
pip install snowflake-cli-labs

# Or with pipx (recommended)
pipx install snowflake-cli-labs

# Verify
snow --version
```

---

### Issue: Connection fails

**Symptoms:**
```
Error: Failed to connect to Snowflake
Connection refused
```

**Diagnostic:**
```bash
# Test connection
snow connection test

# List connections
snow connection list

# Check config file
cat ~/.snowflake/config.toml
```

**Common config issues:**
```toml
# WRONG - missing quotes on account
account = xy12345.us-east-1

# CORRECT
account = "xy12345.us-east-1"

# WRONG - wrong key name
username = "my_user"

# CORRECT
user = "my_user"
```

---

### Issue: "snow dbt deploy" fails

**Symptoms:**
```
Error: Unable to deploy dbt project
Error: Source directory not found
```

**Solution:**
```bash
# Verify source directory exists and has dbt_project.yml
ls -la ./dbt_project/
ls ./dbt_project/dbt_project.yml

# Use absolute path
snow dbt deploy my_project \
    --source /full/path/to/dbt_project \
    --database COURSE_DB \
    --schema DBT_PROJECTS
```

---

## 9. Package/Dependency Issues

### Issue: "Unable to download packages"

**Symptoms:**
```
Error: Unable to fetch package from hub.getdbt.com
Network unreachable
```

**Solution - Set up external access:**
```sql
-- Create network rule
CREATE OR REPLACE NETWORK RULE dbt_packages_rule
    MODE = EGRESS
    TYPE = HOST_PORT
    VALUE_LIST = (
        'hub.getdbt.com:443',
        'github.com:443',
        'raw.githubusercontent.com:443'
    );

-- Create integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION dbt_packages_integration
    ALLOWED_NETWORK_RULES = (dbt_packages_rule)
    ENABLED = TRUE;

-- Use in project
CREATE OR REPLACE DBT PROJECT my_project
    FROM '@my_stage'
    EXTERNAL_ACCESS_INTEGRATIONS = (dbt_packages_integration);
```

---

### Issue: Package version conflicts

**Symptoms:**
```
Error: Could not find a version of package that satisfies requirements
Version conflict between packages
```

**Solution:**
```yaml
# packages.yml - pin compatible versions
packages:
  - package: dbt-labs/dbt_utils
    version: ">=1.0.0,<2.0.0"  # Version range

  - package: calogica/dbt_expectations
    version: 0.10.1  # Exact version
```

---

## 10. Diagnostic Queries

### Check Project Status

```sql
-- View all dbt projects
SHOW DBT PROJECTS IN DATABASE COURSE_DB;

-- Describe specific project
DESCRIBE DBT PROJECT COURSE_DB.DBT_PROJECTS.MY_PROJECT;

-- View versions
SHOW VERSIONS IN DBT PROJECT COURSE_DB.DBT_PROJECTS.MY_PROJECT;
```

### Check Execution History

```sql
-- Recent executions
SELECT
    query_id,
    object_name,
    execution_status,
    query_start_time,
    DATEDIFF('second', query_start_time, query_end_time) AS duration_sec,
    error_message
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE query_start_time >= DATEADD('day', -7, CURRENT_TIMESTAMP())
ORDER BY query_start_time DESC;

-- Failed executions with logs
SELECT
    query_id,
    object_name,
    query_start_time,
    error_message,
    SYSTEM$GET_DBT_LOG(query_id) AS logs
FROM TABLE(INFORMATION_SCHEMA.DBT_PROJECT_EXECUTION_HISTORY())
WHERE execution_status = 'FAILED'
    AND query_start_time >= DATEADD('day', -1, CURRENT_TIMESTAMP());
```

### Check Permissions

```sql
-- View grants on schema
SHOW GRANTS ON SCHEMA COURSE_DB.DBT_PROJECTS;

-- View grants to role
SHOW GRANTS TO ROLE DBT_DEVELOPER_ROLE;

-- View grants on warehouse
SHOW GRANTS ON WAREHOUSE DBT_WH;
```

### Check Task Status

```sql
-- View tasks
SHOW TASKS IN SCHEMA COURSE_DB.DBT_PROJECTS;

-- Task history
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP())
))
WHERE NAME LIKE 'DBT%'
ORDER BY SCHEDULED_TIME DESC;
```

### Check Monitoring Settings

```sql
-- Verify monitoring enabled
SHOW PARAMETERS LIKE '%LEVEL%' IN SCHEMA COURSE_DB.DBT_PROJECTS;
```

---

## Quick Diagnostic Checklist

When troubleshooting, check these in order:

1. **Permissions**
   - [ ] CREATE DBT PROJECT on schema?
   - [ ] USAGE on warehouse?
   - [ ] SELECT on source tables?
   - [ ] CREATE TABLE/VIEW on output schemas?

2. **Project Structure**
   - [ ] dbt_project.yml at root?
   - [ ] Valid YAML syntax?
   - [ ] models/ folder exists?

3. **Source Data**
   - [ ] Source tables exist?
   - [ ] Data is populated?
   - [ ] Column names match sources.yml?

4. **Execution**
   - [ ] Warehouse is running?
   - [ ] Correct --select pattern?
   - [ ] Target matches profile?

5. **Monitoring**
   - [ ] LOG_LEVEL set?
   - [ ] Check SYSTEM$GET_DBT_LOG()?
   - [ ] Review compiled SQL?

---

## Getting Help

If you're still stuck:

1. **Check logs**: `SELECT SYSTEM$GET_DBT_LOG('<query_id>')`
2. **Review compiled SQL**: Check artifacts folder
3. **dbt Discourse**: [discourse.getdbt.com](https://discourse.getdbt.com)
4. **Snowflake Community**: [community.snowflake.com](https://community.snowflake.com)
5. **dbt Slack**: [getdbt.com/community](https://www.getdbt.com/community/)

When asking for help, include:
- Error message (full text)
- dbt version
- Snowflake edition
- Relevant SQL/YAML
- Steps to reproduce
