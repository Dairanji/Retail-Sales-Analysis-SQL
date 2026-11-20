-- ============================================================
-- Retail Sales Analysis (MySQL)
--
-- Raw tables (never modified):
--   sales_transaction, product_inventory, customer_profiles
-- Cleaned layer:
--   sales_transaction_clean   (table: duplicates removed, prices fixed)
--   vw_customer_profiles      (view: missing locations filled)
--   vw_sales_transaction      (view: adds a real DATE column)
-- Analysis layer (views reused by several queries):
--   vw_product_sales, vw_customer_summary, vw_customer_segment
--
-- Run 01_setup_database.sql first, then run this file top to bottom.
-- There are no DROP statements, so it is safe to run again.
-- ============================================================

USE retail_analysis;

-- MySQL Workbench safe-update mode blocks UPDATEs that have no key
-- in the WHERE clause (error 1175), so turn it off for this session.
SET SQL_SAFE_UPDATES = 0;


-- ============================================================
-- PART 1: DATA CLEANING
-- ============================================================

-- 1. Remove Duplicates
-- Duplicated transactions in the raw table
SELECT TransactionID, COUNT(*) AS Occurrences
FROM sales_transaction
GROUP BY TransactionID
HAVING COUNT(*) > 1;

-- Cleaned copy with unique rows only (raw table stays as it is)
CREATE TABLE IF NOT EXISTS sales_transaction_clean AS
SELECT DISTINCT *
FROM sales_transaction;

-- Check: row counts before and after
SELECT
    (SELECT COUNT(*) FROM sales_transaction)       AS raw_rows,
    (SELECT COUNT(*) FROM sales_transaction_clean) AS clean_rows;


-- 2. Fix Incorrect Prices
-- Transactions whose price differs from the inventory price
SELECT
    st.TransactionID,
    st.Price AS TransactionPrice,
    p.Price  AS InventoryPrice
FROM sales_transaction_clean st
JOIN product_inventory p ON st.ProductID = p.ProductID
WHERE st.Price <> p.Price;

-- Correct them in the cleaned table
UPDATE sales_transaction_clean st
JOIN product_inventory p ON st.ProductID = p.ProductID
SET st.Price = p.Price
WHERE st.Price <> p.Price;

-- Check: no mismatches remain
SELECT COUNT(*) AS remaining_mismatches
FROM sales_transaction_clean st
JOIN product_inventory p ON st.ProductID = p.ProductID
WHERE st.Price <> p.Price;


-- 3. Fixing Null Values
-- Missing locations in the raw table
SELECT COUNT(*) AS null_locations
FROM customer_profiles
WHERE Location IS NULL;

-- View that shows 'Unknown' instead of NULL
CREATE OR REPLACE VIEW vw_customer_profiles AS
SELECT
    CustomerID,
    Age,
    Gender,
    COALESCE(Location, 'Unknown') AS Location,
    JoinDate
FROM customer_profiles;

-- Check: the rows that were filled in
SELECT *
FROM vw_customer_profiles
WHERE Location = 'Unknown';


-- 4. Cleaning Date
-- View with a real DATE column next to the text TransactionDate
CREATE OR REPLACE VIEW vw_sales_transaction AS
SELECT
    *,
    CAST(TransactionDate AS DATE) AS TransactionDate_updated
FROM sales_transaction_clean;

SELECT * FROM vw_sales_transaction;


-- ============================================================
-- PART 2: SALES ANALYSIS
-- ============================================================

-- 5. Total Sales Summary
-- Reusable product-level totals (also used by queries 8 and 9)
CREATE OR REPLACE VIEW vw_product_sales AS
SELECT
    ProductID,
    SUM(QuantityPurchased)         AS TotalUnitsSold,
    SUM(QuantityPurchased * Price) AS TotalSales
FROM vw_sales_transaction
GROUP BY ProductID;

SELECT ProductID, TotalUnitsSold, TotalSales
FROM vw_product_sales
ORDER BY TotalSales DESC;


-- 6. Customer Purchase Frequency
-- Reusable customer-level totals (also used by queries 12 and 13)
CREATE OR REPLACE VIEW vw_customer_summary AS
SELECT
    CustomerID,
    COUNT(TransactionID)           AS NumberOfTransactions,
    SUM(QuantityPurchased * Price) AS TotalSpent
FROM vw_sales_transaction
GROUP BY CustomerID;

SELECT CustomerID, NumberOfTransactions
FROM vw_customer_summary
ORDER BY NumberOfTransactions DESC, CustomerID ASC;


-- 7. Product Categories Performance
SELECT
    p.Category,
    SUM(st.QuantityPurchased)            AS TotalUnitsSold,
    SUM(st.QuantityPurchased * st.Price) AS TotalSales
FROM vw_sales_transaction st
JOIN product_inventory p ON st.ProductID = p.ProductID
GROUP BY p.Category
ORDER BY TotalSales DESC;


-- 8. High Sales Products (top 10 by revenue)
SELECT ProductID, TotalSales AS TotalRevenue
FROM vw_product_sales
ORDER BY TotalRevenue DESC
LIMIT 10;


-- 9. Low Sales Products (bottom 10 by units sold)
SELECT ProductID, TotalUnitsSold
FROM vw_product_sales
WHERE TotalUnitsSold >= 1
ORDER BY TotalUnitsSold ASC, ProductID ASC
LIMIT 10;


-- 10. Sales Trend (daily)
SELECT
    DATE_FORMAT(TransactionDate_updated, '%Y-%m-%d') AS DATETRANS,
    COUNT(TransactionID)                             AS Transaction_count,
    SUM(QuantityPurchased)                           AS TotalUnitsSold,
    ROUND(SUM(Price * QuantityPurchased), 2)         AS TotalSales
FROM vw_sales_transaction
GROUP BY DATE_FORMAT(TransactionDate_updated, '%Y-%m-%d')
ORDER BY DATETRANS DESC;


-- 11. Growth Rate of Sales (month over month)
WITH monthly_sales AS (
    SELECT
        MONTH(TransactionDate_updated) AS month,
        ROUND(SUM(QuantityPurchased * Price), 2) AS total_sales
    FROM vw_sales_transaction
    GROUP BY MONTH(TransactionDate_updated)
)
SELECT
    month,
    total_sales,
    LAG(total_sales) OVER (ORDER BY month) AS previous_month_sales,
    ROUND(
        (total_sales - LAG(total_sales) OVER (ORDER BY month))
        / LAG(total_sales) OVER (ORDER BY month) * 100, 2
    ) AS mom_growth_percentage
FROM monthly_sales
ORDER BY month;


-- ============================================================
-- PART 3: CUSTOMER ANALYSIS
-- ============================================================

-- 12. High Purchase Frequency (more than 10 transactions and over 1000 spent)
SELECT CustomerID, NumberOfTransactions, TotalSpent
FROM vw_customer_summary
WHERE NumberOfTransactions > 10
  AND TotalSpent > 1000
ORDER BY TotalSpent DESC, CustomerID ASC;


-- 13. Occasional Customers (2 transactions or fewer)
SELECT CustomerID, NumberOfTransactions, TotalSpent
FROM vw_customer_summary
WHERE NumberOfTransactions <= 2
ORDER BY NumberOfTransactions ASC, TotalSpent DESC, CustomerID ASC;


-- 14. Repeat Purchases (same customer buying the same product again)
SELECT
    CustomerID,
    ProductID,
    COUNT(QuantityPurchased) AS TimesPurchased
FROM vw_sales_transaction
GROUP BY CustomerID, ProductID
HAVING COUNT(QuantityPurchased) > 1
ORDER BY TimesPurchased DESC, CustomerID ASC, ProductID ASC;


-- 15. Loyalty Indicators (days between first and last purchase)
SELECT
    CustomerID,
    MIN(TransactionDate_updated) AS FirstPurchase,
    MAX(TransactionDate_updated) AS LastPurchase,
    DATEDIFF(MAX(TransactionDate_updated), MIN(TransactionDate_updated)) AS DaysBetweenPurchases
FROM vw_sales_transaction
GROUP BY CustomerID
HAVING DATEDIFF(MAX(TransactionDate_updated), MIN(TransactionDate_updated)) > 0
ORDER BY DaysBetweenPurchases DESC, CustomerID ASC;


-- 16. Customer Segmentation (Low: 1-10, Med: 11-30, High: >30 units)
CREATE OR REPLACE VIEW vw_customer_segment AS
SELECT
    c.CustomerID,
    SUM(s.QuantityPurchased) AS TotalQuantity,
    CASE
        WHEN SUM(s.QuantityPurchased) BETWEEN 1 AND 10 THEN 'Low'
        WHEN SUM(s.QuantityPurchased) BETWEEN 11 AND 30 THEN 'Med'
        WHEN SUM(s.QuantityPurchased) > 30 THEN 'High'
    END AS CustomerSegment
FROM vw_customer_profiles c
JOIN vw_sales_transaction s ON c.CustomerID = s.CustomerID
GROUP BY c.CustomerID;

SELECT CustomerSegment, COUNT(*) AS NumberOfCustomers
FROM vw_customer_segment
GROUP BY CustomerSegment;
