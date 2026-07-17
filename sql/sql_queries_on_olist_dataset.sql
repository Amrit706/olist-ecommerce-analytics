-- =====================================================================================
-- PART 1: DATA EXPLORATION & CORE BUSINESS METRICS
-- Description: Foundational data analysis focusing on aggregations, joins, date 
-- manipulation, and primary Key Performance Indicators (KPIs) for the Olist platform.
-- =====================================================================================

USE olist_ecommerce;
-- Basic (Warm-up & Aggregations)

-- Problem 1 - Total Revenue: Write a query to calculate the total gross revenue generated across the entire platform.
-- Query: 
SELECT ROUND(SUM(payment_value),2) AS total_revenue 
FROM payments;

-- Problem 2 - Order Status Distribution: Find the total number of orders for each distinct order_status 
-- (e.g., delivered, canceled, shipped). Sort the results from highest volume to lowest.
-- Query:
SELECT order_status, COUNT(order_status) AS count
FROM orders
GROUP BY order_status
ORDER BY count DESC;

-- Problem 3 - Customer Geography: Determine how many unique customers exist in each Brazilian state.
-- Query:
SELECT customer_state, COUNT(DISTINCT(customer_id)) AS unique_customer_count
FROM customers
GROUP BY customer_state
ORDER BY unique_customer_count DESC;

-- Problem 4 - Platform Satisfaction: Calculate the overall average review score across all orders, 
-- rounded to exactly two decimal places.
-- Query:

SELECT ROUND(AVG(review_score),2) AS avg_review_score
FROM reviews;

-- Problem 5 - Top Categories by Volume: Identify the top 5 product categories based strictly on the total number of items sold.
-- Query:

SELECT t3.product_category_name, COUNT(t1.order_id) AS total_item_sold
FROM orders t1
JOIN order_items t2
ON t1.order_id = t2.order_id
JOIN products t3
ON t2.product_id = t3.product_id
WHERE t1.order_status NOT IN ("canceled","unavailable")
GROUP BY t3.product_category_name
ORDER BY total_item_sold DESC LIMIT 5;

-- Intermediate (Joins & Timestamp Extraction)

-- Problem 6 - Monthly Sales Trend: 
-- Extract the year and month from the purchase timestamp to calculate the total number of orders placed in each specific month.
-- Query:

SELECT YEAR(order_purchase_timestamp) AS year, MONTHNAME(order_purchase_timestamp) AS months, COUNT(*) AS order_counts
FROM orders
GROUP BY year, months
ORDER BY order_counts DESC;

-- Problem 7 - Revenue by Payment Type: 
-- Calculate the total revenue and the total number of transactions for each distinct payment method (credit card, boleto, etc.).
-- Query:

SELECT t2.payment_type, COUNT(t2.payment_type) AS total_number_of_transactions, ROUND(SUM(t2.payment_value),2) AS total_revenue
FROM orders t1
JOIN payments t2
ON t1.order_id = t2.order_id
GROUP BY t2.payment_type;

-- Problem 8 - Average Delivery Speed: Extract the difference in days between the purchase timestamp and 
-- the customer delivery date to calculate the average delivery time for all completed 'delivered' orders.

SELECT CEIL(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp))) AS avg_delivery_speed
FROM orders
WHERE order_status = 'delivered'
GROUP BY order_status;

-- Problem 9 - Top Earning Sellers: Find the top 10 sellers based on the total revenue they have generated. 
-- Display their seller ID, city, and total earnings.
-- Query:

SELECT t2.seller_id, t3.seller_state, ROUND(SUM(t2.price),2) AS total_earning
FROM orders t1
JOIN order_items t2
ON t1.order_id = t2.order_id
JOIN sellers t3
ON t2.seller_id = t3.seller_id
WHERE order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY t2.seller_id, t3.seller_state
ORDER BY total_earning DESC;

-- Problem 10 - Impact of Delays on Reviews: Compare the average review score of orders that arrived on time 
-- or early versus orders that arrived after their estimated delivery date.

WITH cte1 AS (SELECT t1.order_id, DATEDIFF(t1.order_delivered_customer_date, t1.order_purchase_timestamp) AS exact_delivery_time,
DATEDIFF(t1.order_estimated_delivery_date , t1.order_purchase_timestamp) AS estimated_delivery_time, t2.review_score
FROM orders t1
JOIN reviews t2
ON t1.order_id = t2.order_id
WHERE t1.order_status = 'delivered')

SELECT CASE WHEN exact_delivery_time = estimated_delivery_time THEN 'on_time'
				WHEN exact_delivery_time < estimated_delivery_time THEN 'early'
                ELSE 'late' END AS delivery_status,
		ROUND(AVG(review_score),2) AS avg_review_score
FROM cte1
GROUP BY delivery_status;

-- Advanced (CTEs, Window Functions & Conditional Logic)

-- Problem 11 - Exact Order Status Count by State: Calculate the total number of orders, 
-- the exact count of 'delivered' orders, and the exact count of 'canceled' orders for each customer state in a single query.
-- Query:

SELECT t2.customer_state,
COUNT(t1.order_id) AS total_orders,
SUM(CASE WHEN t1.order_status = 'delivered' THEN 1 ELSE 0 END) AS total_delivered_orders,
SUM(CASE WHEN t1.order_status = 'canceled' THEN 1 ELSE 0 END) AS total_canceled_orders
FROM orders t1
JOIN customers t2
ON t1.customer_id = t2.customer_id
GROUP BY t2.customer_state;

-- Problem 12 - Month-over-Month Growth: Use window functions (such as LAG) to calculate the total revenue for each month and 
-- the exact percentage growth or decline compared directly to the preceding month.
-- Query:

WITH cte3 AS (SELECT YEAR(t1.order_purchase_timestamp) AS year, MONTH(t1.order_purchase_timestamp) AS month_number , 
MONTHNAME(t1.order_purchase_timestamp) AS month_name, SUM(t2.payment_value) AS payment_value, 
LAG(SUM(t2.payment_value)) OVER(ORDER BY YEAR(t1.order_purchase_timestamp) ASC, MONTH(t1.order_purchase_timestamp) ASC) AS 'previous_month_payment'
FROM orders t1
JOIN payments t2
ON t1.order_id = t2.order_id
GROUP BY year, month_number, month_name 
ORDER BY year ASC, month_number ASC)

SELECT year, month_name,
CASE WHEN previous_month_payment IS NULL THEN 100 
ELSE ROUND(((payment_value - previous_month_payment) / previous_month_payment) * 100,2) END AS 'MoM_Growth'
FROM cte3;

-- Problem 13 - Repeat Customer Identification: Using a Common Table Expression (CTE), 
-- determine the absolute total count of unique customers who have placed more than one order on the platform.
-- Query:

WITH cte4 AS (
	SELECT t1.customer_unique_id, COUNT(t2.order_id) AS total_orders
	FROM customers t1
	JOIN orders t2
	ON t1.customer_id = t2.customer_id
	WHERE t2.order_status NOT IN ('canceled', 'unavailable', 'created')
	GROUP BY t1.customer_unique_id
	HAVING COUNT(t2.order_id) > 1
)

SELECT COUNT(customer_unique_id) AS total_unique_customers
FROM cte4;

-- Problem 14 - Cumulative Daily Revenue: Calculate the daily total revenue and use an over-partitioning 
-- window function to create an ascending, cumulative running sum of revenue across the platform's timeline.
-- Query:

WITH cte5 AS (
	SELECT DATE(t1.order_purchase_timestamp) AS day, ROUND(SUM(t2.payment_value),2) AS daily_revenue
	FROM orders t1
	JOIN payments t2
	ON t1.order_id = t2.order_id
    WHERE t1.order_status NOT IN ('canceled', 'unavailable', 'created')
	GROUP BY DATE(t1.order_purchase_timestamp)
	ORDER BY day ASC
)

SELECT day, daily_revenue,
ROUND(SUM(daily_revenue) OVER(ORDER BY day ASC
						ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),2) AS cumulative_revenue
FROM cte5;

-- Problem 15 - RFM Base Metrics: For each unique customer id, calculate their "Recency" 
-- (days elapsed between their last purchase and the maximum date in the entire dataset),
-- "Frequency" (total distinct orders placed), and "Monetary Value" (total financial value spent across all their payments).

SELECT t1.customer_unique_id,
    DATEDIFF(
        (SELECT MAX(DATE(order_purchase_timestamp)) 
         FROM orders 
         WHERE order_status NOT IN ('canceled', 'unavailable', 'created')), 
        MAX(DATE(t2.order_purchase_timestamp))
    ) AS 'Recency',
COUNT(DISTINCT t2.order_id) AS 'Frequency',
ROUND(SUM(t3.payment_value), 2) AS 'Monetary Value'
FROM customers t1
JOIN orders t2
ON t1.customer_id = t2.customer_id
JOIN payments t3 
ON t2.order_id = t3.order_id
WHERE t2.order_status NOT IN ('canceled', 'unavailable', 'created')
GROUP BY t1.customer_unique_id;


-- =====================================================================================
-- PART 2: EXECUTIVE ANALYTICS & ADVANCED BUSINESS SCENARIOS
-- Description: Complex queries utilizing CTEs, Window Functions, and Self-Joins 
-- to derive strategic business intelligence, predictive metrics, and customer insights.
-- =====================================================================================

-- -------------------------------------------------------------------------------------
-- PROBLEM 16: The Pareto Principle (80/20 Rule) Analysis
-- 
-- Business Scenario: The VP of Sales wants to know if the platform's revenue is 
-- dangerously concentrated among a few top sellers.
--
-- Task: Write a query to determine if 20% of the active sellers generate 80% of the 
-- total revenue. Calculate the total revenue per seller, sort them descending, and 
-- use a running total (cumulative sum) as a percentage of the grand total revenue 
-- to find the cut-off point.
-- -------------------------------------------------------------------------------------

USE olist_ecommerce;
WITH revenue_data AS (SELECT t1.seller_id, SUM(t4.payment_value) AS total_revenue
FROM sellers t1
JOIN order_items t2
ON t1.seller_id = t2.seller_id
JOIN orders t3
ON t2.order_id = t3.order_id
JOIN payments t4
ON t3.order_id = t4.order_id
WHERE order_status NOT IN ('unavailable','created', 'canceled')
GROUP BY t1.seller_id
ORDER BY total_revenue DESC ),

revenue_percentage AS (SELECT *,
SUM(total_revenue) OVER() AS grand_total_revenue,
((total_revenue / SUM(total_revenue) OVER()) * 100) AS revenue_perc
FROM revenue_data),

cum_rev_perc AS (SELECT *, COUNT(seller_id) OVER() AS seller_count,
SUM(revenue_perc) OVER(ORDER BY revenue_perc DESC ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS cumulative_revenue_perc
FROM revenue_percentage)

SELECT seller_id, cumulative_revenue_perc, ROUND((COUNT(seller_id) OVER() / seller_count) * 100,2) AS top_nPerc_seller
FROM cum_rev_perc
WHERE cumulative_revenue_perc <= 80;

