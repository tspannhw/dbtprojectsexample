# Section 1: Introduction & Setup (10 minutes)

## Learning Objectives

By the end of this section, you will:
- Understand what dbt Projects on Snowflake is and its benefits
- Know the key architecture components
- Have your environment configured
- Understand dbt project structure and configuration files

---

## 1.1 What is dbt Projects on Snowflake?

dbt (Data Build Tool) Projects on Snowflake enables you to deploy and run dbt Core transformations as **native Snowflake objects**. This means:

- **No external infrastructure** - dbt runs inside Snowflake
- **Native integration** - Uses Snowflake compute, storage, and security
- **Simplified operations** - No dbt Cloud subscription needed
- **Version control** - Built-in versioning for dbt project objects

> **💡 TIP: When to Use dbt Projects on Snowflake**
> 
> This is ideal when you:
> - Want to consolidate your analytics stack within Snowflake
> - Need to reduce external dependencies and network latency
> - Require Snowflake's enterprise security features (RBAC, data sharing)
> - Want simplified billing through a single vendor

> **⚠️ IMPORTANT: dbt Core vs dbt Cloud**
> 
> dbt Projects on Snowflake runs **dbt Core** (open source), not dbt Cloud. You won't have access to dbt Cloud features like the semantic layer UI, IDE, or dbt Explorer. However, you get native Snowflake integration and can use Snowsight for monitoring.

### Traditional dbt vs dbt Projects on Snowflake

```
┌─────────────────────────────────────┐    ┌─────────────────────────────────────┐
│     Traditional dbt Deployment      │    │    dbt Projects on Snowflake        │
├─────────────────────────────────────┤    ├─────────────────────────────────────┤
│                                     │    │                                     │
│  ┌─────────┐     ┌─────────────┐   │    │  ┌─────────────────────────────────┐│
│  │ dbt CLI │────►│   dbt Cloud │   │    │  │         SNOWFLAKE               ││
│  └─────────┘     │  (External) │   │    │  │  ┌─────────────────────────┐   ││
│       │          └──────┬──────┘   │    │  │  │    DBT PROJECT Object   │   ││
│       │                 │          │    │  │  │  ┌─────────────────┐    │   ││
│       ▼                 ▼          │    │  │  │  │   dbt Core      │    │   ││
│  ┌──────────────────────────┐     │    │  │  │  │   (Built-in)    │    │   ││
│  │       SNOWFLAKE          │     │    │  │  │  └─────────────────┘    │   ││
│  │    (Data Warehouse)      │     │    │  │  └─────────────────────────┘   ││
│  └──────────────────────────┘     │    │  └─────────────────────────────────┘│
│                                     │    │                                     │
│  • External compute required        │    │  • All-in-one solution             │
│  • Network connectivity needed      │    │  • Native Snowflake security       │
│  • Separate billing                 │    │  • Single billing                  │
│  • Credentials management           │    │  • No credential exposure          │
└─────────────────────────────────────┘    └─────────────────────────────────────┘
```

### Comparison Table

| Feature | Traditional dbt | dbt Cloud | dbt Projects on Snowflake |
|---------|----------------|-----------|---------------------------|
| **Compute** | External server | dbt Cloud infra | Snowflake warehouse |
| **Scheduling** | Airflow/cron/etc | dbt Cloud | Snowflake Tasks |
| **Security** | Credentials file | OAuth/API keys | Snowflake RBAC |
| **Monitoring** | Custom logging | dbt Cloud UI | Snowsight + Event Tables |
| **Cost** | Infrastructure + Snowflake | Subscription + Snowflake | Snowflake only |
| **Version** | Any dbt version | Latest supported | 1.9.4 or 1.10.15 |

> **📚 REFERENCE: Official Documentation**
> - [dbt Projects on Snowflake Overview](https://docs.snowflake.com/en/user-guide/dbt-projects/overview)
> - [dbt Core Documentation](https://docs.getdbt.com/docs/introduction)
> - [Snowflake dbt Adapter](https://docs.getdbt.com/docs/core/connect-data-platform/snowflake-setup)

---

## 1.2 Architecture Overview

### Key Components

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                        dbt Projects on Snowflake Architecture                   │
├─────────────────────────────────────────────────────────────────────────────────┤
│                                                                                 │
│  ┌─────────────────┐                                                           │
│  │  SOURCE FILES   │  Git Repository, Workspace, or Internal Stage             │
│  │  ├─ models/     │                                                           │
│  │  ├─ macros/     │                                                           │
│  │  ├─ tests/      │                                                           │
│  │  └─ dbt_project.yml                                                         │
│  └────────┬────────┘                                                           │
│           │                                                                     │
│           │ CREATE DBT PROJECT / snow dbt deploy                               │
│           ▼                                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐           │
│  │                    DBT PROJECT OBJECT                           │           │
│  │  • Schema-level object (DATABASE.SCHEMA.PROJECT_NAME)          │           │
│  │  • Versioned (version$1, version$2, ...)                       │           │
│  │  • Contains all dbt assets                                      │           │
│  │  • Immutable versions (append-only)                            │           │
│  └────────┬────────────────────────────────────────────────────────┘           │
│           │                                                                     │
│           │ EXECUTE DBT PROJECT / snow dbt execute                             │
│           ▼                                                                     │
│  ┌─────────────────────────────────────────────────────────────────┐           │
│  │                    EXECUTION ENGINE                             │           │
│  │  • dbt Core (1.9.4 or 1.10.15)                                 │           │
│  │  • Snowflake Warehouse compute                                  │           │
│  │  • Commands: build, run, test, compile, etc.                   │           │
│  │  • Automatic dependency resolution                              │           │
│  └────────┬────────────────────────────────────────────────────────┘           │
│           │                                                                     │
│           │ Output                                                             │
│           ▼                                                                     │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
│  │ Transformed     │  │ Logs &          │  │ Snowsight       │                │
│  │ Tables/Views    │  │ Artifacts       │  │ Monitoring      │                │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘
```

### DBT PROJECT Object

A DBT PROJECT is a **schema-level object** that contains:
- Versioned source files for your dbt project
- Configuration (dbt version, default target, external integrations)
- Metadata (creation date, owner, comments)

```sql
-- Example: View dbt project objects in your account
SHOW DBT PROJECTS IN DATABASE my_database;

-- View specific project details
DESCRIBE DBT PROJECT my_database.my_schema.my_project;

-- View versions
SHOW VERSIONS IN DBT PROJECT my_database.my_schema.my_project;
```

> **💡 TIP: Version Management**
> 
> Each `snow dbt deploy` creates a new immutable version. Versions are named `version$1`, `version$2`, etc. You can:
> - Execute a specific version: `EXECUTE DBT PROJECT ... VERSION = 'version$2'`
> - Set a default version: `ALTER DBT PROJECT ... SET DEFAULT_VERSION = 'version$3'`
> - Roll back by pointing to an older version

> **⚠️ WARNING: Storage Considerations**
> 
> Each version stores a complete copy of your project. For large projects with many versions, consider:
> - Periodically dropping old versions
> - Using meaningful version comments for tracking
> - Implementing a retention policy

### Supported dbt Versions

| Version | Status | Features |
|---------|--------|----------|
| 1.9.4 | Supported | Stable, widely tested |
| 1.10.15 | Supported | Latest features, unit tests |

> **📚 REFERENCE: Version Compatibility**
> - [dbt Version Support Matrix](https://docs.snowflake.com/en/user-guide/dbt-projects/deploy#dbt-version)
> - Check current support: `SELECT SYSTEM$SUPPORTED_DBT_VERSIONS();`

---

## 1.3 Prerequisites & Environment Setup

### Checklist Before Starting

- [ ] Snowflake account with appropriate edition (Enterprise recommended)
- [ ] User with ACCOUNTADMIN or delegated privileges
- [ ] Snowflake CLI installed (v2.0+)
- [ ] Git installed (optional, for Workspaces)
- [ ] Basic understanding of SQL and data modeling

### Required Privileges

```sql
-- Create a role for dbt operations
CREATE ROLE IF NOT EXISTS DBT_DEVELOPER_ROLE;

-- Grant necessary privileges
GRANT CREATE DATABASE ON ACCOUNT TO ROLE DBT_DEVELOPER_ROLE;
GRANT CREATE WAREHOUSE ON ACCOUNT TO ROLE DBT_DEVELOPER_ROLE;

-- Or use existing database/warehouse
GRANT USAGE ON DATABASE course_db TO ROLE DBT_DEVELOPER_ROLE;
GRANT CREATE SCHEMA ON DATABASE course_db TO ROLE DBT_DEVELOPER_ROLE;
GRANT CREATE DBT PROJECT ON SCHEMA course_db.dbt_projects TO ROLE DBT_DEVELOPER_ROLE;
GRANT USAGE ON WAREHOUSE dbt_wh TO ROLE DBT_DEVELOPER_ROLE;

-- Grant role to user
GRANT ROLE DBT_DEVELOPER_ROLE TO USER my_user;
```

> **💡 TIP: Principle of Least Privilege**
> 
> In production environments, create separate roles:
> - `DBT_DEVELOPER_ROLE` - Can deploy and test (dev/staging)
> - `DBT_EXECUTOR_ROLE` - Can only execute (production)
> - `DBT_ADMIN_ROLE` - Full management including DROP

> **⚠️ WARNING: CREATE DBT PROJECT Privilege**
> 
> The `CREATE DBT PROJECT` privilege must be granted at the **schema level**, not database level. This is a common source of permission errors:
> ```sql
> -- WRONG: This won't work
> GRANT CREATE DBT PROJECT ON DATABASE course_db TO ROLE my_role;
> 
> -- CORRECT: Grant on specific schema
> GRANT CREATE DBT PROJECT ON SCHEMA course_db.dbt_projects TO ROLE my_role;
> ```

### Complete Privilege Reference

| Privilege | Level | Purpose |
|-----------|-------|---------|
| `CREATE DBT PROJECT` | Schema | Deploy new projects |
| `USAGE` | Database, Schema | Access objects |
| `USAGE` | Warehouse | Execute dbt commands |
| `CREATE TABLE` | Schema | Create model outputs |
| `CREATE VIEW` | Schema | Create view models |
| `SELECT` | Table | Read source data |
| `OPERATE` | Task | Schedule executions |

### Install Snowflake CLI

```bash
# Install using pip
pip install snowflake-cli-labs

# Or using pipx (recommended - isolated environment)
pipx install snowflake-cli-labs

# Or using Homebrew (macOS)
brew install snowflake-cli

# Verify installation
snow --version

# Expected output: Snowflake CLI version: 2.x.x
```

> **💡 TIP: Use pipx for CLI Installation**
> 
> `pipx` installs the CLI in an isolated environment, preventing dependency conflicts with other Python packages. This is especially important if you also use dbt Core locally.

> **⚠️ WARNING: Version Requirements**
> 
> dbt Projects on Snowflake requires Snowflake CLI version 2.0 or later. Earlier versions use different command syntax (`snowsql` vs `snow`).

### Snowflake CLI Configuration

Create `~/.snowflake/config.toml`:

```toml
# Default connection
[connections.default]
account = "your_account"          # e.g., "xy12345.us-east-1"
user = "your_user"
password = "your_password"        # Or use authenticator
warehouse = "DBT_WH"
database = "COURSE_DB"
schema = "DBT_PROJECTS"
role = "DBT_DEVELOPER_ROLE"

# Development connection
[connections.dev]
account = "your_account"
user = "your_user"
authenticator = "externalbrowser"  # SSO authentication
warehouse = "DEV_WH"
database = "DEV_DB"
schema = "DBT_PROJECTS"
role = "DBT_DEVELOPER_ROLE"

# Production connection (restricted)
[connections.prod]
account = "your_account"
user = "dbt_service_user"
private_key_path = "~/.ssh/snowflake_key.p8"
warehouse = "PROD_WH"
database = "PROD_DB"
schema = "DBT_PROJECTS"
role = "DBT_EXECUTOR_ROLE"
```

> **💡 TIP: Authentication Methods**
> 
> For production, avoid storing passwords in config files. Use:
> - **Key-pair authentication**: Most secure for automation
> - **External browser (SSO)**: Best for interactive development
> - **Environment variables**: `SNOWFLAKE_PASSWORD` for CI/CD

> **📚 REFERENCE: CLI Configuration**
> - [Snowflake CLI Configuration](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/connecting/configure-cli)
> - [Key-pair Authentication](https://docs.snowflake.com/en/user-guide/key-pair-auth)

### Verify CLI Connection

```bash
# Test connection
snow connection test

# List available connections
snow connection list

# Set active connection
snow connection set-default dev

# Check current context
snow sql -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE();"
```

---

## 1.4 dbt Project Structure

### Standard Directory Layout

```
my_dbt_project/
├── dbt_project.yml          # Project configuration (REQUIRED)
├── profiles.yml             # Connection profiles (REQUIRED for local dev)
├── packages.yml             # External package dependencies
├── .gitignore               # Git ignore patterns
│
├── models/                  # SQL transformations
│   ├── staging/            # Raw data cleaning (Bronze layer)
│   │   ├── sources.yml     # Source definitions
│   │   ├── _staging.yml    # Model documentation
│   │   ├── stg_customers.sql
│   │   └── stg_orders.sql
│   ├── intermediate/       # Business logic (Silver layer)
│   │   ├── _intermediate.yml
│   │   └── int_order_items.sql
│   └── marts/              # Analytics-ready (Gold layer)
│       ├── _marts.yml
│       ├── dim_customers.sql
│       ├── fct_orders.sql
│       └── agg_monthly_sales.sql
│
├── macros/                  # Reusable SQL functions
│   ├── generate_schema_name.sql
│   ├── generate_surrogate_key.sql
│   └── custom_tests.sql
│
├── tests/                   # Custom data tests (singular tests)
│   ├── test_unique_orders.sql
│   └── test_totals_match.sql
│
├── seeds/                   # CSV files to load as tables
│   ├── country_codes.csv
│   └── _seeds.yml
│
├── snapshots/               # SCD Type 2 tracking
│   └── snap_customers.sql
│
├── analyses/                # Ad-hoc analytical queries
│   └── yearly_summary.sql
│
└── target/                  # Compiled SQL (auto-generated)
    └── compiled/
```

### Medallion Architecture Mapping

```
┌─────────────────────────────────────────────────────────────────────┐
│                     MEDALLION ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐          │
│  │   BRONZE    │     │   SILVER    │     │    GOLD     │          │
│  │   (Raw)     │────►│ (Cleansed)  │────►│  (Curated)  │          │
│  └─────────────┘     └─────────────┘     └─────────────┘          │
│                                                                     │
│  dbt Mapping:                                                       │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐          │
│  │  sources.yml│     │intermediate/│     │   marts/    │          │
│  │  staging/   │────►│   models    │────►│   models    │          │
│  └─────────────┘     └─────────────┘     └─────────────┘          │
│                                                                     │
│  Materialization:                                                   │
│  ┌─────────────┐     ┌─────────────┐     ┌─────────────┐          │
│  │    VIEW     │     │    TABLE    │     │    TABLE    │          │
│  │  (minimal   │     │  (persist   │     │  (optimized │          │
│  │   storage)  │     │   cleaned)  │     │   for BI)   │          │
│  └─────────────┘     └─────────────┘     └─────────────┘          │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

> **💡 TIP: Naming Conventions**
> 
> Adopt consistent prefixes for clarity:
> - `stg_` for staging models (1:1 with source tables)
> - `int_` for intermediate models (business logic)
> - `dim_` for dimension tables (descriptive attributes)
> - `fct_` for fact tables (measurable events)
> - `agg_` for aggregate/summary tables

> **💡 TIP: Model Organization**
> 
> Keep your models organized by:
> 1. **Layer first**: staging/ → intermediate/ → marts/
> 2. **Domain second** (optional): marts/finance/, marts/marketing/
> 3. **One model per file**: Easier to maintain and review
> 4. **Schema YAML files**: Use `_schema.yml` or `_models.yml` in each folder

### Essential File Types

| File Type | Extension | Purpose | Example |
|-----------|-----------|---------|---------|
| Model | `.sql` | SQL transformation | `stg_customers.sql` |
| Schema | `.yml` | Documentation, tests | `sources.yml` |
| Macro | `.sql` | Reusable SQL logic | `generate_key.sql` |
| Test | `.sql` | Custom data tests | `test_unique.sql` |
| Seed | `.csv` | Static reference data | `country_codes.csv` |
| Snapshot | `.sql` | SCD Type 2 history | `snap_products.sql` |
| Analysis | `.sql` | Ad-hoc queries | `yearly_report.sql` |

> **📚 REFERENCE: dbt Best Practices**
> - [dbt Style Guide](https://docs.getdbt.com/best-practices/how-we-style/0-how-we-style-our-dbt-projects)
> - [Project Structure Guide](https://docs.getdbt.com/guides/best-practices/how-we-structure/1-guide-overview)

---

## 1.5 Configuration Files

### dbt_project.yml

The main configuration file that defines your project:

```yaml
# dbt_project.yml
name: 'course_dbt_project'       # Project name (no spaces, lowercase)
version: '1.0.0'                 # Semantic versioning
config-version: 2                # Always use 2 for modern dbt

# Connection profile name (must match profiles.yml)
profile: 'course_dbt_project'

# Path configurations (defaults shown)
model-paths: ["models"]
analysis-paths: ["analyses"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

# Cleanup targets for 'dbt clean'
clean-targets:
  - "target"
  - "dbt_packages"

# Global variables (accessible in models via var())
vars:
  source_database: "COURSE_DB"
  source_schema: "RAW"
  start_date: "2024-01-01"

# Model configurations by folder
models:
  course_dbt_project:           # Must match 'name' above
    # Staging: 1:1 with sources, minimal transformation
    staging:
      +materialized: view       # Views for minimal storage
      +schema: staging          # Output schema
      +tags: ['staging', 'daily']
    
    # Intermediate: Business logic, joins, aggregations
    intermediate:
      +materialized: table      # Tables for query performance
      +schema: silver
      +tags: ['intermediate']
    
    # Marts: Analytics-ready, optimized for consumers
    marts:
      +materialized: table
      +schema: gold
      +tags: ['marts', 'production']
      +grants:
        select: ['ANALYST_ROLE', 'BI_ROLE']  # Auto-grant access

# Seed configurations
seeds:
  course_dbt_project:
    +schema: reference           # Load to reference schema
    country_codes:
      +column_types:
        country_code: varchar(3)

# Snapshot configurations  
snapshots:
  course_dbt_project:
    +target_schema: snapshots
    +strategy: timestamp
    +updated_at: updated_at

# Test configurations
tests:
  +severity: warn                # 'warn' or 'error'
  +store_failures: true          # Store failed rows in tables
```

> **💡 TIP: Configuration Hierarchy**
> 
> dbt configuration follows this precedence (highest to lowest):
> 1. `config()` block in model file
> 2. Resource-specific YAML properties
> 3. `dbt_project.yml` folder configs
> 4. Default values
> 
> This allows global defaults with selective overrides.

> **⚠️ WARNING: Common Configuration Mistakes**
> 
> - **Model name mismatch**: The key under `models:` must exactly match your `name:`
> - **Indentation**: YAML is whitespace-sensitive; use spaces, not tabs
> - **Schema naming**: `+schema` appends to target schema, not replaces it
>   - Target schema: `DBT_PROJECTS`, +schema: `staging` → `DBT_PROJECTS_STAGING`
>   - Use `generate_schema_name` macro to customize this behavior

### profiles.yml

Connection configuration (for local development):

```yaml
# profiles.yml
# Location: ~/.dbt/profiles.yml (home directory) or project root

course_dbt_project:              # Must match profile: in dbt_project.yml
  target: dev                    # Default target
  outputs:
    # Development environment
    dev:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      password: "{{ env_var('SNOWFLAKE_PASSWORD') }}"  # Or use authenticator
      role: "{{ env_var('SNOWFLAKE_ROLE', 'DBT_DEVELOPER_ROLE') }}"
      warehouse: "{{ env_var('SNOWFLAKE_WAREHOUSE', 'DBT_WH') }}"
      database: COURSE_DB
      schema: DBT_PROJECTS
      threads: 4                 # Parallel model execution
      query_tag: 'dbt_dev'       # Tag queries for monitoring
      
    # Staging environment  
    staging:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      role: DBT_DEVELOPER_ROLE
      warehouse: DBT_WH
      database: STAGING_DB
      schema: DBT_PROJECTS
      threads: 4
      query_tag: 'dbt_staging'

    # Production environment
    prod:
      type: snowflake
      account: "{{ env_var('SNOWFLAKE_ACCOUNT') }}"
      user: "{{ env_var('SNOWFLAKE_USER') }}"
      role: DBT_ADMIN_ROLE
      warehouse: DBT_WH_LARGE    # Larger warehouse for prod
      database: PROD_DB
      schema: DBT_PROJECTS
      threads: 8                 # More parallelism
      query_tag: 'dbt_production'
```

> **💡 TIP: Environment Variables**
> 
> Never hardcode credentials. Use environment variables:
> ```bash
> export SNOWFLAKE_ACCOUNT="xy12345.us-east-1"
> export SNOWFLAKE_USER="my_user"
> export SNOWFLAKE_PASSWORD="my_password"  # Or use key-pair auth
> export SNOWFLAKE_ROLE="DBT_DEVELOPER_ROLE"
> export SNOWFLAKE_WAREHOUSE="DBT_WH"
> ```

> **⚠️ WARNING: profiles.yml Not Needed for Snowflake Execution**
> 
> When using `EXECUTE DBT PROJECT` or `snow dbt execute`, profiles.yml is ignored. The execution uses:
> - Warehouse specified in the SQL command
> - Current session's role and user
> - Target database/schema from dbt_project.yml
>
> profiles.yml is only needed for local `dbt run` commands during development.

### packages.yml

External package dependencies:

```yaml
# packages.yml
packages:
  # dbt Labs maintained packages
  - package: dbt-labs/dbt_utils
    version: 1.1.1
    
  - package: dbt-labs/codegen
    version: 0.12.1
    
  # Audit logging helper
  - package: dbt-labs/audit_helper
    version: 0.10.0
    
  # Testing utilities
  - package: calogica/dbt_expectations
    version: 0.10.1
    
  # Git-based package (private repo example)
  # - git: "https://github.com/your-org/your-package.git"
  #   revision: v1.0.0
```

> **💡 TIP: Useful dbt Packages**
> 
> | Package | Purpose |
> |---------|---------|
> | `dbt_utils` | Common macros (surrogate keys, pivots, etc.) |
> | `codegen` | Generate YAML from database |
> | `audit_helper` | Compare model outputs |
> | `dbt_expectations` | Great Expectations-style tests |
> | `dbt_date` | Date dimension and utilities |

> **📚 REFERENCE: dbt Packages**
> - [dbt Package Hub](https://hub.getdbt.com/)
> - [dbt Utils Documentation](https://github.com/dbt-labs/dbt-utils)

---

## 1.6 Hands-On: Initial Setup

### Step 1: Create Snowflake Objects

```sql
-- =====================================================
-- STEP 1: Create database for the course
-- =====================================================
CREATE DATABASE IF NOT EXISTS COURSE_DB
    COMMENT = 'Database for dbt Projects on Snowflake course';

-- =====================================================
-- STEP 2: Create schemas following medallion architecture
-- =====================================================
-- Project storage schema
CREATE SCHEMA IF NOT EXISTS COURSE_DB.DBT_PROJECTS
    COMMENT = 'dbt project objects and metadata';

-- Raw data layer (Bronze)
CREATE SCHEMA IF NOT EXISTS COURSE_DB.RAW
    COMMENT = 'Raw source data - Bronze layer';

-- Staging layer (cleaned Bronze)
CREATE SCHEMA IF NOT EXISTS COURSE_DB.STAGING
    COMMENT = 'Staging models - cleaned raw data';

-- Intermediate layer (Silver)    
CREATE SCHEMA IF NOT EXISTS COURSE_DB.SILVER
    COMMENT = 'Intermediate models - business logic';

-- Analytics layer (Gold)
CREATE SCHEMA IF NOT EXISTS COURSE_DB.GOLD
    COMMENT = 'Mart models - analytics ready';

-- Snapshot storage
CREATE SCHEMA IF NOT EXISTS COURSE_DB.SNAPSHOTS
    COMMENT = 'SCD Type 2 snapshot tables';

-- Reference data
CREATE SCHEMA IF NOT EXISTS COURSE_DB.REFERENCE
    COMMENT = 'Seed tables and reference data';

-- =====================================================
-- STEP 3: Create warehouse
-- =====================================================
CREATE WAREHOUSE IF NOT EXISTS DBT_WH 
    WITH 
        WAREHOUSE_SIZE = 'XSMALL'
        AUTO_SUSPEND = 60          -- Suspend after 1 minute idle
        AUTO_RESUME = TRUE
        INITIALLY_SUSPENDED = TRUE
        COMMENT = 'Warehouse for dbt project execution';

-- =====================================================
-- STEP 4: Enable monitoring on dbt projects schema
-- =====================================================
ALTER SCHEMA COURSE_DB.DBT_PROJECTS SET LOG_LEVEL = 'INFO';
ALTER SCHEMA COURSE_DB.DBT_PROJECTS SET TRACE_LEVEL = 'ALWAYS';
ALTER SCHEMA COURSE_DB.DBT_PROJECTS SET METRIC_LEVEL = 'ALL';
```

> **💡 TIP: Warehouse Sizing**
> 
> Start with XSMALL for development:
> - **XSMALL**: Development, testing, small datasets
> - **SMALL/MEDIUM**: Production with moderate data volumes
> - **LARGE+**: Large transformations, tight SLAs
> 
> Snowflake charges per-second, so auto-suspend is crucial!

> **💡 TIP: Monitoring Levels**
> 
> | Setting | Value | Purpose |
> |---------|-------|---------|
> | `LOG_LEVEL` | INFO | Capture dbt logs |
> | `TRACE_LEVEL` | ALWAYS | Enable query profiling |
> | `METRIC_LEVEL` | ALL | Capture all metrics |
> 
> These enable rich monitoring data in Snowsight.

### Step 2: Create Sample Source Data

```sql
-- =====================================================
-- Create CUSTOMERS source table
-- =====================================================
CREATE OR REPLACE TABLE COURSE_DB.RAW.CUSTOMERS (
    customer_id INTEGER PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(200),
    phone VARCHAR(20),
    country_code VARCHAR(3),
    status VARCHAR(20) DEFAULT 'active',
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Raw customer data from CRM system';

-- Insert sample data
INSERT INTO COURSE_DB.RAW.CUSTOMERS 
    (customer_id, first_name, last_name, email, phone, country_code, status, created_at, updated_at)
VALUES
    (1, 'John', 'Doe', 'john.doe@email.com', '555-0101', 'USA', 'active', '2024-01-15 10:30:00', '2024-01-15 10:30:00'),
    (2, 'Jane', 'Smith', 'jane.smith@email.com', '555-0102', 'USA', 'active', '2024-01-16 14:20:00', '2024-02-01 09:15:00'),
    (3, 'Bob', 'Wilson', 'bob.wilson@email.com', '555-0103', 'CAN', 'active', '2024-02-01 08:45:00', '2024-02-01 08:45:00'),
    (4, 'Alice', 'Brown', 'alice.brown@email.com', '555-0104', 'GBR', 'inactive', '2024-02-05 11:00:00', '2024-02-20 16:30:00'),
    (5, 'Charlie', 'Davis', 'charlie.d@email.com', '555-0105', 'USA', 'active', '2024-02-10 09:00:00', '2024-02-10 09:00:00');

-- =====================================================
-- Create PRODUCTS source table
-- =====================================================
CREATE OR REPLACE TABLE COURSE_DB.RAW.PRODUCTS (
    product_id INTEGER PRIMARY KEY,
    product_name VARCHAR(200),
    category VARCHAR(100),
    unit_price DECIMAL(10,2),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Product catalog from inventory system';

INSERT INTO COURSE_DB.RAW.PRODUCTS
    (product_id, product_name, category, unit_price, is_active, created_at, updated_at)
VALUES
    (101, 'Widget Pro', 'Widgets', 49.99, TRUE, '2024-01-01', '2024-01-01'),
    (102, 'Widget Basic', 'Widgets', 29.99, TRUE, '2024-01-01', '2024-01-15'),
    (103, 'Gadget X', 'Gadgets', 99.99, TRUE, '2024-01-10', '2024-01-10'),
    (104, 'Gadget Mini', 'Gadgets', 59.99, TRUE, '2024-01-15', '2024-02-01'),
    (105, 'Legacy Item', 'Discontinued', 19.99, FALSE, '2023-01-01', '2024-02-01');

-- =====================================================
-- Create ORDERS source table
-- =====================================================
CREATE OR REPLACE TABLE COURSE_DB.RAW.ORDERS (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER,
    order_date DATE,
    status VARCHAR(50),
    shipping_address VARCHAR(500),
    total_amount DECIMAL(10,2),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
)
COMMENT = 'Order headers from e-commerce platform';

INSERT INTO COURSE_DB.RAW.ORDERS 
    (order_id, customer_id, order_date, status, shipping_address, total_amount, created_at)
VALUES
    (1001, 1, '2024-01-20', 'completed', '123 Main St, New York, NY', 150.00, '2024-01-20 10:00:00'),
    (1002, 1, '2024-02-05', 'completed', '123 Main St, New York, NY', 89.99, '2024-02-05 14:30:00'),
    (1003, 2, '2024-02-10', 'pending', '456 Oak Ave, Los Angeles, CA', 250.50, '2024-02-10 09:15:00'),
    (1004, 3, '2024-02-15', 'completed', '789 Maple Rd, Toronto, ON', 75.00, '2024-02-15 11:45:00'),
    (1005, 4, '2024-02-18', 'shipped', '10 Baker St, London, UK', 199.99, '2024-02-18 16:00:00'),
    (1006, 5, '2024-02-20', 'completed', '555 Pine Ln, Boston, MA', 349.97, '2024-02-20 08:30:00'),
    (1007, 1, '2024-02-22', 'pending', '123 Main St, New York, NY', 129.98, '2024-02-22 12:00:00');

-- =====================================================
-- Create ORDER_ITEMS source table  
-- =====================================================
CREATE OR REPLACE TABLE COURSE_DB.RAW.ORDER_ITEMS (
    order_item_id INTEGER PRIMARY KEY,
    order_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    unit_price DECIMAL(10,2),
    discount_amount DECIMAL(10,2) DEFAULT 0
)
COMMENT = 'Order line items';

INSERT INTO COURSE_DB.RAW.ORDER_ITEMS
    (order_item_id, order_id, product_id, quantity, unit_price, discount_amount)
VALUES
    (1, 1001, 101, 2, 49.99, 0),
    (2, 1001, 102, 1, 29.99, 0),
    (3, 1002, 102, 3, 29.99, 0),
    (4, 1003, 103, 2, 99.99, 0),
    (5, 1003, 104, 1, 59.99, 9.47),
    (6, 1004, 102, 2, 29.99, 0),
    (7, 1004, 105, 1, 19.99, 4.97),
    (8, 1005, 103, 2, 99.99, 0),
    (9, 1006, 101, 3, 49.99, 0),
    (10, 1006, 103, 2, 99.99, 0),
    (11, 1007, 104, 2, 59.99, 0),
    (12, 1007, 105, 1, 19.99, 9.99);
```

> **💡 TIP: Test Data Best Practices**
> 
> - Include edge cases (NULL values, special characters)
> - Use realistic volumes for performance testing
> - Include various statuses and states
> - Add data spanning different time periods

### Step 3: Verify Setup

```sql
-- =====================================================
-- Verification queries
-- =====================================================

-- Check schemas created
SHOW SCHEMAS IN DATABASE COURSE_DB;

-- Check tables created
SHOW TABLES IN SCHEMA COURSE_DB.RAW;

-- Verify data counts
SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS row_count FROM COURSE_DB.RAW.CUSTOMERS
UNION ALL
SELECT 'PRODUCTS', COUNT(*) FROM COURSE_DB.RAW.PRODUCTS
UNION ALL
SELECT 'ORDERS', COUNT(*) FROM COURSE_DB.RAW.ORDERS
UNION ALL
SELECT 'ORDER_ITEMS', COUNT(*) FROM COURSE_DB.RAW.ORDER_ITEMS;

-- Preview sample data
SELECT * FROM COURSE_DB.RAW.CUSTOMERS LIMIT 5;
SELECT * FROM COURSE_DB.RAW.ORDERS LIMIT 5;

-- Verify monitoring settings
SHOW PARAMETERS LIKE '%LEVEL%' IN SCHEMA COURSE_DB.DBT_PROJECTS;

-- Check warehouse exists
SHOW WAREHOUSES LIKE 'DBT_WH';
```

> **✅ Expected Results:**
> - 7 schemas in COURSE_DB
> - 4 tables in RAW schema
> - CUSTOMERS: 5 rows
> - PRODUCTS: 5 rows
> - ORDERS: 7 rows
> - ORDER_ITEMS: 12 rows

### Step 4: Test Snowflake CLI Connection

```bash
# Test connection
snow connection test

# Run simple query
snow sql -q "SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE();"

# List schemas
snow sql -q "SHOW SCHEMAS IN DATABASE COURSE_DB;"

# Check dbt version support
snow sql -q "SELECT SYSTEM\$SUPPORTED_DBT_VERSIONS();"
```

---

## Summary

In this section, you learned:

| Topic | Key Takeaway |
|-------|--------------|
| **What is dbt Projects** | Native Snowflake objects for running dbt Core without external infrastructure |
| **Architecture** | Git/Workspace → DBT PROJECT → EXECUTE → Output (tables, views, logs) |
| **Prerequisites** | Snowflake CLI 2.0+, CREATE DBT PROJECT privilege on schema, warehouse |
| **Project Structure** | models/ (staging→intermediate→marts), macros/, tests/, seeds/, snapshots/ |
| **Configuration** | dbt_project.yml defines project; profiles.yml defines connections |
| **Medallion Pattern** | Bronze (raw) → Silver (cleaned) → Gold (curated) |

### Key Commands Learned

```sql
-- Snowflake SQL
SHOW DBT PROJECTS IN DATABASE ...;
DESCRIBE DBT PROJECT ...;
ALTER SCHEMA ... SET LOG_LEVEL = 'INFO';
```

```bash
# Snowflake CLI
snow connection test
snow connection list
snow sql -q "..."
```

---

## Quick Reference

### Essential Privileges

```sql
GRANT CREATE DBT PROJECT ON SCHEMA <schema> TO ROLE <role>;
GRANT USAGE ON WAREHOUSE <wh> TO ROLE <role>;
GRANT CREATE TABLE ON SCHEMA <schema> TO ROLE <role>;
```

### Minimum Configuration Files

1. **dbt_project.yml** - Required for all dbt projects
2. **profiles.yml** - Required for local development
3. **sources.yml** - Required for source data documentation

### Troubleshooting Checklist

| Issue | Check |
|-------|-------|
| Cannot create dbt project | Verify CREATE DBT PROJECT on schema |
| Connection fails | Verify `snow connection test` |
| Warehouse not found | Check USAGE privilege on warehouse |
| Schema permission denied | Verify CREATE TABLE/VIEW privileges |

---

## Additional Resources

### Official Documentation
- [dbt Projects on Snowflake Overview](https://docs.snowflake.com/en/user-guide/dbt-projects/overview)
- [Snowflake CLI Installation](https://docs.snowflake.com/en/developer-guide/snowflake-cli-v2/installation/installation)
- [dbt Core Documentation](https://docs.getdbt.com/docs/introduction)

### Community Resources
- [dbt Discourse Forum](https://discourse.getdbt.com/)
- [Snowflake Community](https://community.snowflake.com/)
- [dbt Slack Community](https://getdbt.com/community)

### Recommended Reading
- [dbt Best Practices](https://docs.getdbt.com/guides/best-practices)
- [Snowflake Data Modeling](https://docs.snowflake.com/en/user-guide/data-modeling)

---

## Next Section

In [Section 2: Development & Models](02-development-models.md), you'll learn:
- Using Snowflake Workspaces for development
- Creating sources, models, and tests
- Working with macros
- All dbt Core commands (build, run, test, seed, snapshot, etc.)
- Development workflow best practices
