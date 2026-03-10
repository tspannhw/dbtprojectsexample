# Section 3: Transformation & Deployment (10 minutes)

## Learning Objectives

By the end of this section, you will:
- Deploy dbt projects to Snowflake using SQL and CLI
- Execute transformations with all available options
- Schedule dbt runs with Snowflake Tasks
- Manage project versions and implement rollback strategies
- Set up CI/CD pipelines for dbt deployments

---

## 3.1 Deployment Methods

There are two primary ways to deploy dbt projects to Snowflake:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        Deployment Methods                                   │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   METHOD 1: SQL Commands                  METHOD 2: Snowflake CLI           │
│   ──────────────────────                  ────────────────────────          │
│                                                                             │
│   CREATE DBT PROJECT                      snow dbt deploy                   │
│   ALTER DBT PROJECT                       snow dbt execute                  │
│   EXECUTE DBT PROJECT                     snow dbt list                     │
│   DROP DBT PROJECT                                                          │
│   SHOW DBT PROJECTS                                                         │
│   DESCRIBE DBT PROJECT                                                      │
│                                                                             │
│   Best for:                               Best for:                         │
│   • Snowsight worksheets                  • CI/CD pipelines                 │
│   • Stored procedures                     • Local development               │
│   • Task scheduling                       • Automation scripts              │
│   • Administrative scripts                • Cross-platform tools            │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Deployment Workflow

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     Typical Deployment Workflow                             │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   1. DEVELOP         2. TEST           3. DEPLOY         4. SCHEDULE       │
│   ─────────         ──────           ────────         ──────────         │
│                                                                             │
│   ┌──────────┐     ┌──────────┐     ┌──────────┐     ┌──────────┐        │
│   │Workspace │────►│ dbt build│────►│ CREATE   │────►│ CREATE   │        │
│   │or Local  │     │ (dev)    │     │ DBT      │     │ TASK     │        │
│   │IDE       │     │          │     │ PROJECT  │     │          │        │
│   └──────────┘     └──────────┘     └──────────┘     └──────────┘        │
│        │                │                │                │               │
│        ▼                ▼                ▼                ▼               │
│   Git commit        Tests pass      Version created   Task resumed        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

> **💡 TIP: Choosing a Deployment Method**
> 
> | Scenario | Recommended Method |
> |----------|-------------------|
> | First-time setup | CLI (`snow dbt deploy`) |
> | CI/CD pipelines | CLI (easier to script) |
> | Scheduled updates | SQL (in stored procedures) |
> | Quick fixes | Workspace (browser-based) |
> | Production releases | SQL (auditable, versioned) |

---

## 3.2 CREATE DBT PROJECT

Creates a new dbt project object from source files.

### Syntax

```sql
CREATE [ OR REPLACE ] DBT PROJECT [ IF NOT EXISTS ] <name>
    [ FROM '<source_location>' ]
    [ COMMENT = '<string>' ]
    [ DBT_VERSION = '<version>' ]
    [ DEFAULT_TARGET = '<target>' ]
    [ EXTERNAL_ACCESS_INTEGRATIONS = ( <integration> [, ...] ) ]
```

### Source Locations

| Source Type | Example Path | Use Case |
|-------------|--------------|----------|
| Git Repository Stage | `@db.schema.git_repo/branches/main/path` | Production deployments |
| Existing DBT PROJECT | `snow://dbt/db.schema.project/versions/last` | Copying/backup |
| Internal Named Stage | `@db.schema.my_stage/dbt_project` | Manual uploads |
| Workspace | `snow://workspace/user$.public."My Workspace"/versions/live` | Development |

> **💡 TIP: Understanding Source Location Syntax**
> 
> ```
> Git repo format:   @database.schema.git_repo_name/branches/<branch>/path/
> Stage format:      @database.schema.stage_name/folder/
> Project format:    snow://dbt/database.schema.project_name/versions/<version>
> Workspace format:  snow://workspace/<namespace>."<workspace_name>"/versions/live
> ```

### Examples

```sql
-- ============================================
-- Example 1: From Git repository (RECOMMENDED for production)
-- ============================================
CREATE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    FROM '@COURSE_DB.INTEGRATIONS.DBT_GIT_REPO/branches/main'
    DBT_VERSION = '1.10.15'
    DEFAULT_TARGET = 'prod'
    COMMENT = 'Production dbt project - deployed from main branch';

-- ============================================
-- Example 2: From internal stage (for manual deployments)
-- ============================================
-- First, upload files to stage
PUT file://./dbt_project/* @COURSE_DB.STAGES.DBT_STAGE/course_project/ AUTO_COMPRESS=FALSE;

-- Then create project
CREATE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    FROM '@COURSE_DB.STAGES.DBT_STAGE/course_project'
    DBT_VERSION = '1.9.4'
    DEFAULT_TARGET = 'prod';

-- ============================================
-- Example 3: From workspace (for development)
-- ============================================
CREATE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    FROM 'snow://workspace/user$.public."My dbt Workspace"/versions/live'
    DEFAULT_TARGET = 'dev';

-- ============================================
-- Example 4: With external access for dbt packages
-- ============================================
CREATE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    FROM '@COURSE_DB.INTEGRATIONS.DBT_GIT_REPO/branches/main'
    DBT_VERSION = '1.10.15'
    EXTERNAL_ACCESS_INTEGRATIONS = (DBT_PACKAGES_ACCESS)
    COMMENT = 'Project with external package dependencies (dbt-utils, etc.)';

-- ============================================
-- Example 5: Copy from existing project version
-- ============================================
CREATE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT_BACKUP
    FROM 'snow://dbt/COURSE_DB.DBT_PROJECTS.COURSE_PROJECT/versions/version$3'
    COMMENT = 'Backup of version 3 before major changes';
```

> **⚠️ WARNING: Common CREATE DBT PROJECT Errors**
> 
> | Error | Cause | Solution |
> |-------|-------|----------|
> | `Object does not exist` | Missing source files | Verify path with `LIST @stage/path/` |
> | `Insufficient privileges` | Missing CREATE DBT PROJECT | Grant on schema, not database |
> | `Invalid dbt_project.yml` | Syntax error in YAML | Validate with `dbt parse` locally |
> | `Network access denied` | packages.yml needs internet | Set up EXTERNAL_ACCESS_INTEGRATIONS |

### Setting Up External Access for dbt Packages

If your project uses packages from packages.yml (dbt-utils, dbt-expectations, etc.), you need external access:

```sql
-- Step 1: Create network rule for dbt packages
CREATE OR REPLACE NETWORK RULE dbt_packages_network_rule
    MODE = EGRESS                              -- Outbound traffic
    TYPE = HOST_PORT
    VALUE_LIST = (
        'hub.getdbt.com:443',                  -- dbt package hub
        'github.com:443',                      -- GitHub
        'raw.githubusercontent.com:443',       -- GitHub raw content
        'codeload.github.com:443'              -- GitHub downloads
    );

-- Step 2: Create external access integration
CREATE OR REPLACE EXTERNAL ACCESS INTEGRATION dbt_packages_access
    ALLOWED_NETWORK_RULES = (dbt_packages_network_rule)
    ENABLED = TRUE
    COMMENT = 'Allow dbt to download packages from hub and GitHub';

-- Step 3: Grant usage to appropriate role
GRANT USAGE ON INTEGRATION dbt_packages_access TO ROLE DBT_DEVELOPER_ROLE;

-- Step 4: Use in CREATE DBT PROJECT
CREATE DBT PROJECT my_project
    FROM '@my_stage/project'
    EXTERNAL_ACCESS_INTEGRATIONS = (dbt_packages_access);
```

> **💡 TIP: Private Package Repositories**
> 
> For private Git repositories hosting dbt packages:
> ```sql
> -- Add your private GitHub/GitLab to the network rule
> CREATE OR REPLACE NETWORK RULE private_packages_rule
>     MODE = EGRESS
>     TYPE = HOST_PORT
>     VALUE_LIST = (
>         'github.com:443',
>         'gitlab.your-company.com:443'  -- Add private hosts
>     );
> ```

> **📚 REFERENCE: CREATE DBT PROJECT**
> - [CREATE DBT PROJECT Documentation](https://docs.snowflake.com/en/sql-reference/sql/create-dbt-project)
> - [External Access Integrations](https://docs.snowflake.com/en/developer-guide/external-network-access/external-network-access-overview)

---

## 3.3 ALTER DBT PROJECT

Modifies existing dbt project objects, including adding new versions.

### Syntax

```sql
-- Rename project
ALTER DBT PROJECT <name> RENAME TO <new_name>;

-- Add new version (most common operation)
ALTER DBT PROJECT <name> ADD VERSION [<alias>] FROM '<source>';

-- Set default version
ALTER DBT PROJECT <name> SET DEFAULT_VERSION = '<version>';

-- Set properties
ALTER DBT PROJECT <name> SET
    [ DBT_VERSION = '<version>' ]
    [ DEFAULT_TARGET = '<target>' ]
    [ EXTERNAL_ACCESS_INTEGRATIONS = ( <integration> ) ]
    [ COMMENT = '<string>' ];

-- Unset properties
ALTER DBT PROJECT <name> UNSET <property>;

-- Drop a specific version
ALTER DBT PROJECT <name> DROP VERSION <version_name>;
```

### Version Management Examples

```sql
-- ============================================
-- Update project from Git (typical workflow)
-- ============================================
-- Step 1: Fetch latest changes from Git
ALTER GIT REPOSITORY COURSE_DB.INTEGRATIONS.DBT_GIT_REPO FETCH;

-- Step 2: Add new version with descriptive alias
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ADD VERSION release_2024_03_15
    FROM '@COURSE_DB.INTEGRATIONS.DBT_GIT_REPO/branches/main';

-- ============================================
-- Create version from specific Git tag
-- ============================================
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ADD VERSION v2_0_0
    FROM '@COURSE_DB.INTEGRATIONS.DBT_GIT_REPO/tags/v2.0.0';

-- ============================================
-- Change default version (for rollback)
-- ============================================
-- See available versions
SHOW VERSIONS IN DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT;

-- Roll back to previous version
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    SET DEFAULT_VERSION = 'version$2';  -- Or use alias like 'release_2024_02_01'

-- ============================================
-- Upgrade dbt version
-- ============================================
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    SET DBT_VERSION = '1.10.15';

-- ============================================
-- Switch default target for all executions
-- ============================================
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    SET DEFAULT_TARGET = 'prod';

-- ============================================
-- Clean up old versions
-- ============================================
-- Drop specific version
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    DROP VERSION version$1;

-- ============================================
-- Rename project (careful with dependencies!)
-- ============================================
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    RENAME TO COURSE_DB.DBT_PROJECTS.COURSE_PROJECT_V2;
```

> **💡 TIP: Version Naming Strategy**
> 
> Use consistent, descriptive version aliases:
> ```sql
> -- Date-based (recommended for regular deployments)
> ADD VERSION release_2024_03_15 FROM '...'
> 
> -- Semantic versioning (recommended for releases)
> ADD VERSION v2_1_0 FROM '...'
> 
> -- Environment + date (for multi-environment)
> ADD VERSION prod_2024_03_15 FROM '...'
> ```

> **⚠️ WARNING: ALTER DBT PROJECT Gotchas**
> 
> - **RENAME breaks references**: Tasks, stored procedures, and scripts referencing the old name will fail
> - **DROP VERSION is permanent**: Cannot be undone
> - **DEFAULT_VERSION affects all executions**: Test first in non-production

> **📚 REFERENCE: ALTER DBT PROJECT**
> - [ALTER DBT PROJECT Documentation](https://docs.snowflake.com/en/sql-reference/sql/alter-dbt-project)

---

## 3.4 EXECUTE DBT PROJECT

Runs dbt commands within the project object. This is the core command for transformations.

### Syntax

```sql
EXECUTE DBT PROJECT [ IF EXISTS ] <name>
    [ VERSION = '<version>' ]
    [ WAREHOUSE = '<warehouse>' ]
    [ ARGS = '<dbt_command> [--options...]' ]
    [ DBT_VERSION = '<version>' ]
```

### Output Columns

| Column | Type | Description |
|--------|------|-------------|
| `0\|1 Success` | BOOLEAN | TRUE if command succeeded |
| `EXCEPTION` | VARCHAR | Error message (if failed) |
| `STDOUT` | VARCHAR | Standard output from dbt |
| `OUTPUT_ARCHIVE_URL` | VARCHAR | URL to artifacts (logs, manifests) |

> **💡 TIP: Capturing EXECUTE Results**
> 
> ```sql
> -- Store results in a table for analysis
> CREATE OR REPLACE TABLE dbt_execution_log AS
> SELECT
>     CURRENT_TIMESTAMP() AS execution_time,
>     'build' AS command,
>     *
> FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
> WHERE 1=0;  -- Create empty table with schema
> 
> -- Then after each execution:
> INSERT INTO dbt_execution_log
> SELECT
>     CURRENT_TIMESTAMP(),
>     'build',
>     *
> FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));
> ```

### Complete Command Examples

```sql
-- ============================================
-- BASIC EXECUTION
-- ============================================

-- Default run (no args = dbt run)
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT;

-- Build all (models + tests + seeds + snapshots)
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'build';

-- Specify warehouse explicitly
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    WAREHOUSE = 'DBT_WH_LARGE'
    ARGS = 'build';

-- ============================================
-- MODEL SELECTION
-- ============================================

-- Run specific models
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --select stg_customers dim_customers fct_orders';

-- Run with downstream dependencies (+)
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --select stg_customers+';

-- Run with upstream dependencies (+model)
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --select +fct_orders';

-- Run entire folder
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --select staging.*';

-- Run by tag
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --select tag:daily';

-- Run by materialization
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --select config.materialized:table';

-- Exclude models
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --exclude staging.* --exclude tag:deprecated';

-- Combine selections (run marts except aggregates)
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --select marts.* --exclude tag:aggregate';

-- ============================================
-- INCREMENTAL MODELS
-- ============================================

-- Full refresh (rebuild from scratch)
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --full-refresh';

-- Full refresh specific model
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --select fct_orders --full-refresh';

-- ============================================
-- TESTING
-- ============================================

-- Test all
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'test';

-- Test specific models
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'test --select dim_customers fct_orders';

-- Test only source freshness
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'source freshness';

-- Test with specific severity
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'test --severity warn';

-- ============================================
-- SEEDS AND SNAPSHOTS
-- ============================================

-- Seed (load CSV files)
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'seed';

-- Seed specific file
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'seed --select country_codes';

-- Seed with full refresh (recreate tables)
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'seed --full-refresh';

-- Snapshot (SCD Type 2)
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'snapshot';

-- Snapshot specific
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'snapshot --select snap_customers';

-- ============================================
-- DEBUGGING AND INSPECTION
-- ============================================

-- Compile (generate SQL without executing)
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'compile';

-- List all resources
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'list';

-- List specific resource types
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'list --resource-type model';

EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'list --resource-type test';

-- Show preview of model output
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'show --select dim_customers --limit 10';

-- ============================================
-- MACROS (RUN-OPERATION)
-- ============================================

-- Run a macro
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run-operation grant_select_on_marts --args "{role_name: ANALYST_ROLE}"';

-- Run cleanup macro
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run-operation cleanup_old_tables --args "{schema_name: staging, days_old: 30}"';

-- ============================================
-- ENVIRONMENT AND VARIABLES
-- ============================================

-- Use specific target
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --target prod';

-- Pass variables
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --vars "{start_date: 2024-01-01, end_date: 2024-12-31}"';

-- Combine target and variables
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'run --target prod --vars "{is_full_refresh: true}"';

-- ============================================
-- VERSION CONTROL
-- ============================================

-- Execute specific version (for testing before making default)
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    VERSION = 'release_2024_03_15'
    ARGS = 'build';

-- Override dbt version at runtime
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ARGS = 'build'
    DBT_VERSION = '1.10.15';
```

> **💡 TIP: Selection Operators Quick Reference**
> 
> | Pattern | Description | Example |
> |---------|-------------|---------|
> | `model` | Single model | `--select dim_customers` |
> | `model+` | Model + downstream | `--select stg_customers+` |
> | `+model` | Model + upstream | `--select +fct_orders` |
> | `+model+` | Both directions | `--select +dim_customers+` |
> | `n+model` | n levels upstream | `--select 2+fct_orders` |
> | `model+n` | n levels downstream | `--select stg_customers+2` |
> | `folder.*` | All in folder | `--select staging.*` |
> | `tag:name` | By tag | `--select tag:daily` |
> | `source:name` | Source models | `--select source:raw+` |
> | `@model` | Model + immediate ancestors | `--select @fct_orders` |

> **⚠️ WARNING: EXECUTE DBT PROJECT Gotchas**
> 
> - **No implicit warehouse**: Always specify WAREHOUSE or set on project
> - **Timeout**: Long builds may timeout; consider breaking into smaller tasks
> - **Concurrent executions**: Multiple executions on same models can cause conflicts
> - **ARGS quoting**: Use single quotes for ARGS, escape internal quotes

> **📚 REFERENCE: EXECUTE DBT PROJECT**
> - [EXECUTE DBT PROJECT Documentation](https://docs.snowflake.com/en/sql-reference/sql/execute-dbt-project)
> - [dbt Node Selection](https://docs.getdbt.com/reference/node-selection/syntax)

---

## 3.5 Snowflake CLI (snow dbt)

The Snowflake CLI provides command-line tools for dbt operations, ideal for CI/CD and local development.

### snow dbt deploy

Deploys dbt project files to Snowflake.

```bash
# ============================================
# BASIC DEPLOYMENT
# ============================================

# Deploy from local directory
snow dbt deploy course_project \
    --source ./dbt_project \
    --database COURSE_DB \
    --schema DBT_PROJECTS

# With explicit connection
snow dbt deploy course_project \
    --connection my_connection \
    --source ./dbt_project \
    --database COURSE_DB \
    --schema DBT_PROJECTS

# Force update (replaces existing project)
snow dbt deploy course_project \
    --source ./dbt_project \
    --database COURSE_DB \
    --schema DBT_PROJECTS \
    --force

# ============================================
# WITH DBT VERSION
# ============================================

snow dbt deploy course_project \
    --source ./dbt_project \
    --database COURSE_DB \
    --schema DBT_PROJECTS \
    --dbt-version 1.10.15

# ============================================
# CI/CD EXAMPLE
# ============================================

# Deploy and build in one pipeline
snow dbt deploy course_project \
    --source ./dbt_project \
    --database COURSE_DB \
    --schema DBT_PROJECTS \
    --force && \
snow dbt execute course_project build \
    --database COURSE_DB \
    --schema DBT_PROJECTS
```

> **💡 TIP: CLI Authentication in CI/CD**
> 
> For CI/CD pipelines, use key-pair authentication:
> ```bash
> # Set environment variables
> export SNOWFLAKE_ACCOUNT="xy12345.us-east-1"
> export SNOWFLAKE_USER="dbt_service_account"
> export SNOWFLAKE_PRIVATE_KEY_PATH="/path/to/key.p8"
> export SNOWFLAKE_ROLE="DBT_EXECUTOR_ROLE"
> 
> # Or use config file with connection name
> snow dbt deploy my_project -c cicd_connection ...
> ```

### snow dbt execute

Executes dbt commands on deployed project.

```bash
# ============================================
# COMMON COMMANDS
# ============================================

# Build all
snow dbt execute course_project build \
    --database COURSE_DB --schema DBT_PROJECTS

# Run specific models
snow dbt execute course_project run \
    --select "staging.*" \
    --database COURSE_DB --schema DBT_PROJECTS

# Run with dependencies
snow dbt execute course_project run \
    --select "stg_customers+" \
    --database COURSE_DB --schema DBT_PROJECTS

# Test
snow dbt execute course_project test \
    --database COURSE_DB --schema DBT_PROJECTS

# Full refresh
snow dbt execute course_project run \
    --full-refresh \
    --database COURSE_DB --schema DBT_PROJECTS

# ============================================
# WITH TARGET AND VARIABLES
# ============================================

snow dbt execute course_project run \
    --target prod \
    --database COURSE_DB --schema DBT_PROJECTS

snow dbt execute course_project run \
    --vars '{"start_date": "2024-01-01"}' \
    --database COURSE_DB --schema DBT_PROJECTS

# ============================================
# SEEDS, SNAPSHOTS, AND OPERATIONS
# ============================================

# Load seeds
snow dbt execute course_project seed \
    --database COURSE_DB --schema DBT_PROJECTS

# Run snapshots
snow dbt execute course_project snapshot \
    --database COURSE_DB --schema DBT_PROJECTS

# Run macro operation
snow dbt execute course_project "run-operation grant_select_on_marts" \
    --args '{"role_name": "ANALYST_ROLE"}' \
    --database COURSE_DB --schema DBT_PROJECTS

# ============================================
# DEBUGGING
# ============================================

# Compile only
snow dbt execute course_project compile \
    --database COURSE_DB --schema DBT_PROJECTS

# List resources
snow dbt execute course_project list \
    --database COURSE_DB --schema DBT_PROJECTS

# Show data preview
snow dbt execute course_project "show --select dim_customers --limit 5" \
    --database COURSE_DB --schema DBT_PROJECTS
```

### snow dbt list

Lists dbt project objects.

```bash
# List all projects in database
snow dbt list --database COURSE_DB

# List with schema filter
snow dbt list --database COURSE_DB --schema DBT_PROJECTS

# JSON output (for parsing in scripts)
snow dbt list --database COURSE_DB --format json

# Example: Get project names for automation
snow dbt list --database COURSE_DB --format json | jq -r '.[].name'
```

> **📚 REFERENCE: Snowflake CLI**
> - [Snowflake CLI dbt Commands](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/dbt-commands)
> - [CLI Installation](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation)

---

## 3.6 DROP and SHOW Commands

### DROP DBT PROJECT

```sql
-- Drop project (fails if not exists)
DROP DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT;

-- Drop if exists (no error if missing)
DROP DBT PROJECT IF EXISTS COURSE_DB.DBT_PROJECTS.COURSE_PROJECT;
```

> **⚠️ WARNING: DROP is Permanent**
> 
> - All versions are deleted
> - Cannot be undone (no Time Travel for DBT PROJECT objects)
> - Tasks referencing the project will fail
> - Consider backing up first:
>   ```sql
>   CREATE DBT PROJECT my_project_backup
>       FROM 'snow://dbt/my_database.my_schema.my_project/versions/last';
>   ```

### SHOW DBT PROJECTS

```sql
-- Show all projects in account
SHOW DBT PROJECTS IN ACCOUNT;

-- Show in specific database
SHOW DBT PROJECTS IN DATABASE COURSE_DB;

-- Show in specific schema
SHOW DBT PROJECTS IN SCHEMA COURSE_DB.DBT_PROJECTS;

-- Filter by name pattern
SHOW DBT PROJECTS LIKE 'COURSE%' IN DATABASE COURSE_DB;

-- Limit results
SHOW DBT PROJECTS LIMIT 10;

-- Use result in query
SHOW DBT PROJECTS IN SCHEMA COURSE_DB.DBT_PROJECTS;
SELECT * FROM TABLE(RESULT_SCAN(LAST_QUERY_ID())) 
WHERE "dbt_version" = '1.10.15';
```

**Output columns:**
| Column | Description |
|--------|-------------|
| `name` | Project name |
| `database_name` | Database |
| `schema_name` | Schema |
| `created_on` | Creation timestamp |
| `updated_on` | Last update timestamp |
| `owner` | Owning role |
| `dbt_version` | dbt Core version |
| `default_target` | Default profile target |
| `external_access_integrations` | Configured integrations |
| `comment` | Project description |

### DESCRIBE DBT PROJECT

```sql
-- Get detailed project information
DESCRIBE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT;

-- Show all versions
SHOW VERSIONS IN DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT;
```

---

## 3.7 Scheduling with Snowflake Tasks

Snowflake Tasks automate dbt executions on a schedule. They integrate natively with dbt Projects.

### Basic Task for dbt

```sql
-- ============================================
-- Simple scheduled task
-- ============================================
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.RUN_DBT_BUILD
    WAREHOUSE = DBT_WH
    SCHEDULE = '360 MINUTES'  -- Every 6 hours
    COMMENT = 'Scheduled dbt build every 6 hours'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
        ARGS = 'build --target prod';

-- IMPORTANT: Tasks are created in SUSPENDED state
-- Enable the task
ALTER TASK COURSE_DB.DBT_PROJECTS.RUN_DBT_BUILD RESUME;
```

### Task with CRON Schedule

```sql
-- ============================================
-- Daily at 6 AM UTC
-- ============================================
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DAILY_DBT_BUILD
    WAREHOUSE = DBT_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
    COMMENT = 'Daily dbt build at 6 AM UTC'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
        ARGS = 'build --target prod';

-- ============================================
-- Weekdays at 8 AM Eastern
-- ============================================
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.WEEKDAY_DBT_BUILD
    WAREHOUSE = DBT_WH
    SCHEDULE = 'USING CRON 0 8 * * 1-5 America/New_York'
    COMMENT = 'Weekday dbt build at 8 AM ET'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
        ARGS = 'build';

-- ============================================
-- Every 15 minutes (high-frequency)
-- ============================================
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.FREQUENT_DBT_RUN
    WAREHOUSE = DBT_WH
    SCHEDULE = 'USING CRON */15 * * * * UTC'
    COMMENT = 'Run staging models every 15 minutes'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
        ARGS = 'run --select staging.*';
```

> **💡 TIP: CRON Expression Reference**
> 
> ```
> ┌───────────── minute (0-59)
> │ ┌───────────── hour (0-23)
> │ │ ┌───────────── day of month (1-31)
> │ │ │ ┌───────────── month (1-12)
> │ │ │ │ ┌───────────── day of week (0-6, Sun-Sat)
> │ │ │ │ │
> * * * * * timezone
> 
> Examples:
> 0 6 * * * UTC          → Daily at 6 AM UTC
> 0 0 1 * * UTC          → First day of month at midnight
> */15 * * * * UTC       → Every 15 minutes
> 0 8 * * 1-5 US/Eastern → Weekdays at 8 AM ET
> 0 */4 * * * UTC        → Every 4 hours
> ```

### Task DAG (Dependencies)

```sql
-- ============================================
-- Parent task: Run models
-- ============================================
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_RUN
    WAREHOUSE = DBT_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
    COMMENT = 'Root task - runs dbt models'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
        ARGS = 'run --target prod';

-- ============================================
-- Child task: Test after run completes
-- ============================================
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_TEST
    WAREHOUSE = DBT_WH
    AFTER COURSE_DB.DBT_PROJECTS.DBT_RUN  -- Runs after parent
    COMMENT = 'Test data quality after run'
AS
    EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
        ARGS = 'test --target prod';

-- ============================================
-- Enable tasks (child first, then parent)
-- ============================================
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_TEST RESUME;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_RUN RESUME;
```

### Complex Task DAG

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          Task DAG for dbt Pipeline                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│                        ┌─────────────────────┐                              │
│                        │   DBT_SEED          │  Load reference data        │
│                        │   (Scheduled: 6AM)  │                              │
│                        └──────────┬──────────┘                              │
│                                   │                                         │
│                                   ▼                                         │
│                        ┌─────────────────────┐                              │
│                        │   DBT_RUN_STAGING   │  Build staging models       │
│                        │   (AFTER: SEED)     │                              │
│                        └──────────┬──────────┘                              │
│                                   │                                         │
│                    ┌──────────────┼──────────────┐                          │
│                    │              │              │                          │
│                    ▼              ▼              ▼                          │
│           ┌────────────┐ ┌────────────┐ ┌────────────┐                     │
│           │DBT_RUN_DIM │ │DBT_RUN_FCT │ │DBT_SNAPSHOT│  (Parallel)         │
│           │(AFTER STG) │ │(AFTER STG) │ │(AFTER STG) │                     │
│           └─────┬──────┘ └──────┬─────┘ └────────────┘                     │
│                 │               │                                           │
│                 └───────┬───────┘                                           │
│                         ▼                                                   │
│                ┌─────────────────────┐                                      │
│                │    DBT_TEST         │  Run all tests                       │
│                │ (AFTER: DIM, FCT)   │                                      │
│                └──────────┬──────────┘                                      │
│                           │                                                 │
│                           ▼                                                 │
│                ┌─────────────────────┐                                      │
│                │  DBT_NOTIFY_SUCCESS │  Send notification                   │
│                │  (AFTER: TEST)      │                                      │
│                └─────────────────────┘                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

```sql
-- ============================================
-- Implement complex DAG
-- ============================================

-- Root task: Load seeds
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_SEED
    WAREHOUSE = DBT_WH
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
    COMMENT = 'Load seed data'
AS EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT 
    ARGS = 'seed --target prod';

-- Staging models (depends on seed)
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_RUN_STAGING
    WAREHOUSE = DBT_WH
    AFTER COURSE_DB.DBT_PROJECTS.DBT_SEED
    COMMENT = 'Build staging models'
AS EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT 
    ARGS = 'run --select staging.* --target prod';

-- Dimension models (depends on staging) - parallel
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_RUN_DIM
    WAREHOUSE = DBT_WH
    AFTER COURSE_DB.DBT_PROJECTS.DBT_RUN_STAGING
    COMMENT = 'Build dimension models'
AS EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT 
    ARGS = 'run --select dim_* --target prod';

-- Fact models (depends on staging) - parallel
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_RUN_FCT
    WAREHOUSE = DBT_WH
    AFTER COURSE_DB.DBT_PROJECTS.DBT_RUN_STAGING
    COMMENT = 'Build fact models'
AS EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT 
    ARGS = 'run --select fct_* --target prod';

-- Snapshots (depends on staging) - parallel
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_SNAPSHOT
    WAREHOUSE = DBT_WH
    AFTER COURSE_DB.DBT_PROJECTS.DBT_RUN_STAGING
    COMMENT = 'Run snapshots'
AS EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT 
    ARGS = 'snapshot --target prod';

-- Tests (depends on dim AND fact completion)
CREATE OR REPLACE TASK COURSE_DB.DBT_PROJECTS.DBT_TEST
    WAREHOUSE = DBT_WH
    AFTER COURSE_DB.DBT_PROJECTS.DBT_RUN_DIM, COURSE_DB.DBT_PROJECTS.DBT_RUN_FCT
    COMMENT = 'Run all tests'
AS EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT 
    ARGS = 'test --target prod';

-- ============================================
-- Resume all tasks (leaves to root)
-- ============================================
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_TEST RESUME;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_SNAPSHOT RESUME;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_RUN_FCT RESUME;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_RUN_DIM RESUME;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_RUN_STAGING RESUME;
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_SEED RESUME;
```

> **💡 TIP: Task Best Practices**
> 
> 1. **Use dedicated warehouse**: Create `DBT_TASK_WH` for scheduled runs
> 2. **Enable auto-suspend**: Minimize costs when not running
> 3. **Monitor failures**: Set up alerts on task failure
> 4. **Stagger schedules**: Avoid resource contention
> 5. **Test DAGs manually**: Use `EXECUTE TASK` before enabling

> **⚠️ WARNING: Task Gotchas**
> 
> - **Resume order**: Resume children before parents for AFTER dependencies
> - **Suspend order**: Suspend parents before children
> - **Overlapping runs**: Tasks don't overlap by default; long runs block next
> - **Task history**: Only kept for 7 days in INFORMATION_SCHEMA

### Manage Tasks

```sql
-- View all tasks
SHOW TASKS IN SCHEMA COURSE_DB.DBT_PROJECTS;

-- View task DAG dependencies
SHOW TASKS IN SCHEMA COURSE_DB.DBT_PROJECTS;
SELECT "name", "schedule", "predecessors", "state" 
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()));

-- Check task history (last 24 hours)
SELECT *
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('hour', -24, CURRENT_TIMESTAMP()),
    TASK_NAME => 'DBT_BUILD'
))
ORDER BY SCHEDULED_TIME DESC;

-- Check all task runs
SELECT 
    NAME,
    STATE,
    SCHEDULED_TIME,
    COMPLETED_TIME,
    ERROR_MESSAGE
FROM TABLE(INFORMATION_SCHEMA.TASK_HISTORY(
    SCHEDULED_TIME_RANGE_START => DATEADD('day', -7, CURRENT_TIMESTAMP())
))
WHERE NAME LIKE 'DBT_%'
ORDER BY SCHEDULED_TIME DESC;

-- Suspend task
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_BUILD SUSPEND;

-- Resume task
ALTER TASK COURSE_DB.DBT_PROJECTS.DBT_BUILD RESUME;

-- Run task immediately (manual trigger)
EXECUTE TASK COURSE_DB.DBT_PROJECTS.DBT_BUILD;

-- Get task run status
SELECT SYSTEM$TASK_RUNTIME_INFO('COURSE_DB.DBT_PROJECTS.DBT_BUILD');
```

> **📚 REFERENCE: Snowflake Tasks**
> - [Task Documentation](https://docs.snowflake.com/en/user-guide/tasks-intro)
> - [Task DAGs](https://docs.snowflake.com/en/user-guide/tasks-intro#label-task-dag)
> - [CRON Scheduling](https://docs.snowflake.com/en/sql-reference/sql/create-task#optional-parameters)

---

## 3.8 Version Management

### Understanding Versions

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        DBT PROJECT Versioning                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Every DBT PROJECT maintains immutable versions:                          │
│                                                                             │
│   snow://dbt/<db>.<schema>.<project>/versions/                             │
│       ├── version$1        (first deployment)                              │
│       ├── version$2        (ALTER ADD VERSION)                             │
│       ├── release_v1_0_0   (alias for version$2)                           │
│       ├── version$3        (ALTER ADD VERSION)                             │
│       ├── release_v1_1_0   (alias for version$3)                           │
│       └── version$4        (current/default)                               │
│                                                                             │
│   Special identifiers:                                                      │
│       • first    → Oldest version (version$1)                              │
│       • last     → Most recent version                                     │
│       • version$N → Specific version number                                │
│       • <alias>  → Custom name (e.g., release_v1_0_0)                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Version Operations

```sql
-- ============================================
-- View all versions
-- ============================================
SHOW VERSIONS IN DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT;

-- ============================================
-- Create new version from Git
-- ============================================
-- Fetch latest
ALTER GIT REPOSITORY COURSE_DB.INTEGRATIONS.DBT_GIT_REPO FETCH;

-- Add with descriptive alias
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ADD VERSION release_2024_03_15
    FROM '@COURSE_DB.INTEGRATIONS.DBT_GIT_REPO/branches/main';

-- ============================================
-- Create version from Git tag (recommended for releases)
-- ============================================
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    ADD VERSION v2_0_0
    FROM '@COURSE_DB.INTEGRATIONS.DBT_GIT_REPO/tags/v2.0.0';

-- ============================================
-- Execute specific version (test before default)
-- ============================================
EXECUTE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    VERSION = 'release_2024_03_15'
    ARGS = 'build';

-- ============================================
-- Set default version (promote to production)
-- ============================================
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    SET DEFAULT_VERSION = 'release_2024_03_15';

-- ============================================
-- Rollback to previous version
-- ============================================
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    SET DEFAULT_VERSION = 'release_2024_03_01';

-- ============================================
-- Create backup of project
-- ============================================
CREATE DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT_BACKUP
    FROM 'snow://dbt/COURSE_DB.DBT_PROJECTS.COURSE_PROJECT/versions/last'
    COMMENT = 'Backup before major upgrade';

-- ============================================
-- Clean up old versions
-- ============================================
ALTER DBT PROJECT COURSE_DB.DBT_PROJECTS.COURSE_PROJECT
    DROP VERSION version$1;
```

> **💡 TIP: Version Management Strategy**
> 
> 1. **Development**: Deploy frequently with auto-generated version names
> 2. **Staging**: Use date-based aliases (`staging_2024_03_15`)
> 3. **Production**: Use semantic versioning aliases (`v2_0_0`)
> 4. **Rollback plan**: Always test new version before setting as default
> 5. **Cleanup policy**: Keep last N versions, delete older ones monthly

> **⚠️ WARNING: Version Storage**
> 
> Each version stores a complete copy of your project files. For large projects:
> - Monitor storage usage
> - Implement retention policy (keep last 10 versions)
> - Archive important versions by copying to backup projects

---

## 3.9 CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/dbt-deploy.yml
name: Deploy dbt Project

on:
  push:
    branches: [main]
    paths:
      - 'dbt_project/**'
  workflow_dispatch:

env:
  PROJECT_NAME: course_project
  DATABASE: COURSE_DB
  SCHEMA: DBT_PROJECTS

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Install Snowflake CLI
        run: pip install snowflake-cli-labs
        
      - name: Deploy dbt Project
        env:
          SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
          SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
          SNOWFLAKE_PRIVATE_KEY: ${{ secrets.SNOWFLAKE_PRIVATE_KEY }}
        run: |
          # Create private key file
          echo "$SNOWFLAKE_PRIVATE_KEY" > /tmp/key.p8
          
          # Deploy
          snow dbt deploy $PROJECT_NAME \
            --source ./dbt_project \
            --database $DATABASE \
            --schema $SCHEMA \
            --force
          
      - name: Run dbt build
        env:
          SNOWFLAKE_ACCOUNT: ${{ secrets.SNOWFLAKE_ACCOUNT }}
          SNOWFLAKE_USER: ${{ secrets.SNOWFLAKE_USER }}
          SNOWFLAKE_PRIVATE_KEY: ${{ secrets.SNOWFLAKE_PRIVATE_KEY }}
        run: |
          snow dbt execute $PROJECT_NAME build \
            --database $DATABASE \
            --schema $SCHEMA
```

### Deployment Script Example

```bash
#!/bin/bash
# deploy_dbt_project.sh
# Complete deployment script with error handling

set -e  # Exit on error

# ============================================
# Configuration
# ============================================
PROJECT_NAME="${DBT_PROJECT_NAME:-course_project}"
DATABASE="${DBT_DATABASE:-COURSE_DB}"
SCHEMA="${DBT_SCHEMA:-DBT_PROJECTS}"
CONNECTION="${SNOWFLAKE_CONNECTION:-default}"
SOURCE_DIR="${DBT_SOURCE_DIR:-./dbt_project}"
TARGET="${DBT_TARGET:-prod}"

# ============================================
# Functions
# ============================================
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >&2
    exit 1
}

# ============================================
# Pre-flight checks
# ============================================
log "======================================"
log "Deploying dbt Project: ${PROJECT_NAME}"
log "======================================"
log "Database: ${DATABASE}"
log "Schema: ${SCHEMA}"
log "Source: ${SOURCE_DIR}"
log "Target: ${TARGET}"
log ""

# Check source directory exists
if [ ! -d "${SOURCE_DIR}" ]; then
    error "Source directory not found: ${SOURCE_DIR}"
fi

# Check dbt_project.yml exists
if [ ! -f "${SOURCE_DIR}/dbt_project.yml" ]; then
    error "dbt_project.yml not found in ${SOURCE_DIR}"
fi

# Test connection
log "[1/5] Testing Snowflake connection..."
if ! snow connection test -c ${CONNECTION} > /dev/null 2>&1; then
    error "Failed to connect to Snowflake"
fi
log "Connection successful"

# ============================================
# Deploy
# ============================================
log ""
log "[2/5] Deploying dbt project..."
snow dbt deploy ${PROJECT_NAME} \
    -c ${CONNECTION} \
    --source ${SOURCE_DIR} \
    --database ${DATABASE} \
    --schema ${SCHEMA} \
    --force || error "Deployment failed"

# ============================================
# Load seeds
# ============================================
log ""
log "[3/5] Loading seed data..."
snow dbt execute ${PROJECT_NAME} seed \
    -c ${CONNECTION} \
    --database ${DATABASE} \
    --schema ${SCHEMA} || error "Seed loading failed"

# ============================================
# Build models
# ============================================
log ""
log "[4/5] Building all models..."
snow dbt execute ${PROJECT_NAME} build \
    -c ${CONNECTION} \
    --database ${DATABASE} \
    --schema ${SCHEMA} \
    --target ${TARGET} || error "Build failed"

# ============================================
# Verify
# ============================================
log ""
log "[5/5] Verification..."
snow sql -c ${CONNECTION} -q "
SELECT 
    'Project' as check_type,
    COUNT(*) as count
FROM TABLE(RESULT_SCAN(LAST_QUERY_ID()))
UNION ALL
SELECT 
    'Models',
    COUNT(*)
FROM ${DATABASE}.INFORMATION_SCHEMA.TABLES
WHERE TABLE_SCHEMA IN ('STAGING', 'SILVER', 'GOLD');
" || log "Warning: Verification query failed (non-fatal)"

log ""
log "======================================"
log "Deployment Complete!"
log "======================================"
log "Project: ${DATABASE}.${SCHEMA}.${PROJECT_NAME}"
log "Time: $(date)"
```

> **📚 REFERENCE: CI/CD**
> - [GitHub Actions with Snowflake](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/github-actions)
> - [Key-pair Authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth)

---

## Summary

| Topic | Key Command/Concept |
|-------|---------------------|
| **Create Project** | `CREATE DBT PROJECT name FROM 'source'` |
| **Alter Project** | `ALTER DBT PROJECT name SET/ADD VERSION` |
| **Execute Project** | `EXECUTE DBT PROJECT name ARGS='command'` |
| **Drop Project** | `DROP DBT PROJECT name` |
| **CLI Deploy** | `snow dbt deploy project --source ./dir` |
| **CLI Execute** | `snow dbt execute project build` |
| **Schedule** | Snowflake Tasks with CRON or intervals |
| **Versions** | Automatic versioning, aliases, rollback |
| **External Access** | Required for packages.yml dependencies |

### Quick Command Reference

```sql
-- Deploy from Git
CREATE DBT PROJECT db.schema.project
    FROM '@db.schema.git_repo/branches/main'
    DBT_VERSION = '1.10.15';

-- Add new version
ALTER DBT PROJECT db.schema.project
    ADD VERSION v2_0 FROM '@db.schema.git_repo/tags/v2.0';

-- Execute build
EXECUTE DBT PROJECT db.schema.project ARGS = 'build';

-- Schedule daily
CREATE TASK daily_dbt
    WAREHOUSE = wh
    SCHEDULE = 'USING CRON 0 6 * * * UTC'
AS EXECUTE DBT PROJECT db.schema.project ARGS = 'build';

ALTER TASK daily_dbt RESUME;
```

---

## Next Section

In [Section 4: Monitoring & Best Practices](04-monitoring-best-practices.md), you'll learn:
- Enable and configure monitoring (LOG_LEVEL, TRACE_LEVEL, METRIC_LEVEL)
- Access logs and artifacts with system functions
- Cost control and optimization strategies
- Build a Streamlit monitoring dashboard
- Production best practices and troubleshooting
