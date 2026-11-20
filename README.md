# Retail Sales Analysis (SQL)

## Problem

A retail company's transaction data contains duplicate rows, prices that don't match the inventory, missing customer locations and dates stored as text. Until that is fixed, sales reports can't be trusted, and the company has no clear view of which products, categories and customers drive revenue.

## Solution

Cleaned the data in a separate layer, so the raw tables are never modified, then used MySQL views to answer 16 business questions about products, categories and customers.

Based on the Coding Ninjas *Case Study: Retail Analytics*. The dataset from that case study is included in `01_setup_database.sql`.

## Key Findings

- **Home & Kitchen leads:** 217,755.94 in sales, 31.0% of the 702,003.62 total (12,325 units over 5,000 transactions).
- **Beauty & Health sells more units than Clothing but earns less:** 3,001 vs 2,810 units, 143,824.99 vs 162,874.21 in sales, because its units sell at a lower price (about 47.93 vs 57.96 each).
- **Sales are flat, not growing:** monthly sales stay between 96,690.99 and 104,289.18 from January to June. July's -10.99% drop is mostly a shorter period, as the data ends on 28 July (3,249.35 per day vs 3,364.17 in January).
- **Most customers are low-volume:** 423 Low, 559 Med and only 7 High. Just 18 customers made more than 10 purchases and spent over 1,000.
- **Best and worst sellers:** product 17 brings in the most (9,450.00 from 100 units), and product 142 sells the least (27 units).

## Data Quality Issues Found

- **2 duplicate transactions** (IDs 4999 and 5000): removed, 5,002 rows down to 5,000.
- **20 wrong prices, all for product 51:** recorded as 9,312.00 instead of 93.12 (100 times too high). Corrected from the inventory table.
- **13 customers with no location:** shown as `Unknown`.
- **Dates stored as text:** converted to a real `DATE` column.
- **Customer 668 has an age of 131:** an obvious outlier, left as is because no question depends on age.
- **11 of 1,000 customers have no purchases:** so they don't appear in the segmentation.

## Dataset

| Table | Rows | Columns |
|---|---|---|
| `sales_transaction` | 5,002 | TransactionID, CustomerID, ProductID, QuantityPurchased, TransactionDate, Price |
| `product_inventory` | 200 | ProductID, ProductName, Category, StockLevel, Price |
| `customer_profiles` | 1,000 | CustomerID, Age, Gender, Location, JoinDate |

## Structure

| Layer | Object | Purpose |
|---|---|---|
| Raw | `sales_transaction`, `product_inventory`, `customer_profiles` | Source tables, never modified |
| Clean | `sales_transaction_clean` (table) | Duplicates removed, prices corrected |
| Clean | `vw_customer_profiles` (view) | Missing locations shown as `Unknown` |
| Clean | `vw_sales_transaction` (view) | Adds `TransactionDate_updated` as a real `DATE` |
| Analysis | `vw_product_sales`, `vw_customer_summary`, `vw_customer_segment` (views) | Reused by several queries |

## How to run

Requires MySQL 8.0 or later.

1. Open [`01_setup_database.sql`](01_setup_database.sql) in MySQL Workbench and run it. It creates the `retail_analysis` database with the three tables.
2. Open [`02_retail_analysis.sql`](02_retail_analysis.sql) and run it. There are no `DROP` statements, so it can be run again safely. To start from scratch, run step 1 again.

---

## Part 1: Data Cleaning

### 1. Remove Duplicates
**Problem:** Some transactions appear more than once.
**Solution:** Counted repeated `TransactionID`s, then created `sales_transaction_clean` with `SELECT DISTINCT *` and compared row counts against the raw table.
**Result:** 2 duplicates found (IDs 4999 and 5000). Rows went from 5,002 to 5,000.

### 2. Fix Incorrect Prices
**Problem:** Transaction prices don't always match the inventory price for the same product.
**Solution:** Joined to the inventory to list the mismatches, corrected them in the clean table with `UPDATE ... JOIN`, then confirmed none remain.
**Result:** 20 mismatches, all product 51 (for example transaction 88: 9,312.00 vs 93.12). All corrected, 0 remaining.

### 3. Fixing Null Values
**Problem:** Some customers have no location.
**Solution:** Counted the NULLs, then created the view `vw_customer_profiles`, which shows `'Unknown'` through `COALESCE`.
**Result:** 13 missing locations, now shown as `Unknown`.

### 4. Cleaning Date
**Problem:** `TransactionDate` is stored as text, so date calculations don't work.
**Solution:** Created the view `vw_sales_transaction`, which adds a `DATE` column, `TransactionDate_updated`, using `CAST`.
**Result:** 5,000 transactions from 2023-01-01 to 2023-07-28.

---

## Part 2: Sales Analysis

### 5. Total Sales Summary
**Problem:** How many units and how much revenue does each product generate?
**Solution:** Created the view `vw_product_sales` with `SUM(QuantityPurchased)` and `SUM(QuantityPurchased * Price)` per product, then ranked by total sales.
**Result:** top 5 products by sales:

| ProductID | TotalUnitsSold | TotalSales |
|---|---|---|
| 17 | 100 | 9,450.00 |
| 87 | 92 | 7,817.24 |
| 179 | 86 | 7,388.26 |
| 96 | 72 | 7,132.32 |
| 54 | 86 | 7,052.86 |

### 6. Customer Purchase Frequency
**Problem:** How often does each customer buy?
**Solution:** Created the view `vw_customer_summary` (transactions and spend per customer) and listed transaction counts, highest first.
**Result:** customer 664 has the most transactions (14), followed by several customers with 12.

### 7. Product Categories Performance
**Problem:** Which categories should be promoted in marketing campaigns?
**Solution:** Joined sales to inventory and ranked categories by total sales.
**Result:**

| Category | TotalUnitsSold | TotalSales |
|---|---|---|
| Home & Kitchen | 3,477 | 217,755.94 |
| Electronics | 3,037 | 177,548.48 |
| Clothing | 2,810 | 162,874.21 |
| Beauty & Health | 3,001 | 143,824.99 |

### 8. High Sales Products
**Problem:** Which products bring in the most revenue?
**Solution:** Top 10 products by revenue from `vw_product_sales`.
**Result:** product 17 (9,450.00), product 87 (7,817.24) and product 179 (7,388.26) lead.

### 9. Low Sales Products
**Problem:** Which products sell the least?
**Solution:** Bottom 10 products by units sold from `vw_product_sales`, keeping only products with at least one unit sold.
**Result:** product 142 (27 units), product 33 (31) and product 174 (33) sell the least.

### 10. Sales Trend
**Problem:** What does daily revenue look like?
**Solution:** Grouped by date with `DATE_FORMAT` to get transactions, units and sales per day, rounded to 2 decimals.
**Result:** sales on all 209 days. Best day 2023-03-15 (4,516.08). The last day, 2023-07-28, has only 8 transactions against about 24 on a typical day, so the data looks cut off.

### 11. Growth Rate of Sales
**Problem:** How fast is revenue growing month over month?
**Solution:** A CTE for monthly sales, then `LAG()` to pull the previous month and compute the growth percentage.
**Result:**

| Month | TotalSales | PreviousMonthSales | MoMGrowth |
|---|---|---|---|
| Jan | 104,289.18 | - | - |
| Feb | 96,690.99 | 104,289.18 | -7.29% |
| Mar | 103,271.49 | 96,690.99 | 6.81% |
| Apr | 101,561.09 | 103,271.49 | -1.66% |
| May | 102,998.84 | 101,561.09 | 1.42% |
| Jun | 102,210.28 | 102,998.84 | -0.77% |
| Jul | 90,981.75 | 102,210.28 | -10.99% |

---

## Part 3: Customer Analysis

### 12. High Purchase Frequency
**Problem:** Who are the frequent, high-spending customers?
**Solution:** Filtered `vw_customer_summary` to customers with more than 10 transactions and more than 1000 spent.
**Result:** 18 customers. Top 5 by spend:

| CustomerID | NumberOfTransactions | TotalSpent |
|---|---|---|
| 936 | 12 | 2,834.47 |
| 664 | 14 | 2,519.04 |
| 670 | 12 | 2,432.15 |
| 39 | 12 | 2,221.29 |
| 958 | 12 | 2,104.71 |

### 13. Occasional Customers
**Problem:** Who buys rarely?
**Solution:** Filtered `vw_customer_summary` to customers with 2 transactions or fewer.
**Result:** 130 customers, of which 39 bought only once.

### 14. Repeat Purchases
**Problem:** Which customers buy the same product more than once?
**Solution:** Grouped by customer and product, keeping counts above 1.
**Result:** 70 customer-product pairs repeat. Only one pair was bought 3 times (customer 685, product 192).

### 15. Loyalty Indicators
**Problem:** How long do customers stay active?
**Solution:** `MIN` and `MAX` for first and last purchase, `DATEDIFF` for the gap, keeping customers with a gap above 0 days.
**Result:** 950 customers bought on more than one day. The longest span is 208 days (customer 215).

### 16. Customer Segmentation
**Problem:** How many customers fall into each purchase-volume segment?
**Solution:** Created the view `vw_customer_segment` with a `CASE` expression on total quantity (Low 1-10, Med 11-30, High above 30), then counted customers per segment.
**Result:**

| CustomerSegment | NumberOfCustomers |
|---|---|
| Low | 423 |
| Med | 559 |
| High | 7 |

---

## Skills Used

`JOIN` · `GROUP BY` · `HAVING` · `CASE` · CTEs · window functions (`LAG`) · views · date functions (`CAST`, `DATE_FORMAT`, `DATEDIFF`) · `CREATE TABLE AS` · `UPDATE` with `JOIN` · `COALESCE`
