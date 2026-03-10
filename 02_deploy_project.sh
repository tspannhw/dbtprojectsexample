#!/bin/bash
# ==============================================================================
# dbt Projects on Snowflake - Deployment Script
# ==============================================================================
# This script deploys the dbt project to Snowflake using the Snowflake CLI
# ==============================================================================

set -e

# Configuration - modify as needed
PROJECT_NAME="course_dbt_project"
DATABASE="COURSE_DB"
SCHEMA="DBT_PROJECTS"
CONNECTION="${SNOWFLAKE_CONNECTION_NAME:-default}"
SOURCE_DIR="$(dirname "$0")/../dbt_project"

echo "=============================================="
echo "dbt Project Deployment"
echo "=============================================="
echo "Project:    ${PROJECT_NAME}"
echo "Database:   ${DATABASE}"
echo "Schema:     ${SCHEMA}"
echo "Connection: ${CONNECTION}"
echo "Source:     ${SOURCE_DIR}"
echo ""

# Check if Snowflake CLI is installed
if ! command -v snow &> /dev/null; then
    echo "ERROR: Snowflake CLI (snow) is not installed."
    echo "Install with: pip install snowflake-cli-labs"
    exit 1
fi

# Step 1: Deploy the dbt project
echo "[1/5] Deploying dbt project..."
snow dbt deploy ${PROJECT_NAME} \
    -c ${CONNECTION} \
    --source "${SOURCE_DIR}" \
    --database ${DATABASE} \
    --schema ${SCHEMA} \
    --force

echo ""
echo "[2/5] Loading seed data..."
snow dbt execute ${PROJECT_NAME} seed \
    -c ${CONNECTION} \
    --database ${DATABASE} \
    --schema ${SCHEMA}

echo ""
echo "[3/5] Building all models..."
snow dbt execute ${PROJECT_NAME} build \
    -c ${CONNECTION} \
    --database ${DATABASE} \
    --schema ${SCHEMA}

echo ""
echo "[4/5] Running tests..."
snow dbt execute ${PROJECT_NAME} test \
    -c ${CONNECTION} \
    --database ${DATABASE} \
    --schema ${SCHEMA}

echo ""
echo "[5/5] Listing deployed project..."
snow dbt list \
    -c ${CONNECTION} \
    --database ${DATABASE}

echo ""
echo "=============================================="
echo "Deployment Complete!"
echo "=============================================="
echo ""
echo "Next steps:"
echo "  1. View project in Snowsight: Transformation → dbt Projects"
echo "  2. Schedule with: snow sql -f scripts/03_schedule_tasks.sql"
echo "  3. Monitor with: streamlit run streamlit/dbt_monitor_dashboard.py"
echo ""
