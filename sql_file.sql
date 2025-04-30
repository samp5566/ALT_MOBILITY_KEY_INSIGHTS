SET SQL_SAFE_UPDATES = 0;
CREATE DATABASE alt_mobility;
USE alt_mobility;

CREATE TABLE orders
(order_id VARCHAR(50),
customer_id INT,
order_date DATE,
order_amount DOUBLE,
shipping_address VARCHAR(200),
order_status VARCHAR(25));

SELECT * FROM orders;

LOAD DATA INFILE 'orders.csv' INTO TABLE orders FIELDS TERMINATED BY ',' IGNORE 1 LINES;

SELECT COUNT(*) FROM orders;

CREATE TABLE payments
(payment_id VARCHAR(50),
order_id VARCHAR(50),
payment_date DATE,
payment_amount DOUBLE,
payment_method VARCHAR(20),
payment_status VARCHAR(20));

SELECT * FROM payments;

LOAD DATA INFILE 'payments.csv' INTO TABLE payments FIELDS TERMINATED BY ',' IGNORE 1 LINES;

SELECT COUNT(*) FROM payments;

#TASK 1
#Revenue trend (Yearly)
SELECT YEAR(order_date) AS year , ROUND(SUM(order_amount),2) as total_amount FROM orders GROUP BY year ORDER BY total_amount DESC;
#2023 = Highest revenue generated (735218.44)
#2024 = Lowest revenue generated (699269.85)

#YOY change (2023 & 2024) 
WITH year_2023 AS
(SELECT ROUND(SUM(order_amount),2) AS amount_2023 FROM orders WHERE YEAR(order_date) = 2023),
year_2024 AS (SELECT ROUND(SUM(order_amount),2) AS amount_2024 FROM orders WHERE YEAR(order_date) = 2024)
SELECT ROUND((amount_2024 - amount_2023)/amount_2023*100,2) AS yoy_change FROM year_2024,year_2023;
#-4.89% reduction is seen from 2023 to 2024 

#YOY change (2022 & 2023)
WITH year_2022 AS
(SELECT ROUND(SUM(order_amount),2) AS amount_2022 FROM orders WHERE YEAR(order_date) = 2022),
year_2023 AS (SELECT ROUND(SUM(order_amount),2) AS amount_2023 FROM orders WHERE YEAR(order_date) = 2023)
SELECT ROUND((amount_2023 - amount_2022)/amount_2022*100,2) as yoy_change FROM year_2023,year_2022;
#+3.24% growth is seen from 2022 to 2023 in revenue generation.

#Order status in 2022,2023 & 2024
SELECT YEAR(order_date) AS year, order_status, COUNT(order_id) as total_orders
FROM orders WHERE YEAR(order_date) IN (2022,2023,2024)
GROUP BY YEAR(order_date), order_status ORDER BY year, total_orders DESC;
#2022 = DELIVERED ORDERS (975) ARE HIGHEST WITH LOWEST PENDING ORDERS
#2023 = PENDING ORDERS (979) ARE MORE WITH SHIPPED ORDERS BUT DELIVERED ORDERS ARE LOW
#2024 = PENDING ORDERS (946) STILL RANK THE HIGHEST FOLLOWED BY DELIVERED ORDERS AND SHIPPED ORDERS

#Orders by year
WITH t as (
SELECT EXTRACT(YEAR FROM order_date) as year, COUNT(order_id) as total_orders FROM orders GROUP BY EXTRACT(YEAR FROM order_date))
SELECT *, (total_orders - LAG(total_orders) OVER (ORDER BY year)) as orders_difference FROM t;
#2023 = RECEIVED HIGHEST ORDERS(+59) BECAUSE THE DELIVERED ORDERS IN 2022 WERE HIGHEST THUS REVENUE GROWTH
#2024 = NUMBER OF ORDERS DECREASED (-143) BECAUSE THE NUMBER OF PENDING ORDERS IN 2023, 2024 THUS REVENUE LOSS

#MOM OF 2025
SELECT *, ROUND((total_amount - LAG(total_amount) OVER (ORDER BY month))/LAG(total_amount) OVER (ORDER BY month)*100,2) AS MOM FROM 
(SELECT EXTRACT(MONTH FROM order_date) AS month, ROUND(SUM(order_amount)) AS total_amount FROM orders 
WHERE YEAR(order_date)= 2025 GROUP BY month ORDER BY month) AS year_2025; 
#-11.23% loss is seen from March to April 2025 

#Monthwise order status in 2025
SELECT MONTH(order_date) AS month, MONTHNAME(order_date) AS monthname, order_status, COUNT(order_id) AS total_orders FROM orders
WHERE YEAR(order_date)=2025 GROUP BY month, monthname, order_status ORDER BY month;
#April has highest shipped orders with lowest delivered orders contrasting to March in 2025


#TASK 2
#Identify customers with repeated orders
SELECT customer_id, COUNT(order_id) as total_orders FROM orders GROUP BY customer_id HAVING total_orders > 1 ORDER BY total_orders DESC;
#Customer 2633 has highest repeated orders (8)

#Segmentation of customers based on repeated orders

CREATE TABLE customer_freq SELECT customer_id, COUNT(order_id) as total_orders,
CASE 
WHEN  COUNT(order_id) <= 2 THEN 'Low Purchasing'
WHEN  COUNT(order_id) BETWEEN 3 AND 5 THEN 'Moderately Purchasing'
WHEN  COUNT(order_id) > 5 THEN 'Highly Purchasing'
END AS order_frequency 
FROM orders GROUP BY customer_id ORDER BY customer_id;

SELECT * FROM customer_freq;

#Customer order frequency wise distribution
SELECT c.order_frequency, (COUNT(o.order_id)/15000)*100 AS distribution FROM orders AS o INNER JOIN customer_freq AS c 
ON o.customer_id = c.customer_id GROUP BY c.order_frequency ORDER BY distribution DESC;
#Large group of customers with low purchasing behavior (50.25%)

#Order status by segmented customers
SELECT o.order_status, c.order_frequency, COUNT(o.order_id) AS total_orders FROM orders AS o INNER JOIN customer_freq AS c 
ON o.customer_id = c.customer_id GROUP BY o.order_status, c.order_frequency ORDER BY total_orders DESC;
#Customer in low purchasing frequency has more pending order status than customers with moderately and highly purchasing that have high rate of delivered orders.

#Yearwise customer purchase behavior
SELECT YEAR(o.order_date) AS year, c.order_frequency, COUNT(o.order_id) AS total_orders, ROUND(SUM(o.order_amount)) AS total_amount
FROM orders AS o INNER JOIN customer_freq AS c 
ON o.customer_id = c.customer_id GROUP BY year,c.order_frequency ORDER BY year, total_amount DESC;
#Customers in low purchasing frequency group have generated more revenue than customers in moderately and highly purchasing groups throughout the years except 2021.
#2023 = Customers from low purchasing frequency has generated highest revenue i.e. 380087. 

WITH t as 
(SELECT YEAR(o.order_date) AS year, MONTH(o.order_date) AS month, c.order_frequency, ROUND(SUM(o.order_amount)) AS total_amount 
FROM orders AS o INNER JOIN customer_freq AS c 
ON o.customer_id = c.customer_id GROUP BY year,month,c.order_frequency HAVING c.order_frequency = 'Low Purchasing' ORDER BY year, month ,total_amount DESC)
SELECT year, month, ROUND((total_amount - LAG(total_amount,1) OVER (ORDER BY year,month))/LAG(total_amount,1) OVER (ORDER BY year),4)*100 AS prev_amount 
FROM t ORDER BY year,month;
#Revenue from customers with low purchasing frequency is decreased by 26.48% in April 2025. 
 
 
#Calculate avg time between frequently purchasing customer
SELECT c.order_frequency, SEC_TO_TIME(AVG(TIMESTAMPDIFF(HOUR, previous_order, o.order_date))) AS avg_time_between_orders FROM
orders o JOIN customer_freq c ON o.customer_id = c.customer_id 
LEFT JOIN 
(SELECT customer_id , order_date , lag(order_date,1) OVER (PARTITION BY customer_id ORDER BY order_date) AS previous_order FROM orders) AS prev_orders
ON o.customer_id = prev_orders.customer_id WHERE previous_order IS NOT NULL GROUP BY c.order_frequency ORDER BY avg_time_between_orders DESC; 
#Average time taken between orders for low purchasing group of customers is more (2 hrs) than other purchasing groups


#TASK 3 
#Payment performance by payment status
SELECT payment_status, ROUND(AVG(payment_amount)) AS avg_amount FROM payments GROUP BY payment_status ORDER BY avg_amount DESC;
#Failed payments have the highest avg payment (255) amount followed by pending.

#Payment method impact on total payments by payment status
SELECT payment_method, payment_status, COUNT(payment_id) AS total_payments FROM payments GROUP BY payment_method, payment_status ORDER BY total_payments DESC;
#Bank transfer has most failed payments and low successful payments indicating a potential issue in the process. 
#However paypal has most successful payments and low failed payments suggesting a good method of payment.

#Success rate of payments over payment method
SELECT payment_method, SUM(CASE WHEN payment_status = 'completed' THEN 1 ELSE 0 END)/COUNT(*) * 100 AS success_rate 
FROM payments GROUP BY payment_method;
#Paypal has the highest success rate of payments i.e. +11.3% followed by credit card then bank transfer

#Years & status wise payment trend
SELECT YEAR(payment_date) as year, payment_status, COUNT(payment_id) AS total_payments, ROUND(SUM(payment_amount)) AS total_amount 
FROM payments GROUP BY year, payment_status ORDER BY year, total_amount DESC;
#From 2024, number of successful payments have been increased with total number of payments and total amount of payments. 

SELECT YEAR(payment_date) as year, payment_method, payment_status, COUNT(payment_id) AS total_payments, ROUND(SUM(payment_amount)) AS total_amount 
FROM payments GROUP BY year,payment_status, payment_method HAVING year IN (2024,2025) ORDER BY year, total_amount DESC;
#Paypal has been used frequently for successful payments in 2024 and 2025.


#TASK 4
#Order details
SELECT order_id, customer_id, order_date, order_amount, order_status FROM orders;

#Order status in 2025
SELECT order_status, COUNT(order_id) AS total_orders FROM ORDERS WHERE YEAR(order_date) = 2025 GROUP BY order_status ORDER BY total_orders DESC; 
#DELIVERED = HIGHEST ORDER STATUS (318)
#PENDING = LOWEST ORDER STATUS (298) 

#Revenue trend in 2025
SELECT MONTH(order_date) as month, ROUND(SUM(order_amount)) as total_amount FROM orders WHERE YEAR(order_date) = 2025 
GROUP BY month ORDER BY month;
#Highest revenue is generated in month of March in 2025.

#Payment details
SELECT payment_id, payment_date, payment_amount, payment_method, payment_status FROM payments;

#Number of payments by payment status
SELECT payment_status, COUNT(payment_id) AS total_payments FROM payments WHERE YEAR(payment_date)=2025 GROUP BY payment_status ORDER BY total_payments DESC;
#In 2025, completed payments are more.

#Number of payments by payment_method
SELECT payment_method, COUNT(payment_id) AS total_payments FROM payments WHERE YEAR(payment_date)=2025 GROUP BY payment_method ORDER BY total_payments DESC;
#Paypal is highly used as payment method in 2025.

#Orders not in payments
WITH t AS
(SELECT orders.order_id, payments.order_id as payment_order_id FROM orders LEFT JOIN payments ON orders.order_id = payments.order_id WHERE payments.order_id IS NULL)
SELECT COUNT(*) FROM t;
#There are total 5505 orders which haven't been processed for payments.







