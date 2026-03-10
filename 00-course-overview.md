# dbt Projects on Snowflake - Course Overview

## About This Course

This comprehensive 40-minute training course covers everything you need to know about building, deploying, and monitoring dbt Projects on Snowflake. The course is divided into four 10-minute sections, each focusing on a specific aspect of the dbt Projects workflow.

## Target Audience

- Data Engineers looking to leverage dbt within Snowflake
- Analytics Engineers familiar with SQL transformations
- Data Platform Teams evaluating dbt deployment options
- DevOps Engineers integrating dbt into CI/CD pipelines

## Prerequisites

- Basic SQL knowledge
- Snowflake account access
- Familiarity with data transformation concepts
- (Optional) Prior dbt experience

## Course Structure

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    dbt Projects on Snowflake Course                         │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│   Section 1: Introduction & Setup (10 min)                                  │
│   ├── What is dbt Projects on Snowflake?                                   │
│   ├── Architecture overview                                                 │
│   ├── Prerequisites & environment setup                                     │
│   ├── Project structure                                                     │
│   └── Configuration files                                                   │
│                                                                             │
│   Section 2: Development & Models (10 min)                                  │
│   ├── Workspaces & DAG visualization                                       │
│   ├── Sources definition                                                    │
│   ├── Model layers (staging, intermediate, marts)                          │
│   ├── Tests (built-in and custom)                                          │
│   ├── Macros                                                                │
│   └── All dbt Core commands                                                 │
│                                                                             │
│   Section 3: Transformation & Deployment (10 min)                          │
│   ├── CREATE/ALTER/DROP DBT PROJECT                                        │
│   ├── EXECUTE DBT PROJECT                                                   │
│   ├── Snowflake CLI (snow dbt)                                             │
│   ├── Task scheduling                                                       │
│   └── Version management                                                    │
│                                                                             │
│   Section 4: Monitoring & Best Practices (10 min)                          │
│   ├── Enable monitoring features                                            │
│   ├── Snowsight monitoring UI                                               │
│   ├── Programmatic log/artifact access                                      │
│   ├── Cost control strategies                                               │
│   └── Streamlit monitoring dashboard                                        │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## What You'll Build

Throughout this course, you'll work with a complete e-commerce data pipeline:

### Data Model

```
RAW LAYER (Bronze)                 STAGING (Views)
├── customers                      ├── stg_customers
├── products          ────────►    ├── stg_products
├── orders                         ├── stg_orders
└── order_items                    └── stg_order_items
                                            │
                                            ▼
                    INTERMEDIATE (Silver)
                    ├── int_customer_orders
                    └── int_order_details
                                            │
                                            ▼
                    MARTS (Gold)
                    ├── dim_customers
                    ├── dim_products
                    ├── fct_orders
                    ├── fct_order_items
                    └── agg_monthly_sales
```

## dbt Core Commands Covered

| Command | Description |
|---------|-------------|
| `build` | Run models + tests + snapshots + seeds |
| `compile` | Generate SQL without execution |
| `deps` | Install package dependencies |
| `list` | List project resources |
| `run` | Execute models |
| `run-operation` | Execute macros |
| `seed` | Load CSV seed files |
| `show` | Preview query results |
| `snapshot` | Execute SCD Type 2 snapshots |
| `test` | Run data quality tests |

## Key SQL Commands

```sql
-- Create dbt project
CREATE DBT PROJECT db.schema.project FROM 'source';

-- Execute dbt commands
EXECUTE DBT PROJECT db.schema.project ARGS='build';

-- Show all projects
SHOW DBT PROJECTS IN ACCOUNT;

-- Manage projects
ALTER DBT PROJECT project ADD VERSION FROM 'source';
DROP DBT PROJECT project;
```

## Hands-On Components

1. **dbt Project** - Complete project with models, tests, macros
2. **SQL Scripts** - Setup, deployment, scheduling, monitoring
3. **Bash Scripts** - Automated deployment workflow
4. **Streamlit Dashboard** - Real-time monitoring application

## Resources

### Official Documentation
- [dbt Projects on Snowflake](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake)
- [dbt Projects Developer Guide](https://www.snowflake.com/en/developers/guides/dbt-projects-on-snowflake/)
- [CI/CD Tutorial](https://docs.snowflake.com/en/user-guide/tutorials/dbt-projects-on-snowflake-ci-cd-tutorial)
- [Monitoring & Observability](https://docs.snowflake.com/en/user-guide/data-engineering/dbt-projects-on-snowflake-monitoring-observability)

### SQL Reference
- [CREATE DBT PROJECT](https://docs.snowflake.com/en/sql-reference/sql/create-dbt-project)
- [ALTER DBT PROJECT](https://docs.snowflake.com/en/sql-reference/sql/alter-dbt-project)
- [EXECUTE DBT PROJECT](https://docs.snowflake.com/en/sql-reference/sql/execute-dbt-project)
- [SHOW DBT PROJECTS](https://docs.snowflake.com/en/sql-reference/sql/show-dbt-projects)
- [DROP DBT PROJECT](https://docs.snowflake.com/en/sql-reference/sql/drop-dbt-project)

## Getting Started

1. Review [Section 1: Introduction & Setup](01-introduction-setup.md)
2. Run `scripts/01_setup_snowflake_objects.sql` to create Snowflake objects
3. Deploy the project with `scripts/02_deploy_project.sh`
4. Schedule with `scripts/03_schedule_tasks.sql`
5. Monitor with `streamlit run streamlit/dbt_monitor_dashboard.py`

---

*This course was built with Cortex Code - Snowflake's AI-powered development assistant*
