# Section 2: Development & Models (10 minutes)

## Learning Objectives

By the end of this section, you will:
- Use Snowflake Workspaces for dbt development
- Visualize DAG dependencies
- Create sources, models, and tests
- Write custom macros
- Master all dbt Core commands
- Understand best practices for each component

---

## 2.1 Snowflake Workspaces

Workspaces are **Git-connected web IDEs** within Snowsight for developing dbt projects.

### Features

- Edit dbt project files directly in browser
- Connect to Git repositories (GitHub, GitLab, Bitbucket, Azure DevOps)
- Visualize model DAG
- Execute dbt commands interactively
- Deploy to DBT PROJECT objects
- Integrated SQL worksheet for testing

> **💡 TIP: When to Use Workspaces vs Local Development**
> 
> | Scenario | Recommended Approach |
> |----------|---------------------|
> | Quick edits and testing | Workspace |
> | Complex development | Local IDE + CLI |
> | CI/CD pipeline | CLI automation |
> | Learning/exploration | Workspace |
> | Team collaboration | Git + either approach |

### Creating a Workspace

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           Snowsight Navigation                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  1. Navigate to: Data Engineering → Workspaces                              │
│                                                                             │
│  2. Click: + Create Workspace                                               │
│                                                                             │
│  3. Options:                                                                │
│     ┌─────────────────────┐    ┌─────────────────────┐                     │
│     │ Start from scratch  │    │ Connect to Git repo │                     │
│     │ • Empty workspace   │    │ • GitHub            │                     │
│     │ • Local development │    │ • GitLab            │                     │
│     │ • Great for testing │    │ • Bitbucket         │                     │
│     └─────────────────────┘    │ • Azure DevOps      │                     │
│                                └─────────────────────┘                     │
│                                                                             │
│  4. Configure:                                                              │
│     • Workspace name                                                        │
│     • Database and schema (for deployment)                                  │
│     • Warehouse (for execution)                                             │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Connecting to Git Repository

```sql
-- Step 1: Create a secret for Git credentials (personal access token)
CREATE OR REPLACE SECRET course_db.integrations.git_pat
    TYPE = PASSWORD
    USERNAME = 'your-username'
    PASSWORD = 'ghp_xxxxxxxxxxxxxxxxxxxx';  -- GitHub PAT

-- Step 2: Create an API integration for Git
CREATE OR REPLACE API INTEGRATION git_api_integration
    API_PROVIDER = git_https_api
    API_ALLOWED_PREFIXES = ('https://github.com/your-org/')
    ALLOWED_AUTHENTICATION_SECRETS = (course_db.integrations.git_pat)
    ENABLED = TRUE;

-- Step 3: Create Git repository object
CREATE OR REPLACE GIT REPOSITORY course_db.integrations.my_dbt_repo
    API_INTEGRATION = git_api_integration
    GIT_CREDENTIALS = course_db.integrations.git_pat
    ORIGIN = 'https://github.com/your-org/my-dbt-project.git';

-- Step 4: Fetch latest from repository
ALTER GIT REPOSITORY course_db.integrations.my_dbt_repo FETCH;

-- Step 5: List branches
SHOW GIT BRANCHES IN GIT REPOSITORY course_db.integrations.my_dbt_repo;

-- Step 6: View files in a branch
LIST @course_db.integrations.my_dbt_repo/branches/main/;
```

> **⚠️ WARNING: Git Integration Security**
> 
> - Use **fine-grained personal access tokens** with minimal permissions
> - Never use tokens with write access unless absolutely necessary
> - Rotate tokens regularly (recommend 90-day expiration)
> - Store tokens as Snowflake secrets, never in code

> **💡 TIP: Git Repository Structure**
> 
> Your Git repository should have the dbt project at the root level:
> ```
> my-dbt-project/          ← Repository root
> ├── dbt_project.yml      ← Required at root
> ├── models/
> ├── macros/
> └── ...
> ```
> If dbt files are in a subdirectory, you'll need to specify the path during deployment.

> **📚 REFERENCE: Git Integration**
> - [Snowflake Git Integration](https://docs.snowflake.com/en/developer-guide/git/git-overview)
> - [Creating API Integrations](https://docs.snowflake.com/en/sql-reference/sql/create-api-integration)

---

## 2.2 DAG Visualization

The Directed Acyclic Graph (DAG) shows model dependencies and is essential for understanding data flow.

### Understanding the DAG

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              DAG Visualization                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   SOURCES                    STAGING               INTERMEDIATE    MARTS   │
│   ────────                   ───────               ────────────    ─────   │
│                                                                             │
│   ┌────────────┐         ┌──────────────┐                                  │
│   │ raw.       │────────►│ stg_         │                                  │
│   │ customers  │         │ customers    │──────┐                           │
│   └────────────┘         └──────────────┘      │                           │
│                                                │    ┌────────────────┐     │
│                                                ├───►│ int_customer_  │     │
│                                                │    │ orders         │─┐   │
│   ┌────────────┐         ┌──────────────┐      │    └────────────────┘ │   │
│   │ raw.       │────────►│ stg_         │──────┤                       │   │
│   │ orders     │         │ orders       │      │    ┌──────────────┐   │   │
│   └────────────┘         └──────────────┘      │    │ dim_         │◄──┘   │
│                                                └───►│ customers    │       │
│   ┌────────────┐         ┌──────────────┐          └──────────────┘       │
│   │ raw.       │────────►│ stg_         │──────┐                           │
│   │ products   │         │ products     │      │    ┌──────────────┐       │
│   └────────────┘         └──────────────┘      ├───►│ fct_orders   │       │
│                                                │    └──────────────┘       │
│   ┌────────────┐         ┌──────────────┐      │                           │
│   │ raw.       │────────►│ stg_         │──────┘    ┌──────────────┐       │
│   │ order_items│         │ order_items  │──────────►│ fct_order_   │       │
│   └────────────┘         └──────────────┘           │ items        │       │
│                                                     └──────────────┘       │
│                                                                             │
│   Legend:                                                                   │
│   ───► = dependency (downstream depends on upstream)                        │
│   Yellow box = source                                                       │
│   Green box = model                                                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Accessing DAG in Workspace

1. Open your workspace in Snowsight
2. Click the **Lineage** tab (top navigation)
3. Select a model to see upstream/downstream dependencies
4. Use filters to focus on specific layers
5. Click on nodes to navigate to source code

> **💡 TIP: DAG Best Practices**
> 
> - **Keep DAG shallow**: Aim for 3-4 layers maximum (source → staging → intermediate → mart)
> - **Avoid cycles**: dbt will error if you create circular dependencies
> - **Minimize fan-out**: A model that feeds too many downstream models becomes a bottleneck
> - **Use modular intermediate models**: Break complex transformations into testable steps

### Node Selection Syntax

Understanding node selection is crucial for efficient dbt operations:

```bash
# Select a single model
--select dim_customers

# Select all models in a folder
--select staging.*

# Select model and all downstream (children)
--select stg_customers+

# Select model and all upstream (parents)
--select +fct_orders

# Select model and both directions
--select +dim_customers+

# Select by tag
--select tag:daily

# Select by materialization
--select config.materialized:table

# Exclude models
--exclude staging.*

# Combine selections (union)
--select staging.* marts.*

# Intersection
--select staging.*,tag:critical
```

> **📚 REFERENCE: Node Selection**
> - [dbt Node Selection Syntax](https://docs.getdbt.com/reference/node-selection/syntax)
> - [Graph Operators](https://docs.getdbt.com/reference/node-selection/graph-operators)

---

## 2.3 Sources

Sources define your raw data tables that dbt reads from. Proper source configuration is the foundation of a good dbt project.

### sources.yml Structure

```yaml
# models/staging/sources.yml
version: 2

sources:
  - name: raw                          # Logical name for this source group
    description: "Raw data from operational systems"
    database: COURSE_DB                # Physical database
    schema: RAW                        # Physical schema
    
    # Source-level freshness (optional)
    freshness:
      warn_after: {count: 24, period: hour}
      error_after: {count: 48, period: hour}
    loaded_at_field: _etl_loaded_at    # Column for freshness check
    
    # Source-level tags
    tags: ['raw', 'source']
    
    tables:
      - name: customers
        description: "Customer master data from CRM"
        identifier: CUSTOMERS          # Physical table name (if different)
        
        # Table-level freshness override
        freshness:
          warn_after: {count: 12, period: hour}
        loaded_at_field: updated_at
        
        columns:
          - name: customer_id
            description: "Primary key - unique customer identifier"
            tests:
              - unique
              - not_null
              
          - name: email
            description: "Customer email address"
            tests:
              - unique:
                  severity: warn       # Downgrade to warning
              - not_null
                  
          - name: created_at
            description: "Account creation timestamp"
            tests:
              - not_null
              
      - name: orders
        description: "Transaction orders from e-commerce platform"
        columns:
          - name: order_id
            description: "Primary key"
            tests:
              - unique
              - not_null
              
          - name: customer_id
            description: "Foreign key to customers"
            tests:
              - not_null
              - relationships:
                  to: source('raw', 'customers')
                  field: customer_id
                  severity: error
                  
          - name: total_amount
            description: "Order total in USD"
            tests:
              - not_null
              - dbt_expectations.expect_column_values_to_be_between:
                  min_value: 0
                  max_value: 100000
                  
      - name: products
        description: "Product catalog"
        
      - name: order_items
        description: "Order line items"
```

> **💡 TIP: Source Organization**
> 
> - Group related tables under one source name
> - Use descriptive names that match your data domains
> - Put sources.yml in the staging folder (closest to where it's used)
> - One sources.yml per source system for large projects

> **⚠️ WARNING: Common Source Mistakes**
> 
> - **Case sensitivity**: Snowflake identifiers are uppercase by default. Use `identifier` or `quoting` if needed
> - **Missing freshness column**: If you use freshness, ensure the column exists
> - **Circular references**: Don't reference models in source definitions

### Using Sources in Models

```sql
-- models/staging/stg_customers.sql
-- ALWAYS use the source() function, never hardcode table names

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    created_at,
    updated_at
FROM {{ source('raw', 'customers') }}

-- This compiles to: FROM COURSE_DB.RAW.CUSTOMERS
```

> **💡 TIP: Why Use source() Instead of Direct Table References?**
> 
> 1. **Documentation**: Sources appear in dbt docs and DAG
> 2. **Testing**: Source tests run during `dbt test`
> 3. **Freshness**: Can check data freshness with `dbt source freshness`
> 4. **Flexibility**: Change database/schema in one place
> 5. **Lineage**: Complete lineage from source to mart

### Check Source Freshness

```bash
# Check freshness of all sources
snow dbt execute my_project "source freshness" --database COURSE_DB --schema DBT_PROJECTS

# Check specific source
snow dbt execute my_project "source freshness --select source:raw.customers" \
    --database COURSE_DB --schema DBT_PROJECTS
```

> **📚 REFERENCE: Sources**
> - [dbt Sources Documentation](https://docs.getdbt.com/docs/build/sources)
> - [Source Freshness](https://docs.getdbt.com/docs/build/sources#source-data-freshness)

---

## 2.4 Models

Models are SQL SELECT statements that transform data. They are the core of any dbt project.

### Model Configuration Options

```sql
-- Full config block with all common options
{{
    config(
        -- Materialization
        materialized='table',          -- view, table, incremental, ephemeral
        
        -- Schema/Database
        schema='gold',                 -- Output schema suffix
        database='PROD_DB',            -- Output database (optional)
        alias='customer_dimension',    -- Output table name (default: filename)
        
        -- Snowflake-specific
        transient=false,               -- Transient table (no fail-safe)
        cluster_by=['customer_id'],    -- Clustering keys
        copy_grants=true,              -- Preserve grants on rebuild
        
        -- Query optimization
        query_tag='dbt_mart',          -- Tag for query history
        
        -- Permissions
        grants={'select': ['ANALYST_ROLE', 'BI_ROLE']},
        
        -- Tags and metadata
        tags=['mart', 'daily', 'customer'],
        
        -- Incremental-specific
        unique_key='customer_id',      -- For merge operations
        incremental_strategy='merge',  -- merge, delete+insert, append
        
        -- Contract (dbt 1.5+)
        contract={'enforced': true}
    )
}}
```

### Staging Models (Bronze Layer)

Staging models should:
- Have a 1:1 relationship with source tables
- Perform only light transformations (renaming, type casting, basic cleaning)
- Be materialized as views (to save storage)
- Use consistent naming: `stg_<source>__<table>`

```sql
-- models/staging/stg_customers.sql
{{
    config(
        materialized='view',
        schema='staging'
    )
}}

WITH source AS (
    SELECT * FROM {{ source('raw', 'customers') }}
),

renamed_and_cleaned AS (
    SELECT
        -- Primary key
        customer_id,
        
        -- Standardize text fields
        TRIM(UPPER(first_name)) AS first_name,
        TRIM(UPPER(last_name)) AS last_name,
        LOWER(TRIM(email)) AS email,
        
        -- Standardize phone (remove non-digits)
        REGEXP_REPLACE(phone, '[^0-9]', '') AS phone_cleaned,
        
        -- Keep original for reference
        phone AS phone_original,
        
        -- Status standardization
        UPPER(COALESCE(status, 'UNKNOWN')) AS status,
        
        -- Country code validation
        CASE 
            WHEN LENGTH(country_code) = 3 THEN UPPER(country_code)
            ELSE 'UNK'
        END AS country_code,
        
        -- Timestamps
        created_at,
        updated_at,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS _stg_loaded_at
        
    FROM source
    
    -- Filter out obviously invalid records
    WHERE customer_id IS NOT NULL
)

SELECT * FROM renamed_and_cleaned
```

> **💡 TIP: Staging Model Best Practices**
> 
> - **One source, one staging model**: Don't combine sources in staging
> - **No business logic**: Save that for intermediate/mart layers
> - **Consistent column naming**: Establish conventions (snake_case recommended)
> - **Add metadata columns**: `_stg_loaded_at`, `_source_file`, etc.
> - **Handle NULLs explicitly**: Use COALESCE with sensible defaults

### Intermediate Models (Silver Layer)

Intermediate models should:
- Contain business logic, joins, and aggregations
- Be reusable across multiple mart models
- Be materialized as tables (for performance)
- Use naming: `int_<business_concept>__<transformation>`

```sql
-- models/intermediate/int_customer_orders.sql
{{
    config(
        materialized='table',
        schema='silver',
        tags=['intermediate', 'customer']
    )
}}

WITH customers AS (
    SELECT * FROM {{ ref('stg_customers') }}
),

orders AS (
    SELECT * FROM {{ ref('stg_orders') }}
),

order_items AS (
    SELECT * FROM {{ ref('stg_order_items') }}
),

-- Calculate order-level metrics
order_metrics AS (
    SELECT
        order_id,
        COUNT(*) AS item_count,
        SUM(quantity) AS total_quantity,
        SUM(unit_price * quantity) AS gross_amount,
        SUM(discount_amount) AS total_discount
    FROM order_items
    GROUP BY order_id
),

-- Aggregate to customer level
customer_order_summary AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        c.email,
        c.status AS customer_status,
        c.country_code,
        c.created_at AS customer_created_at,
        
        -- Order metrics
        COUNT(DISTINCT o.order_id) AS total_orders,
        COUNT(DISTINCT CASE WHEN o.status = 'COMPLETED' THEN o.order_id END) AS completed_orders,
        COUNT(DISTINCT CASE WHEN o.status = 'PENDING' THEN o.order_id END) AS pending_orders,
        
        -- Financial metrics
        COALESCE(SUM(o.total_amount), 0) AS lifetime_value,
        COALESCE(AVG(o.total_amount), 0) AS avg_order_value,
        COALESCE(MAX(o.total_amount), 0) AS max_order_value,
        
        -- Item metrics
        COALESCE(SUM(om.item_count), 0) AS total_items_purchased,
        COALESCE(SUM(om.total_discount), 0) AS total_discounts_received,
        
        -- Timing metrics
        MIN(o.order_date) AS first_order_date,
        MAX(o.order_date) AS last_order_date,
        DATEDIFF('day', MIN(o.order_date), MAX(o.order_date)) AS customer_tenure_days,
        DATEDIFF('day', MAX(o.order_date), CURRENT_DATE()) AS days_since_last_order
        
    FROM customers c
    LEFT JOIN orders o ON c.customer_id = o.customer_id
    LEFT JOIN order_metrics om ON o.order_id = om.order_id
    GROUP BY 1, 2, 3, 4, 5, 6, 7
)

SELECT * FROM customer_order_summary
```

> **💡 TIP: Intermediate Model Best Practices**
> 
> - **One concept per model**: `int_customer_orders`, `int_product_inventory`
> - **Pre-aggregate where possible**: Reduce data volume for downstream
> - **Document business logic**: Complex calculations need comments
> - **Make them reusable**: If only one mart uses it, consider merging

### Mart Models (Gold Layer)

Mart models should:
- Be analytics-ready (optimized for BI tools)
- Follow dimensional modeling (dims and facts)
- Be materialized as tables with clustering
- Use naming: `dim_<entity>` or `fct_<event>` or `agg_<aggregation>`

```sql
-- models/marts/dim_customers.sql
{{
    config(
        materialized='table',
        schema='gold',
        tags=['mart', 'dimension', 'customer'],
        cluster_by=['customer_tier', 'country_code'],
        grants={'select': ['ANALYST_ROLE', 'BI_ROLE']}
    )
}}

WITH customer_orders AS (
    SELECT * FROM {{ ref('int_customer_orders') }}
),

-- Add business classifications
classified AS (
    SELECT
        -- Surrogate key (for fact table joins)
        {{ generate_surrogate_key(['customer_id']) }} AS customer_key,
        
        -- Natural key
        customer_id,
        
        -- Attributes
        first_name,
        last_name,
        first_name || ' ' || last_name AS full_name,
        email,
        customer_status,
        country_code,
        
        -- Metrics (denormalized for easy access)
        total_orders,
        completed_orders,
        pending_orders,
        lifetime_value,
        avg_order_value,
        total_items_purchased,
        
        -- Calculated dates
        first_order_date,
        last_order_date,
        customer_tenure_days,
        days_since_last_order,
        customer_created_at,
        
        -- Business classifications
        CASE
            WHEN lifetime_value >= 1000 THEN 'Premium'
            WHEN lifetime_value >= 250 THEN 'Gold'
            WHEN lifetime_value >= 100 THEN 'Silver'
            WHEN lifetime_value > 0 THEN 'Bronze'
            ELSE 'Prospect'
        END AS customer_tier,
        
        CASE
            WHEN days_since_last_order IS NULL THEN 'Never Purchased'
            WHEN days_since_last_order <= 30 THEN 'Active'
            WHEN days_since_last_order <= 90 THEN 'At Risk'
            WHEN days_since_last_order <= 180 THEN 'Lapsed'
            ELSE 'Churned'
        END AS activity_status,
        
        CASE
            WHEN total_orders >= 10 THEN 'Loyal'
            WHEN total_orders >= 5 THEN 'Regular'
            WHEN total_orders >= 2 THEN 'Returning'
            WHEN total_orders = 1 THEN 'New'
            ELSE 'Prospect'
        END AS loyalty_segment,
        
        -- Metadata
        CURRENT_TIMESTAMP() AS dbt_updated_at
        
    FROM customer_orders
)

SELECT * FROM classified
```

> **💡 TIP: Mart Model Best Practices**
> 
> - **Denormalize carefully**: Include frequently-joined attributes
> - **Add business classifications**: Tiers, segments, statuses
> - **Include surrogate keys**: For fact-dimension relationships
> - **Cluster strategically**: On frequently filtered columns
> - **Grant access automatically**: Use `grants` config

> **⚠️ WARNING: Avoid These Mart Anti-Patterns**
> 
> - **Too much business logic**: Keep complex calcs in intermediate layer
> - **Missing documentation**: Business users need column descriptions
> - **No tests**: At minimum, test unique/not_null on keys
> - **Hardcoded values**: Use variables for thresholds that may change

### Model Schema Documentation

```yaml
# models/marts/_marts.yml
version: 2

models:
  - name: dim_customers
    description: |
      Customer dimension table with calculated metrics and business classifications.
      
      **Grain**: One row per customer
      **Update Frequency**: Daily
      **Primary Key**: customer_key
      **Owner**: Analytics Team
      
    meta:
      owner: analytics@company.com
      tier: gold
      pii: true
      
    columns:
      - name: customer_key
        description: "Surrogate key (MD5 hash of customer_id)"
        tests:
          - unique
          - not_null
          
      - name: customer_id
        description: "Natural key from source system"
        tests:
          - unique
          - not_null
          
      - name: email
        description: "Customer email (PII - handle appropriately)"
        meta:
          pii: true
        tests:
          - not_null
          - dbt_expectations.expect_column_values_to_match_regex:
              regex: '^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9-.]+$'
              
      - name: customer_tier
        description: |
          Customer value tier based on lifetime value:
          - Premium: >= $1000
          - Gold: >= $250
          - Silver: >= $100
          - Bronze: > $0
          - Prospect: No purchases
        tests:
          - accepted_values:
              values: ['Premium', 'Gold', 'Silver', 'Bronze', 'Prospect']
              
      - name: activity_status
        description: "Customer activity status based on recency"
        tests:
          - accepted_values:
              values: ['Active', 'At Risk', 'Lapsed', 'Churned', 'Never Purchased']

  - name: fct_orders
    description: "Order fact table - one row per order"
    columns:
      - name: order_key
        description: "Surrogate key"
        tests:
          - unique
          - not_null
      - name: customer_key
        description: "Foreign key to dim_customers"
        tests:
          - relationships:
              to: ref('dim_customers')
              field: customer_key
```

> **📚 REFERENCE: Model Configuration**
> - [dbt Model Configurations](https://docs.getdbt.com/reference/model-configs)
> - [Snowflake-specific Configs](https://docs.getdbt.com/reference/resource-configs/snowflake-configs)

---

## 2.5 Tests

Testing is critical for data quality. dbt supports both generic (schema) tests and singular (custom SQL) tests.

### Built-in Generic Tests

| Test | Purpose | Example Use |
|------|---------|-------------|
| `unique` | No duplicate values | Primary keys, business keys |
| `not_null` | No NULL values | Required fields |
| `accepted_values` | Only allowed values | Status codes, categories |
| `relationships` | Foreign key exists | Join integrity |

### Configuring Tests

```yaml
# models/marts/_marts.yml
version: 2

models:
  - name: fct_orders
    columns:
      - name: order_key
        tests:
          - unique
          - not_null
          
      - name: status
        tests:
          - accepted_values:
              values: ['PENDING', 'SHIPPED', 'COMPLETED', 'CANCELLED', 'REFUNDED']
              quote: true              # Quote string values
              
      - name: customer_key
        tests:
          - not_null:
              severity: error          # Fail the build
          - relationships:
              to: ref('dim_customers')
              field: customer_key
              severity: warn           # Just warn
              
      - name: total_amount
        tests:
          - not_null
          # Using dbt_expectations package
          - dbt_expectations.expect_column_values_to_be_between:
              min_value: 0
              max_value: 100000
              row_condition: "status != 'CANCELLED'"
```

### Custom Singular Tests

Singular tests are SQL queries that return failing rows:

```sql
-- tests/test_order_totals_match_items.sql
-- Verify that order totals match sum of line items

WITH order_totals AS (
    SELECT
        order_id,
        total_amount AS header_total
    FROM {{ ref('fct_orders') }}
),

item_totals AS (
    SELECT
        order_id,
        SUM(line_total) AS calculated_total
    FROM {{ ref('fct_order_items') }}
    GROUP BY order_id
),

mismatched AS (
    SELECT
        ot.order_id,
        ot.header_total,
        it.calculated_total,
        ABS(ot.header_total - it.calculated_total) AS difference
    FROM order_totals ot
    JOIN item_totals it ON ot.order_id = it.order_id
    WHERE ABS(ot.header_total - it.calculated_total) > 0.01  -- Allow penny tolerance
)

SELECT * FROM mismatched
```

```sql
-- tests/test_no_future_order_dates.sql
-- Orders should not have future dates

SELECT
    order_id,
    order_date,
    CURRENT_DATE() AS today
FROM {{ ref('fct_orders') }}
WHERE order_date > CURRENT_DATE()
```

```sql
-- tests/test_customer_segment_consistency.sql
-- Verify segment logic is consistent

SELECT
    customer_id,
    lifetime_value,
    customer_tier,
    CASE
        WHEN lifetime_value >= 1000 THEN 'Premium'
        WHEN lifetime_value >= 250 THEN 'Gold'
        WHEN lifetime_value >= 100 THEN 'Silver'
        WHEN lifetime_value > 0 THEN 'Bronze'
        ELSE 'Prospect'
    END AS expected_tier
FROM {{ ref('dim_customers') }}
WHERE customer_tier != expected_tier
```

> **💡 TIP: Test Organization**
> 
> - **Generic tests**: Define in YAML files alongside models
> - **Singular tests**: Put in `tests/` folder, name descriptively
> - **Test naming**: `test_<what_is_being_tested>.sql`
> - **Subdirectories**: Organize by domain: `tests/marts/`, `tests/finance/`

### Custom Generic Tests (Macros)

Create reusable test macros:

```sql
-- macros/tests/test_positive_value.sql
{% test positive_value(model, column_name) %}

WITH validation AS (
    SELECT
        {{ column_name }} AS value_to_check
    FROM {{ model }}
    WHERE {{ column_name }} IS NOT NULL
)

SELECT *
FROM validation
WHERE value_to_check <= 0

{% endtest %}
```

```sql
-- macros/tests/test_valid_email.sql
{% test valid_email(model, column_name) %}

SELECT
    {{ column_name }} AS invalid_email
FROM {{ model }}
WHERE {{ column_name }} IS NOT NULL
  AND {{ column_name }} NOT REGEXP '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$'

{% endtest %}
```

Usage in YAML:
```yaml
columns:
  - name: total_amount
    tests:
      - positive_value
      
  - name: email
    tests:
      - valid_email
```

### Test Configuration

```yaml
# dbt_project.yml
tests:
  +severity: warn                 # Default: warn instead of error
  +store_failures: true           # Store failing rows
  +store_failures_as: table       # table or view
  +schema: test_failures          # Where to store failures
  +limit: 100                     # Limit failing rows stored

  # Folder-specific overrides
  course_dbt_project:
    marts:
      +severity: error            # Mart tests must pass
```

> **⚠️ WARNING: Test Performance**
> 
> Tests scan entire tables. For large tables:
> - Use `where` config to test recent data only
> - Use `limit` to cap failing row storage
> - Consider sampling for expensive tests
> - Run full tests in off-peak hours

> **📚 REFERENCE: Testing**
> - [dbt Testing Documentation](https://docs.getdbt.com/docs/build/tests)
> - [dbt Expectations Package](https://github.com/calogica/dbt-expectations)
> - [Data Testing Best Practices](https://docs.getdbt.com/blog/write-better-tests-with-dbt)

---

## 2.6 Macros

Macros are reusable Jinja templates that generate SQL. They're powerful for DRY (Don't Repeat Yourself) coding.

### Simple Value Macro

```sql
-- macros/utilities/cents_to_dollars.sql
{% macro cents_to_dollars(column_name, precision=2) %}
    ROUND({{ column_name }} / 100.0, {{ precision }})::DECIMAL(18, {{ precision }})
{% endmacro %}
```

Usage:
```sql
SELECT
    order_id,
    {{ cents_to_dollars('amount_cents') }} AS amount_dollars,
    {{ cents_to_dollars('tax_cents', 4) }} AS tax_dollars
FROM orders
```

### Surrogate Key Macro

```sql
-- macros/utilities/generate_surrogate_key.sql
{% macro generate_surrogate_key(field_list) %}
    {%- set fields = [] -%}
    {%- for field in field_list -%}
        {%- set _ = fields.append(
            "COALESCE(CAST(" ~ field ~ " AS VARCHAR), '_null_')"
        ) -%}
    {%- endfor -%}
    MD5({{ fields | join(" || '|' || ") }})
{% endmacro %}
```

Usage:
```sql
SELECT
    {{ generate_surrogate_key(['customer_id']) }} AS customer_key,
    {{ generate_surrogate_key(['order_id', 'product_id']) }} AS order_item_key
FROM ...
```

### Schema Generation Macro

```sql
-- macros/generate_schema_name.sql
-- Override default schema naming behavior

{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- set default_schema = target.schema -%}
    
    {%- if target.name == 'prod' -%}
        {# In prod, use schema name directly without prefix #}
        {%- if custom_schema_name is none -%}
            {{ default_schema }}
        {%- else -%}
            {{ custom_schema_name | trim }}
        {%- endif -%}
    {%- else -%}
        {# In dev/staging, prefix with target schema #}
        {%- if custom_schema_name is none -%}
            {{ default_schema }}
        {%- else -%}
            {{ default_schema }}_{{ custom_schema_name | trim }}
        {%- endif -%}
    {%- endif -%}
{%- endmacro %}
```

> **💡 TIP: Schema Naming in Different Environments**
> 
> | Target | Model Schema | Output Schema |
> |--------|-------------|---------------|
> | dev | staging | DEV_USER_staging |
> | staging | staging | STAGING_staging |
> | prod | staging | staging |

### Run-Operation Macros

Macros that can be called directly via `run-operation`:

```sql
-- macros/operations/grant_permissions.sql
{% macro grant_select_on_marts(role_name) %}
    {% set schemas = ['staging', 'silver', 'gold'] %}
    
    {% for schema in schemas %}
        {% set grant_usage %}
            GRANT USAGE ON SCHEMA {{ target.database }}.{{ schema }} TO ROLE {{ role_name }};
        {% endset %}
        
        {% set grant_select %}
            GRANT SELECT ON ALL TABLES IN SCHEMA {{ target.database }}.{{ schema }} TO ROLE {{ role_name }};
        {% endset %}
        
        {% set grant_future %}
            GRANT SELECT ON FUTURE TABLES IN SCHEMA {{ target.database }}.{{ schema }} TO ROLE {{ role_name }};
        {% endset %}
        
        {% do run_query(grant_usage) %}
        {% do run_query(grant_select) %}
        {% do run_query(grant_future) %}
        
        {{ log("Granted permissions on " ~ schema ~ " to " ~ role_name, info=True) }}
    {% endfor %}
{% endmacro %}
```

```sql
-- macros/operations/cleanup_old_tables.sql
{% macro cleanup_old_tables(schema_name, days_old=30) %}
    {% set query %}
        SELECT table_name 
        FROM information_schema.tables 
        WHERE table_schema = '{{ schema_name | upper }}'
          AND table_type = 'BASE TABLE'
          AND created < DATEADD('day', -{{ days_old }}, CURRENT_TIMESTAMP())
    {% endset %}
    
    {% set results = run_query(query) %}
    
    {% if results %}
        {% for row in results %}
            {% set drop_stmt %}
                DROP TABLE IF EXISTS {{ schema_name }}.{{ row['TABLE_NAME'] }};
            {% endset %}
            
            {{ log("Dropping: " ~ row['TABLE_NAME'], info=True) }}
            {% do run_query(drop_stmt) %}
        {% endfor %}
    {% endif %}
{% endmacro %}
```

Execute with:
```bash
# SQL command
EXECUTE DBT PROJECT my_proj ARGS='run-operation grant_select_on_marts --args "{role_name: ANALYST_ROLE}"';

# CLI command
snow dbt execute my_project "run-operation grant_select_on_marts" \
    --args '{"role_name": "ANALYST_ROLE"}' \
    --database COURSE_DB --schema DBT_PROJECTS
```

> **💡 TIP: Macro Best Practices**
> 
> - **One macro per file**: Easier to find and maintain
> - **Use default arguments**: `{% macro my_macro(arg1, arg2='default') %}`
> - **Add documentation**: Comment what the macro does
> - **Test macros**: Use `compile` to see generated SQL
> - **Organize by purpose**: `macros/utilities/`, `macros/tests/`, `macros/operations/`

> **⚠️ WARNING: Macro Pitfalls**
> 
> - **Jinja whitespace**: Use `{%-` and `-%}` to control whitespace
> - **SQL injection**: Never use raw user input in macros
> - **Recursion**: Macros can call other macros, but avoid infinite loops
> - **Compilation errors**: Jinja errors can be cryptic; use `dbt compile` to debug

> **📚 REFERENCE: Macros**
> - [dbt Jinja Documentation](https://docs.getdbt.com/docs/build/jinja-macros)
> - [Jinja Template Designer](https://jinja.palletsprojects.com/en/3.1.x/templates/)

---

## 2.7 dbt Core Commands Reference

### Complete Command Reference

| Command | Description | Example |
|---------|-------------|---------|
| `build` | Run models + tests + snapshots + seeds | Build everything in order |
| `compile` | Generate SQL without execution | Debug/review generated SQL |
| `deps` | Install packages from packages.yml | Required before first run |
| `list` (or `ls`) | List project resources | See what's in the project |
| `run` | Execute models | Build tables/views |
| `run-operation` | Execute a macro | Run maintenance tasks |
| `seed` | Load CSV files as tables | Load reference data |
| `show` | Preview query results | Quick data check |
| `snapshot` | Execute SCD Type 2 snapshots | Track historical changes |
| `test` | Run data quality tests | Validate data |
| `source freshness` | Check source data freshness | Verify data is current |
| `docs generate` | Generate documentation | Create docs site |
| `clean` | Remove compiled files | Clean target/ folder |

### SQL Command Syntax

```sql
-- Basic execution
EXECUTE DBT PROJECT my_project ARGS='build';

-- With warehouse specification
EXECUTE DBT PROJECT course_db.dbt_projects.my_project
    WAREHOUSE = 'DBT_WH'
    ARGS = 'build';

-- Specific version
EXECUTE DBT PROJECT my_project
    VERSION = 'version$3'
    ARGS = 'run';

-- With variables
EXECUTE DBT PROJECT my_project
    ARGS = 'run --vars "{start_date: 2024-01-01, end_date: 2024-12-31}"';
```

### Selection Examples

```sql
-- Run specific model
EXECUTE DBT PROJECT my_proj ARGS='run --select dim_customers';

-- Run all models in a folder
EXECUTE DBT PROJECT my_proj ARGS='run --select staging.*';

-- Run model and all downstream (children)
EXECUTE DBT PROJECT my_proj ARGS='run --select stg_customers+';

-- Run model and all upstream (parents)  
EXECUTE DBT PROJECT my_proj ARGS='run --select +fct_orders';

-- Run model with both directions (2 levels up, 1 level down)
EXECUTE DBT PROJECT my_proj ARGS='run --select 2+dim_customers+1';

-- Run by tag
EXECUTE DBT PROJECT my_proj ARGS='run --select tag:daily';

-- Run by materialization
EXECUTE DBT PROJECT my_proj ARGS='run --select config.materialized:table';

-- Exclude models
EXECUTE DBT PROJECT my_proj ARGS='run --exclude staging.*';

-- Combine (run marts except aggregates)
EXECUTE DBT PROJECT my_proj ARGS='run --select marts.* --exclude tag:aggregate';

-- Full refresh (rebuild incremental models from scratch)
EXECUTE DBT PROJECT my_proj ARGS='run --full-refresh';

-- Run only modified models (requires state)
EXECUTE DBT PROJECT my_proj ARGS='run --select state:modified';
```

> **💡 TIP: Selection Operator Quick Reference**
> 
> | Operator | Meaning | Example |
> |----------|---------|---------|
> | `+` (prefix) | Include upstream | `+model` |
> | `+` (suffix) | Include downstream | `model+` |
> | `n+` | n levels upstream | `2+model` |
> | `+n` | n levels downstream | `model+2` |
> | `*` | Wildcard | `staging.*` |
> | `,` | Intersection | `tag:a,tag:b` |
> | Space | Union | `model1 model2` |

### Snowflake CLI Examples

```bash
# Build everything
snow dbt execute my_project build \
    --database COURSE_DB --schema DBT_PROJECTS --warehouse DBT_WH

# Run specific models
snow dbt execute my_project run \
    --select "staging.* marts.*" \
    --database COURSE_DB --schema DBT_PROJECTS

# Test specific folder
snow dbt execute my_project test \
    --select "marts.*" \
    --database COURSE_DB --schema DBT_PROJECTS

# Compile and review SQL
snow dbt execute my_project compile \
    --database COURSE_DB --schema DBT_PROJECTS

# Load seeds
snow dbt execute my_project seed \
    --database COURSE_DB --schema DBT_PROJECTS

# Run snapshots
snow dbt execute my_project snapshot \
    --database COURSE_DB --schema DBT_PROJECTS

# Execute maintenance macro
snow dbt execute my_project "run-operation cleanup_old_tables" \
    --args '{"schema_name": "staging", "days_old": 30}' \
    --database COURSE_DB --schema DBT_PROJECTS

# List all resources
snow dbt execute my_project list \
    --database COURSE_DB --schema DBT_PROJECTS

# Show sample data from a model
snow dbt execute my_project "show --select dim_customers --limit 10" \
    --database COURSE_DB --schema DBT_PROJECTS
```

> **📚 REFERENCE: dbt Commands**
> - [dbt Command Reference](https://docs.getdbt.com/reference/dbt-commands)
> - [Node Selection Syntax](https://docs.getdbt.com/reference/node-selection/syntax)

---

## 2.8 Seeds

Seeds are CSV files that dbt loads as tables. Use them for small, static reference data.

### Example Seed Files

```csv
# seeds/country_codes.csv
country_code,country_name,region,currency
USA,United States,North America,USD
CAN,Canada,North America,CAD
MEX,Mexico,North America,MXN
GBR,United Kingdom,Europe,GBP
DEU,Germany,Europe,EUR
FRA,France,Europe,EUR
JPN,Japan,Asia Pacific,JPY
AUS,Australia,Asia Pacific,AUD
```

```csv
# seeds/order_statuses.csv
status_code,status_name,is_terminal,sort_order
PENDING,Pending,false,1
PROCESSING,Processing,false,2
SHIPPED,Shipped,false,3
DELIVERED,Delivered,true,4
COMPLETED,Completed,true,5
CANCELLED,Cancelled,true,6
REFUNDED,Refunded,true,7
```

### Seed Configuration

```yaml
# dbt_project.yml
seeds:
  course_dbt_project:
    +schema: reference              # All seeds go to reference schema
    +quote_columns: false           # Don't quote column names
    
    # Specific seed configuration
    country_codes:
      +column_types:
        country_code: VARCHAR(3)
        country_name: VARCHAR(100)
        region: VARCHAR(50)
        currency: VARCHAR(3)
        
    order_statuses:
      +column_types:
        status_code: VARCHAR(20)
        status_name: VARCHAR(50)
        is_terminal: BOOLEAN
        sort_order: INTEGER
```

```yaml
# seeds/_seeds.yml (documentation)
version: 2

seeds:
  - name: country_codes
    description: "ISO country codes and regional mapping"
    columns:
      - name: country_code
        description: "ISO 3166-1 alpha-3 country code"
        tests:
          - unique
          - not_null
          
  - name: order_statuses
    description: "Valid order status codes"
    columns:
      - name: status_code
        tests:
          - unique
          - not_null
```

### Using Seeds in Models

```sql
-- Reference seeds with ref() just like models
SELECT
    o.order_id,
    o.status,
    s.status_name,
    s.is_terminal
FROM {{ ref('stg_orders') }} o
LEFT JOIN {{ ref('order_statuses') }} s ON o.status = s.status_code
```

> **💡 TIP: When to Use Seeds**
> 
> **Good use cases:**
> - Country/currency/region mappings
> - Status code lookups
> - Category hierarchies
> - Test fixture data
> - Configuration tables (<1000 rows)
> 
> **Bad use cases:**
> - Large datasets (>10k rows)
> - Frequently changing data
> - Transactional data
> - Data with PII

> **⚠️ WARNING: Seed Limitations**
> 
> - Seeds are fully replaced on each run (no incremental)
> - Large CSVs slow down `dbt build`
> - CSV parsing can be finicky with special characters
> - Consider using external tables for large reference data

> **📚 REFERENCE: Seeds**
> - [dbt Seeds Documentation](https://docs.getdbt.com/docs/build/seeds)

---

## 2.9 Snapshots (SCD Type 2)

Snapshots capture historical changes to your data over time using Slowly Changing Dimension Type 2 methodology.

### Snapshot Strategies

| Strategy | Use When | Required Column |
|----------|----------|-----------------|
| `timestamp` | Source has reliable updated_at | `updated_at` column |
| `check` | No timestamp, check specific columns | None (checks all) |

### Timestamp Strategy

```sql
-- snapshots/snap_customers.sql
{% snapshot snap_customers %}

{{
    config(
        target_database='COURSE_DB',
        target_schema='SNAPSHOTS',
        unique_key='customer_id',
        strategy='timestamp',
        updated_at='updated_at',
        invalidate_hard_deletes=True    -- Track deletions
    )
}}

SELECT
    customer_id,
    first_name,
    last_name,
    email,
    status,
    country_code,
    updated_at
FROM {{ source('raw', 'customers') }}

{% endsnapshot %}
```

### Check Strategy

```sql
-- snapshots/snap_products.sql
{% snapshot snap_products %}

{{
    config(
        target_database='COURSE_DB',
        target_schema='SNAPSHOTS',
        unique_key='product_id',
        strategy='check',
        check_cols=['product_name', 'unit_price', 'is_active']  -- Columns to monitor
    )
}}

SELECT
    product_id,
    product_name,
    category,
    unit_price,
    is_active
FROM {{ source('raw', 'products') }}

{% endsnapshot %}
```

### Snapshot Output

Snapshots add these columns automatically:

| Column | Description |
|--------|-------------|
| `dbt_scd_id` | Unique key for each version |
| `dbt_updated_at` | When this version was captured |
| `dbt_valid_from` | When this version became active |
| `dbt_valid_to` | When this version was superseded (NULL if current) |

### Querying Snapshots

```sql
-- Get current records
SELECT * FROM course_db.snapshots.snap_customers
WHERE dbt_valid_to IS NULL;

-- Get record as of a specific date
SELECT * FROM course_db.snapshots.snap_customers
WHERE '2024-02-15' BETWEEN dbt_valid_from AND COALESCE(dbt_valid_to, '9999-12-31');

-- Get full history for a customer
SELECT * FROM course_db.snapshots.snap_customers
WHERE customer_id = 123
ORDER BY dbt_valid_from;

-- Find changed records
SELECT * FROM course_db.snapshots.snap_customers
WHERE dbt_valid_to IS NOT NULL
ORDER BY dbt_updated_at DESC;
```

> **💡 TIP: Snapshot Best Practices**
> 
> - **Run daily**: Snapshots should run at least daily
> - **Use timestamp strategy**: More efficient than check
> - **Include only needed columns**: Reduce storage costs
> - **Monitor growth**: Snapshot tables can grow large
> - **Separate schema**: Use dedicated snapshots schema

> **⚠️ WARNING: Snapshot Gotchas**
> 
> - **First run**: Inserts all records as current (no history yet)
> - **Deleted records**: Only tracked with `invalidate_hard_deletes=True`
> - **Schema changes**: Adding columns requires manual intervention
> - **Large tables**: Initial snapshot can be slow

> **📚 REFERENCE: Snapshots**
> - [dbt Snapshots Documentation](https://docs.getdbt.com/docs/build/snapshots)
> - [SCD Type 2 Explained](https://www.kimballgroup.com/data-warehouse-business-intelligence-resources/kimball-techniques/dimensional-modeling-techniques/type-2/)

---

## Summary

| Topic | Key Takeaway |
|-------|--------------|
| **Workspaces** | Git-connected IDE in Snowsight for dbt development |
| **DAG** | Visual representation of model dependencies; use selection operators |
| **Sources** | Define raw tables in sources.yml with freshness and tests |
| **Models** | SQL transformations organized in staging→intermediate→marts layers |
| **Tests** | Built-in (unique, not_null) and custom tests for data quality |
| **Macros** | Reusable Jinja SQL functions; use for DRY code |
| **Commands** | build, run, test, compile, seed, snapshot, run-operation, list |
| **Seeds** | CSV files for small static reference data |
| **Snapshots** | SCD Type 2 history tracking with timestamp or check strategy |

### Development Workflow

```
1. Define sources (sources.yml)
        ↓
2. Create staging models (stg_*.sql)
        ↓
3. Add tests to sources and staging
        ↓
4. Create intermediate models (int_*.sql)
        ↓
5. Create mart models (dim_*, fct_*, agg_*)
        ↓
6. Add comprehensive tests to marts
        ↓
7. Document everything (_*.yml files)
        ↓
8. Run build to validate
        ↓
9. Deploy to production
```

---

## Quick Reference Card

### Model Materializations
| Type | Use Case | Storage |
|------|----------|---------|
| view | Staging, light transforms | None |
| table | Marts, heavy queries | Full |
| incremental | Large tables, append | Delta |
| ephemeral | CTEs, no persistence | None |

### Essential Tests
```yaml
tests:
  - unique           # No duplicates
  - not_null         # No NULLs
  - accepted_values  # Valid values only
  - relationships    # FK integrity
```

### Key Commands
```bash
snow dbt execute PROJECT build    # Run everything
snow dbt execute PROJECT run      # Run models only
snow dbt execute PROJECT test     # Run tests only
snow dbt execute PROJECT compile  # Check SQL generation
```

---

## Additional Resources

### Official Documentation
- [dbt Core Documentation](https://docs.getdbt.com/docs/introduction)
- [Snowflake dbt Adapter](https://docs.getdbt.com/reference/resource-configs/snowflake-configs)
- [dbt Best Practices](https://docs.getdbt.com/guides/best-practices)

### Packages
- [dbt Hub](https://hub.getdbt.com/) - Package registry
- [dbt-utils](https://github.com/dbt-labs/dbt-utils) - Essential utilities
- [dbt-expectations](https://github.com/calogica/dbt-expectations) - Data testing

### Community
- [dbt Discourse](https://discourse.getdbt.com/)
- [dbt Slack](https://getdbt.com/community)

---

## Next Section

In [Section 3: Transformation & Deployment](03-transformation-deployment.md), you'll learn:
- Deploying dbt projects to Snowflake (CREATE DBT PROJECT)
- Using ALTER/EXECUTE/SHOW DBT PROJECT commands
- Scheduling with Snowflake Tasks
- Version management and rollback strategies
- CI/CD integration patterns
