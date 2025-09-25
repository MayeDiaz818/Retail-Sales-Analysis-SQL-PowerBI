--Schema

CREATE TABLE Customers (
    CustomerID VARCHAR(10) PRIMARY KEY,
    FirstName VARCHAR(50),
    LastName VARCHAR(50),
    Gender CHAR(1),
    BirthDate DATE,
    City VARCHAR(50),
    JoinDate DATE
);

CREATE TABLE Products (
    ProductID VARCHAR(10) PRIMARY KEY,
    ProductName VARCHAR(100),
    Category VARCHAR(50),
    SubCategory VARCHAR(50),
    UnitPrice NUMERIC(10,2),
    CostPrice NUMERIC(10,2)
);

CREATE TABLE Stores (
    StoreID VARCHAR(10) PRIMARY KEY,
    StoreName VARCHAR(100),
    City VARCHAR(50),
    Region VARCHAR(50)
);

CREATE TABLE Transactions (
    TransactionID VARCHAR(10) PRIMARY KEY,
    Date DATE,
    CustomerID VARCHAR(10) REFERENCES Customers(CustomerID),
    ProductID VARCHAR(10) REFERENCES Products(ProductID),
    StoreID VARCHAR(10) REFERENCES Stores(StoreID),
    Quantity INTEGER,
    Discount NUMERIC(3,2),
    PaymentMethod VARCHAR(50)
);

--Staging_load

copy Customers  
from 'C:\Program Files\PostgreSQL\17\data\Retail_sales_project/Customers.CSV'
Delimiter ','
CSV Header; 

copy Products  
from 'C:\Program Files\PostgreSQL\17\data\Retail_sales_project/Products.CSV'
Delimiter ','
CSV Header; 

copy Stores  
from 'C:\Program Files\PostgreSQL\17\data\Retail_sales_project/Stores.CSV'
Delimiter ','
CSV Header; 

copy Transactions  
from 'C:\Program Files\PostgreSQL\17\data\Retail_sales_project/Transactions.CSV'
Delimiter ','
CSV Header; 

select * from Customers;
select * from Products;
select * from Stores;
select * from Transactions;

--Exploratory Data Analysis (EDA) 
-- 1. Data Cleaning

-- Check for missing values in the Customers table
SELECT 
    COUNT(*) FILTER (WHERE CustomerID IS NULL) AS missing_CustomerID,
    COUNT(*) FILTER (WHERE FirstName IS NULL) AS missing_FirstName,
    COUNT(*) FILTER (WHERE LastName IS NULL) AS missing_LastName,
    COUNT(*) FILTER (WHERE Gender IS NULL) AS missing_Gender,
    COUNT(*) FILTER (WHERE BirthDate IS NULL) AS missing_BirthDate,
	COUNT(*) FILTER (WHERE City IS NULL) AS missing_City,
	COUNT(*) FILTER (WHERE JoinDate IS NULL) AS missing_JoinDate
FROM Customers;

-- Check for missing values in the Transactions table
SELECT 
    COUNT(*) FILTER (WHERE TransactionID IS NULL) AS missing_TransactionID,
    COUNT(*) FILTER (WHERE Date IS NULL) AS missing_Date,
    COUNT(*) FILTER (WHERE CustomerID IS NULL) AS missing_LastName,
    COUNT(*) FILTER (WHERE ProductID IS NULL) AS missing_ProductID,
    COUNT(*) FILTER (WHERE StoreID IS NULL) AS missing_StoreID,
	COUNT(*) FILTER (WHERE Quantity IS NULL) AS missing_Quantity,
	COUNT(*) FILTER (WHERE Discount IS NULL) AS missing_Discount,
	COUNT(*) FILTER (WHERE PaymentMethod IS NULL) AS missing_PaymentMethod
FROM Transactions;

-- Check for duplicate records.
SELECT CustomerID, BirthDate, JoinDate, COUNT(*)
FROM Customers
GROUP BY 1,2,3
HAVING COUNT(*) > 1;

SELECT TransactionID, Date, CustomerID, ProductID, COUNT(*)
FROM Transactions
GROUP BY 1,2,3,4
HAVING COUNT(*) > 1;

-- Check range of transaction dates
SELECT MIN(Date) AS first_transaction, MAX(Date) AS last_transaction
FROM Transactions;

-- Look for invalid or future dates
SELECT *
FROM Transactions
WHERE Date > CURRENT_DATE;

-- Check unit price and cost price in Products
SELECT 
    MIN(UnitPrice) AS min_unit_price,
    MAX(UnitPrice) AS max_unit_price,
    AVG(UnitPrice) AS avg_unit_price,
    MIN(CostPrice) AS min_cost_price,
    MAX(CostPrice) AS max_cost_price,
    AVG(CostPrice) AS avg_cost_price
FROM Products;

-- Detect negative or zero prices
SELECT *
FROM Products
WHERE UnitPrice <= 0 OR CostPrice <= 0;

-- Check quantity and discount in Transactions
SELECT 
    MIN(Quantity) AS min_quantity,
    MAX(Quantity) AS max_quantity,
    AVG(Quantity) AS avg_quantity,
    MIN(Discount) AS min_discount,
    MAX(Discount) AS max_discount,
    AVG(Discount) AS avg_discount
FROM Transactions;

-- Detect invalid values
SELECT *
FROM transactions
WHERE Quantity <= 0 OR Discount < 0 OR Discount > 1;

--2. Business Analysis
-- Top products and categories by total sales, Using correlated subqueries

WITH total_units AS (
    SELECT SUM(Quantity) AS total_units
    FROM Transactions
),
product_summary AS (
    SELECT
        p.ProductID,
        p.ProductName,
		p.category,
        (SELECT SUM(t.Quantity) 
         FROM Transactions t 
         WHERE t.ProductID = p.ProductID) AS total_units_sold,
        (SELECT ROUND(SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)),2)
         FROM Transactions t
         WHERE t.ProductID = p.ProductID) AS total_sales,
        (SELECT COUNT(*) 
         FROM Transactions t 
         WHERE t.ProductID = p.ProductID) AS num_transactions
    FROM Products p
)
SELECT
    ps.ProductID,
    ps.ProductName,
	ps.category,
    COALESCE(ps.total_units_sold,0) AS total_units_sold,
    COALESCE(ROUND(ps.total_sales,2),0) AS total_sales,
    COALESCE(ps.num_transactions,0) AS num_transactions,
    ROUND((COALESCE(ps.total_units_sold,0)::numeric / NULLIF(tu.total_units,0)) * 100,2) AS pct_of_total_units
FROM product_summary ps
CROSS JOIN total_units tu
ORDER BY ps.total_sales DESC
LIMIT 10;

--- Top categories by sales and profit
SELECT 
    p.Category,
    SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)) AS total_sales,
    SUM(t.Quantity * (p.UnitPrice * (1 - t.Discount) - p.CostPrice)) AS total_profit
FROM Transactions t
JOIN Products p ON t.Productid = p.Productid
GROUP BY 1
ORDER BY total_sales DESC;

--- Trend of sales monthly
SELECT
	EXTRACT(YEAR FROM t.Date) AS Year,
	EXTRACT(MONTH FROM t.Date) AS Month,
	SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)) AS total_sales
FROM Transactions t
JOIN Products p ON t.productid = p.Productid
GROUP BY 1,2
ORDER BY Year, Month;

--- Trend of sales yearly
SELECT
	EXTRACT(YEAR FROM t.Date) AS Year,
	SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)) AS total_sales
FROM Transactions t
JOIN Products p ON t.Productid = p.Productid
GROUP BY Year
ORDER BY Year;

--- Trend of sales quarterly
SELECT
	EXTRACT(YEAR FROM t.Date) AS Year,
	EXTRACT(QUARTER FROM t.Date) AS Quarter,
	SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)) AS total_sales
FROM Transactions t
JOIN Products p ON t.Productid = p.Productid
GROUP BY 1,2
ORDER BY Year, Quarter;

-- Best performing stores
SELECT
    s.StoreID,
    s.Region,
    s.City,
    SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)) AS total_sales,
    SUM((p.UnitPrice - p.CostPrice) * t.Quantity * (1 - t.Discount)) AS total_profit,
	COUNT(DISTINCT t.CustomerID) AS total_customers,
    RANK() OVER (ORDER BY SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)) DESC) AS sales_rank,
    RANK() OVER (ORDER BY SUM((p.UnitPrice - p.CostPrice) * t.Quantity * (1 - t.Discount)) DESC) AS profit_rank
FROM Transactions t
JOIN Products p ON t.ProductID = p.ProductID
JOIN Stores s ON t.StoreID = s.StoreID
GROUP BY 1,2,3
ORDER BY sales_rank;

-- Sales by Gender
Select
	c.gender, 
	SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)) AS total_sales,
    SUM((p.UnitPrice - p.CostPrice) * t.Quantity * (1 - t.Discount)) AS total_profit,
	COUNT(DISTINCT c.customerid) AS total_customers
FROM Transactions t
JOIN Products p ON t.ProductID = p.ProductID
JOIN Customers c ON c.customerid = t.customerid
GROUP BY 1
ORDER BY total_sales DESC;

-- Sales by Age Group
WITH customer_age as(
	SELECT 
		c.customerid, 
		DATE_PART('year', AGE(CURRENT_DATE, c.birthdate)) AS age
	FROM Customers c
)
SELECT
	CASE
		WHEN ca.age<25 THEN 'Under25'
		WHEN ca.age BETWEEN 25 AND 34 THEN '25-34'
		WHEN ca.age BETWEEN 35 AND 44 THEN '35-44'
		WHEN ca.age BETWEEN 45 AND 54 THEN '45-54'
		ELSE '55+'
	END AS age_group,
	SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)) AS total_sales,
    SUM((p.UnitPrice - p.CostPrice) * t.Quantity * (1 - t.Discount)) AS total_profit,
	COUNT(DISTINCT ca.customerid) AS total_customers
FROM Transactions t
JOIN Products p ON t.ProductID = p.ProductID
JOIN Customer_age ca ON ca.customerid = t.customerid
GROUP BY age_group
ORDER BY total_sales DESC; 

-- AOV & CLV
WITH customer_data AS (
    SELECT 
        t.customerid,
        COUNT(DISTINCT t.transactionid) AS number_of_orders,
        ROUND(SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)),2) AS total_sales,
        MIN(t.date) AS first_order_date,
        MAX(t.date) AS last_order_date,
     	(MAX(t.date) - MIN(t.date)) AS lifespan_days 
    FROM Transactions t
	JOIN Products p ON t.ProductID = p.ProductID
    GROUP BY 1 
)
SELECT 
    customerid,
    number_of_orders,
    total_sales AS historical_clv,
    lifespan_days,
    ROUND(total_sales / NULLIF(number_of_orders, 0),2) AS AOV,
    ROUND(number_of_orders::NUMERIC / NULLIF(lifespan_days,0),2) AS purchase_frequency_per_day,
    ROUND((total_sales / NULLIF(lifespan_days,0)) * 365,2) AS estimated_annual_clv
FROM 
    customer_data
ORDER BY 
    historical_clv DESC
	LIMIT 10;

--- How do discounts affect revenue? - (Revenue vs Discount)

Select distinct discount from transactions;

SELECT 
    Discount,
    COUNT(*) AS num_transactions,
    ROUND(SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)),2) AS total_revenue,
    ROUND(AVG(t.Quantity * p.UnitPrice * (1 - t.Discount)),2) AS avg_revenue_per_transaction,
	ROUND(SUM((p.UnitPrice - p.CostPrice) * t.Quantity * (1 - t.Discount)),2) AS total_profit
FROM Transactions t
JOIN Products p ON t.ProductID = p.ProductID
GROUP BY Discount
ORDER BY total_revenue DESC;


--- Profit Margin by Product
WITH total_revenue AS(
	SELECT 
		t.productid,
		p.productname,
		SUM(t.Quantity) AS total_units_sold,
    	SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)) AS total_sales,
		SUM(t.Quantity * p.CostPrice) AS total_cost
	FROM Transactions t
	JOIN Products p ON t.ProductID = p.ProductID
	GROUP BY 1,2
)
SELECT 
	r.productid,
	r.productname,
	r.total_units_sold,
	r.total_sales,
	r.total_cost,
	ROUND(((r.total_sales - r.total_cost)/ r.total_sales)*100,2) AS Profit_margin
FROM total_revenue r
ORDER BY profit_margin DESC
LIMIT 10;

--Gross Margin 

WITH total_revenue AS(
	SELECT 
    	SUM(t.Quantity * p.UnitPrice * (1 - t.Discount)) AS total_sales,
		SUM(t.Quantity * p.CostPrice) AS total_cost
	FROM Transactions t
	JOIN Products p ON t.ProductID = p.ProductID
)
SELECT 
	total_sales,
	total_cost,
	ROUND(((total_sales - total_cost)/ total_sales)*100,2) AS Profit_margin
FROM total_revenue;



select * from Customers;
select * from Products;
select * from Stores;
select * from Transactions;