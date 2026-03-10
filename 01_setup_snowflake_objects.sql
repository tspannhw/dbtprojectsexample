-- ==============================================================================
-- dbt Projects on Snowflake - Initial Setup Script
-- ==============================================================================
-- Run this script to create all necessary Snowflake objects for the course
-- ==============================================================================

-- Use ACCOUNTADMIN or a role with sufficient privileges
USE ROLE ACCOUNTADMIN;

-- ==============================================================================
-- SECTION 1: Create Database and Schemas
-- ==============================================================================

-- Create main database
CREATE DATABASE IF NOT EXISTS COURSE_DB;

-- Create schemas for different layers
CREATE SCHEMA IF NOT EXISTS COURSE_DB.DBT_PROJECTS;   -- dbt project objects
CREATE SCHEMA IF NOT EXISTS COURSE_DB.RAW;            -- Raw source data (Bronze)
CREATE SCHEMA IF NOT EXISTS COURSE_DB.STAGING;        -- Staging views (Bronze)
CREATE SCHEMA IF NOT EXISTS COURSE_DB.SILVER;         -- Intermediate tables (Silver)
CREATE SCHEMA IF NOT EXISTS COURSE_DB.GOLD;           -- Mart tables (Gold)
CREATE SCHEMA IF NOT EXISTS COURSE_DB.SNAPSHOTS;      -- SCD Type 2 snapshots
CREATE SCHEMA IF NOT EXISTS COURSE_DB.REFERENCE;      -- Seed/reference data
CREATE SCHEMA IF NOT EXISTS COURSE_DB.INTEGRATIONS;   -- Git repos, stages

-- ==============================================================================
-- SECTION 2: Create Warehouse
-- ==============================================================================

CREATE WAREHOUSE IF NOT EXISTS DBT_WH
    WITH 
    WAREHOUSE_SIZE = 'XSMALL'
    AUTO_SUSPEND = 60
    AUTO_RESUME = TRUE
    INITIALLY_SUSPENDED = FALSE
    COMMENT = 'Warehouse for dbt project executions';

-- ==============================================================================
-- SECTION 3: Enable Monitoring on Schema
-- ==============================================================================

ALTER SCHEMA COURSE_DB.DBT_PROJECTS SET LOG_LEVEL = 'INFO';
ALTER SCHEMA COURSE_DB.DBT_PROJECTS SET TRACE_LEVEL = 'ALWAYS';
ALTER SCHEMA COURSE_DB.DBT_PROJECTS SET METRIC_LEVEL = 'ALL';

-- ==============================================================================
-- SECTION 4: Create Sample Source Tables
-- ==============================================================================

USE SCHEMA COURSE_DB.RAW;

-- Customers table
CREATE OR REPLACE TABLE COURSE_DB.RAW.CUSTOMERS (
    customer_id INTEGER PRIMARY KEY,
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    email VARCHAR(200),
    created_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP(),
    updated_at TIMESTAMP_NTZ DEFAULT CURRENT_TIMESTAMP()
);

-- Products table
CREATE OR REPLACE TABLE COURSE_DB.RAW.PRODUCTS (
    product_id INTEGER PRIMARY KEY,
    product_name VARCHAR(200),
    category VARCHAR(100),
    price DECIMAL(10,2)
);

-- Orders table
CREATE OR REPLACE TABLE COURSE_DB.RAW.ORDERS (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER,
    order_date DATE,
    status VARCHAR(50),
    total_amount DECIMAL(10,2)
);

-- Order Items table
CREATE OR REPLACE TABLE COURSE_DB.RAW.ORDER_ITEMS (
    order_item_id INTEGER PRIMARY KEY,
    order_id INTEGER,
    product_id INTEGER,
    quantity INTEGER,
    unit_price DECIMAL(10,2)
);

-- ==============================================================================
-- SECTION 5: Insert Sample Data
-- ==============================================================================

-- Insert customers
INSERT INTO COURSE_DB.RAW.CUSTOMERS (customer_id, first_name, last_name, email, created_at, updated_at) VALUES
    (1, 'John', 'Doe', 'john.doe@email.com', '2024-01-15 10:30:00', '2024-01-15 10:30:00'),
    (2, 'Jane', 'Smith', 'jane.smith@email.com', '2024-01-16 14:20:00', '2024-02-01 09:15:00'),
    (3, 'Bob', 'Wilson', 'bob.wilson@email.com', '2024-02-01 08:45:00', '2024-02-01 08:45:00'),
    (4, 'Alice', 'Brown', 'alice.brown@email.com', '2024-02-10 11:00:00', '2024-02-10 11:00:00'),
    (5, 'Charlie', 'Davis', 'charlie.davis@email.com', '2024-02-15 16:30:00', '2024-03-01 10:00:00'),
    (6, 'Diana', 'Martinez', 'diana.martinez@email.com', '2024-03-01 09:00:00', '2024-03-01 09:00:00'),
    (7, 'Edward', 'Garcia', 'edward.garcia@email.com', '2024-03-05 14:00:00', '2024-03-05 14:00:00'),
    (8, 'Fiona', 'Lee', 'fiona.lee@email.com', '2024-03-10 10:30:00', '2024-03-10 10:30:00');

-- Insert products
INSERT INTO COURSE_DB.RAW.PRODUCTS (product_id, product_name, category, price) VALUES
    (101, 'Laptop Pro 15', 'Electronics', 1299.99),
    (102, 'Wireless Mouse', 'Electronics', 29.99),
    (103, 'USB-C Hub', 'Accessories', 49.99),
    (104, 'Mechanical Keyboard', 'Electronics', 149.99),
    (105, 'Monitor Stand', 'Furniture', 79.99),
    (106, 'Webcam HD', 'Electronics', 89.99),
    (107, 'Desk Lamp', 'Furniture', 39.99),
    (108, 'Headphones Pro', 'Electronics', 249.99),
    (109, 'Phone Charger', 'Accessories', 19.99),
    (110, 'Tablet Case', 'Accessories', 34.99);

-- Insert orders
INSERT INTO COURSE_DB.RAW.ORDERS (order_id, customer_id, order_date, status, total_amount) VALUES
    (1001, 1, '2024-01-20', 'COMPLETED', 1349.98),
    (1002, 1, '2024-02-05', 'COMPLETED', 89.98),
    (1003, 2, '2024-02-10', 'PENDING', 249.99),
    (1004, 3, '2024-02-15', 'COMPLETED', 79.99),
    (1005, 2, '2024-02-20', 'COMPLETED', 1499.97),
    (1006, 4, '2024-02-25', 'CANCELLED', 149.99),
    (1007, 5, '2024-03-01', 'COMPLETED', 339.97),
    (1008, 3, '2024-03-05', 'PROCESSING', 279.98),
    (1009, 6, '2024-03-08', 'COMPLETED', 69.98),
    (1010, 1, '2024-03-10', 'COMPLETED', 179.98),
    (1011, 7, '2024-03-12', 'PENDING', 1299.99),
    (1012, 8, '2024-03-15', 'COMPLETED', 119.98);

-- Insert order items
INSERT INTO COURSE_DB.RAW.ORDER_ITEMS (order_item_id, order_id, product_id, quantity, unit_price) VALUES
    (10001, 1001, 101, 1, 1299.99),
    (10002, 1001, 102, 1, 29.99),
    (10003, 1001, 109, 1, 19.99),
    (10004, 1002, 102, 2, 29.99),
    (10005, 1002, 109, 1, 19.99),
    (10006, 1003, 108, 1, 249.99),
    (10007, 1004, 105, 1, 79.99),
    (10008, 1005, 101, 1, 1299.99),
    (10009, 1005, 103, 2, 49.99),
    (10010, 1005, 102, 1, 29.99),
    (10011, 1006, 104, 1, 149.99),
    (10012, 1007, 108, 1, 249.99),
    (10013, 1007, 106, 1, 89.99),
    (10014, 1008, 104, 1, 149.99),
    (10015, 1008, 103, 2, 49.99),
    (10016, 1009, 107, 1, 39.99),
    (10017, 1009, 102, 1, 29.99),
    (10018, 1010, 104, 1, 149.99),
    (10019, 1010, 102, 1, 29.99),
    (10020, 1011, 101, 1, 1299.99),
    (10021, 1012, 106, 1, 89.99),
    (10022, 1012, 102, 1, 29.99);

-- ==============================================================================
-- SECTION 6: Create Role for dbt Operations (Optional)
-- ==============================================================================

CREATE ROLE IF NOT EXISTS DBT_DEVELOPER_ROLE;

-- Grant database privileges
GRANT USAGE ON DATABASE COURSE_DB TO ROLE DBT_DEVELOPER_ROLE;
GRANT CREATE SCHEMA ON DATABASE COURSE_DB TO ROLE DBT_DEVELOPER_ROLE;

-- Grant schema privileges
GRANT ALL ON ALL SCHEMAS IN DATABASE COURSE_DB TO ROLE DBT_DEVELOPER_ROLE;
GRANT ALL ON FUTURE SCHEMAS IN DATABASE COURSE_DB TO ROLE DBT_DEVELOPER_ROLE;

-- Grant table privileges
GRANT ALL ON ALL TABLES IN DATABASE COURSE_DB TO ROLE DBT_DEVELOPER_ROLE;
GRANT ALL ON FUTURE TABLES IN DATABASE COURSE_DB TO ROLE DBT_DEVELOPER_ROLE;

-- Grant view privileges
GRANT ALL ON ALL VIEWS IN DATABASE COURSE_DB TO ROLE DBT_DEVELOPER_ROLE;
GRANT ALL ON FUTURE VIEWS IN DATABASE COURSE_DB TO ROLE DBT_DEVELOPER_ROLE;

-- Grant warehouse privileges
GRANT USAGE, OPERATE ON WAREHOUSE DBT_WH TO ROLE DBT_DEVELOPER_ROLE;

-- Grant dbt project creation privilege
GRANT CREATE DBT PROJECT ON SCHEMA COURSE_DB.DBT_PROJECTS TO ROLE DBT_DEVELOPER_ROLE;

-- Grant role to current user (uncomment and modify as needed)
-- GRANT ROLE DBT_DEVELOPER_ROLE TO USER your_username;

-- ==============================================================================
-- SECTION 7: Verify Setup
-- ==============================================================================

-- Check schemas created
SHOW SCHEMAS IN DATABASE COURSE_DB;

-- Check tables created
SHOW TABLES IN SCHEMA COURSE_DB.RAW;

-- Check row counts
SELECT 'CUSTOMERS' AS table_name, COUNT(*) AS row_count FROM COURSE_DB.RAW.CUSTOMERS
UNION ALL
SELECT 'PRODUCTS', COUNT(*) FROM COURSE_DB.RAW.PRODUCTS
UNION ALL
SELECT 'ORDERS', COUNT(*) FROM COURSE_DB.RAW.ORDERS
UNION ALL
SELECT 'ORDER_ITEMS', COUNT(*) FROM COURSE_DB.RAW.ORDER_ITEMS;

-- ==============================================================================
-- Setup Complete!
-- ==============================================================================

SELECT 'Setup completed successfully! You can now deploy the dbt project.' AS status;
