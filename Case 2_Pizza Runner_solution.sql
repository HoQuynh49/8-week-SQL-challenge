---A. Pizza Metrics Solutions

--1. How many pizzas were ordered?
SELECT count(pizza_id) as Total_ordered_pizza
FROM customer_orders

--2. How many unique customer orders were made?
SELECT COUNT(DISTINCT(order_id)) as unique_customer_orders
FROM customer_orders

--3. How many successful orders were delivered by each runner?
SELECT runner_id, COUNT(c.order_id) as delivered_orders
FROM customer_orders c
LEFT JOIN runner_orders r
ON c.order_id = r.order_id
WHERE r.pickup_time_new IS NOT NULL
GROUP BY runner_id

--4. How many of each type of pizza was delivered?
SELECT cast(p.pizza_name AS varchar) AS PizzaName, COUNT(p.pizza_id) as delivered_pizza FROM 
(
SELECT c.*, r.runner_id, r.pickup_time_new, r.distance_km, r.duration_minutes, r.cancellation_new
FROM customer_orders c
LEFT JOIN runner_orders r
ON c.order_id = r.order_id
WHERE r.pickup_time_new IS NOT NULL
) 
AS delivery_table
LEFT JOIN pizza_names p
ON delivery_table.pizza_id = p.pizza_id
GROUP BY cast(p.pizza_name AS varchar)

--5. How many Vegetarian and Meatlovers were ordered by each customer?
SELECT cast(p.pizza_name AS varchar) as PizzaName, c.customer_id, COUNT(c.order_id) as pizza_type_per_customer
FROM customer_orders c
LEFT JOIN runner_orders r ON c.order_id = r.order_id
LEFT JOIN pizza_names p ON c.pizza_id = p.pizza_id
GROUP BY cast(p.pizza_name AS varchar), c.customer_id
ORDER BY 1

--6. What was the maximum number of pizzas delivered in a single order?

SELECT TOP 1 order_id, COUNT(order_id) as max_single_order_pizza
FROM customer_orders
GROUP BY order_id
ORDER BY COUNT(order_id) DESC

--7. For each customer, how many delivered pizzas had at least 1 change and how many had no changes?
SELECT c.customer_id, COUNT(c.order_id) as count_pizza, 
CASE WHEN COUNT(DISTINCT(p.pizza_id)) >1 THEN 'change types of pizza'
ELSE 'no changes'
END AS behavior_order
FROM customer_orders c
LEFT JOIN pizza_names p
ON c.pizza_id = p.pizza_id
--ORDER BY c.customer_id ASC
GROUP BY customer_id

--8. How many pizzas were delivered that had both exclusions and extras?
SELECT c.order_id, COUNT(c.order_id) as total_order_both_ExclusionsAndExtras
FROM customer_orders c
LEFT JOIN runner_orders r
ON c.order_id = r.order_id
WHERE r.pickup_time_new IS NOT NULL
AND c.exclusions_new IS NOT NULL
AND c.extras_new IS NOT NULL
GROUP BY c.order_id

--9. What was the total volume of pizzas ordered for each hour of the day?
SELECT DATEPART(hour, order_time) as hour, COUNT(order_id) as volume_of_pizza
FROM customer_orders
GROUP BY DATEPART(hour, order_time) 

--10. What was the volume of orders for each day of the week?
SELECT DATEPART(DW, order_time) as day, COUNT(order_id) as volume_of_pizza
FROM customer_orders
GROUP BY DATEPART(DW, order_time)

--B. RUUNER & CUSTOMER EXPERIENCE

--1. How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT DATEADD(DAY, 5, DATETRUNC(WEEK,registration_date)) as week, COUNT(runner_id) AS count_runner
FROM runners
GROUP BY DATEADD(DAY, 5, DATETRUNC(WEEK,registration_date))

--2. What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
SELECT r.runner_id, AVG(CONVERT(float, DATEDIFF(minute, c.order_time, r.pickup_time_new))) as avg_time_
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE r.pickup_time_new IS NOT NULL
GROUP BY r.runner_id

-- 3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
--> Số lượng đặt pizza càng nhiều thì thời gian chuẩn bị càng lâu
SELECT number_of_pizza, AVG(CONVERT(float,prep_time)) as AVG_prep_time
FROM
(SELECT c.order_id, COUNT(c.pizza_id) as number_of_pizza, AVG(DATEDIFF(minute, c.order_time, r.pickup_time_new)) as prep_time
FROM customer_orders c
JOIN runner_orders r
ON c.order_id = r.order_id
WHERE r.pickup_time_new IS NOT NULL
GROUP BY c.order_id) AS prep_table
GROUP BY number_of_pizza

-- 4. What was the average distance travelled for each customer?
SELECT c.customer_id, AVG(distance_km) AS distance_per_customer_km
FROM runner_orders r
JOIN customer_orders c
ON r.order_id = c.order_id
WHERE distance_km IS NOT NULL
GROUP BY c.customer_id

-- 5. What was the difference between the longest and shortest delivery times for all orders?
SELECT MAX(duration_minutes) - MIN(duration_minutes) AS diff_longest_shorted_delivery_time
FROM runner_orders
WHERE duration_minutes IS NOT NULL

-- 6. What was the average speed for each runner for each delivery and do you notice any trend for these values?
--> Trend: the runner does more orders they get faster
SELECT runner_id, order_id, SUM(distance_km) / SUM(duration_minutes) AS avg_speed
FROM runner_orders 
WHERE pickup_time_new IS NOT NULL
GROUP BY runner_id, order_id
ORDER BY runner_id, order_id

-- 7. What is the successful delivery percentage for each runner?
SELECT runner_id, SUM(cast(CASE WHEN pickup_time_new IS NULL THEN 0 ELSE 1 END AS float)) / COUNT(cast(order_id AS float)) AS percentage_of_successful_order
FROM runner_orders
GROUP BY runner_id

--C. INGREDIENT OPTIMISATION

--1. What are the standard ingredients for each pizza?
SELECT pr.pizza_id, pt.topping_id, pt.topping_name
FROM pizza_recipes pr
CROSS APPLY string_split(cast(pr.toppings as varchar),',') as pizza_ingredient
JOIN pizza_toppings pt
ON pizza_ingredient.value = pt.topping_id

--2. What was the most commonly added extra?
SELECT TOP 1 pt.topping_id, cast(pt.topping_name as varchar) as extra_topping_name, COUNT(pt.topping_id) as number_topping
FROM customer_orders co
CROSS APPLY string_split(co.extras_new,',') as extra_ingredient
JOIN pizza_toppings pt
ON extra_ingredient.value = pt.topping_id
GROUP BY pt.topping_id, cast(pt.topping_name as varchar)
ORDER BY COUNT(pt.topping_id) DESC

--3. What was the most common exclusion?
SELECT TOP 1 pt.topping_id, cast(pt.topping_name as varchar) as exclusion_topping_name, COUNT(pt.topping_id) as number_topping
FROM customer_orders co
CROSS APPLY string_split(co.exclusions_new,',') as exclusuion_ingredient
JOIN pizza_toppings pt
ON exclusuion_ingredient.value = pt.topping_id
GROUP BY pt.topping_id, cast(pt.topping_name as varchar)
ORDER BY COUNT(pt.topping_id) DESC

--4. Generate an order item for each record in the customers_orders table in the format of one of the following:
--		Meat Lovers
--		Meat Lovers - Exclude Beef
--		Meat Lovers - Extra Bacon
--		Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
-- exlcusion_table
WITH exclusion_table AS
(
SELECT DISTINCT order_id, pizza_id, topping_id, substring(
(
SELECT distinct exclusion_topping + ', ' as [text()]
FROM 
(
SELECT co.order_id, co.pizza_id, pt.topping_id, cast(pt.topping_name as varchar) as exclusion_topping
FROM customer_orders co
CROSS APPLY string_split(co.exclusions_new,',') as exclusion_ingredient
JOIN pizza_toppings pt
ON exclusion_ingredient.value = pt.topping_id
) as exclsuion_name_1
WHERE exclsuion_name_1.order_id = exclsuion_name_2.order_id
FOR XML PATH('')
),1,1000) as exclusion_topping
FROM 
(
SELECT co.order_id, co.pizza_id, pt.topping_id, cast(pt.topping_name as varchar) as exclusion_topping
FROM customer_orders co
CROSS APPLY string_split(co.exclusions_new,',') as exclusion_ingredient
JOIN pizza_toppings pt
ON exclusion_ingredient.value = pt.topping_id
) as exclsuion_name_2
),
--extra_table
extra_table AS
(
SELECT DISTINCT order_id, pizza_id, topping_id, substring(
(
SELECT distinct extra_topping + ', ' as [text()]
FROM 
(
SELECT co.order_id, co.pizza_id, pt.topping_id, cast(pt.topping_name as varchar) as extra_topping
FROM customer_orders co
CROSS APPLY string_split(co.extras_new,',') as extra_ingredient
JOIN pizza_toppings pt
ON extra_ingredient.value = pt.topping_id
) as extra_name_1
WHERE extra_name_1.order_id = extra_name_2.order_id
FOR XML PATH('')
),1,1000) as extra_topping
FROM 
(
SELECT co.order_id, co.pizza_id, pt.topping_id, cast(pt.topping_name as varchar) as extra_topping
FROM customer_orders co
CROSS APPLY string_split(co.extras_new,',') as extra_ingredient
JOIN pizza_toppings pt
ON extra_ingredient.value = pt.topping_id
) as extra_name_2
)
SELECT distinct co.order_id,
CONCAT(CASE WHEN p.pizza_name LIKE 'Meatlovers' THEN 'Meat Lovers' ELSE p.pizza_name END, 
	' - Exclude ' + exc.exclusion_topping, ' - Extra ' + ext.extra_topping) as order_detail
FROM customer_orders co
LEFT JOIN exclusion_table exc ON co.order_id = exc.order_id AND co.pizza_id = exc.pizza_id 
LEFT JOIN extra_table ext ON co.order_id = ext.order_id AND co.pizza_id = ext.pizza_id 
INNER JOIN pizza_names p ON co.pizza_id = p.pizza_id

--5. Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
--	For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
WITH Excluded AS
(
SELECT co.order_id, 
co.pizza_id,
co.exclusions_new,
pt.topping_id, 
cast(pt.topping_name as varchar) as exclusion_topping
FROM customer_orders co
CROSS APPLY string_split(co.exclusions_new,',') as exclusion_ingredient
JOIN pizza_toppings pt ON exclusion_ingredient.value = pt.topping_id
JOIN pizza_names pn ON pn.pizza_id = co.pizza_id
),
Extras AS
(
SELECT co.order_id, co.pizza_id, co.extras_new, pt.topping_id, cast(pt.topping_name as varchar) as extra_topping
FROM customer_orders co
CROSS APPLY string_split(co.extras_new,',') as extra_ingredient
JOIN pizza_toppings pt
ON extra_ingredient.value = pt.topping_id
), 
Ordered AS
(
SELECT co.order_id, 
co.pizza_id,
pt.topping_id,
pt.topping_name
FROM customer_orders co
JOIN pizza_recipes pr ON co.pizza_id = pr.pizza_id
CROSS APPLY string_split(cast(pr.toppings as varchar),',') as topping_name
JOIN pizza_toppings pt
ON topping_name.value = pt.topping_id
),
ORDER_WITH_EXCLUDED_AND_EXTRAS AS
(
SELECT o.order_id, o.pizza_id, o.topping_id, o.topping_name
FROM Ordered o
LEFT JOIN Excluded exc ON exc.order_id = o.order_id AND exc.pizza_id = o.pizza_id AND exc.topping_id = o.topping_id
WHERE exc.topping_id is NULL

UNION ALL

SELECT ext.order_id, ext.pizza_id, ext.topping_id, ext.extra_topping
FROM Extras ext
)
SELECT oee.order_id, oee.pizza_id, oee.topping_id, cast(pn.pizza_name as varchar) as name_of_pizza, cast(oee.topping_name as varchar) as toppings,
COUNT(cast(oee.topping_name as varchar)) as N
FROM ORDER_WITH_EXCLUDED_AND_EXTRAS oee
INNER JOIN pizza_names pn ON oee.pizza_id = pn.pizza_id
GROUP BY oee.order_id, oee.pizza_id, oee.topping_id, cast(pn.pizza_name as varchar), cast(oee.topping_name as varchar)
ORDER BY oee.order_id, oee.pizza_id, oee.topping_id

--D. Pricing and Ratings Solutions

--1. If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - 
--how much money has Pizza Runner made so far if there are no delivery fees?
WITH CTE AS (SELECT pizza_id, 
                    pizza_name,
                    CASE WHEN pizza_name = 'Meatlovers' THEN 12
                      ELSE 10 END AS pizza_cost
             FROM pizza_names) 

SELECT SUM(pizza_cost) as total_revenue
FROM customer_orders c 
JOIN runner_orders r ON c.order_id = r.order_id
JOIN CTE c2 ON c.pizza_id = c2.pizza_id
WHERE r.cancellation_new is NULL
--2. What if there was an additional $1 charge for any pizza extras? (Add cheese is $1 extra)
WITH pizza_cte AS
          (SELECT 
                  (CASE WHEN pizza_id=1 THEN 12
                        WHEN pizza_id = 2 THEN 10
                        END) AS pizza_cost, 
                  c.exclusions_new,
                  c.extras_new
          FROM runner_orders r
          JOIN customer_orders c ON c.order_id = r.order_id
          WHERE r.cancellation_new IS  NULL
          )
SELECT 
      SUM(CASE WHEN extras_new IS NULL THEN pizza_cost
               WHEN DATALENGTH(extras_new) = 1 THEN pizza_cost + 1
               ELSE pizza_cost + 2
                END ) AS total_earn
FROM pizza_cte;
--3. The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, 
--how would you design an additional table for this new dataset - 
--generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.
DROP TABLE IF EXISTS ratings
CREATE TABLE ratings 
 (order_id INTEGER,
    rating INTEGER);
INSERT INTO ratings
 (order_id ,rating)
VALUES 
(1,3),
(2,4),
(3,5),
(4,2),
(5,1),
(6,3),
(7,4),
(8,1),
(9,3),
(10,5); 

SELECT * 
from ratings
--4. Using your newly generated table - 
--can you join all of the information together to form a table which has the following information for successful deliveries?
SELECT customer_id , 
        c.order_id, 
        runner_id, 
        rating, 
        order_time, 
        pickup_time_new, 
        datepart( minute,pickup_time_new - order_time) as Time__order_pickup, 
        r.duration_minutes, 
        round(avg(distance_km/duration_minutes*60),2) as avg_Speed, 
        COUNT(pizza_id) AS Pizza_Count
FROM customer_orders c
LEFT JOIN runner_orders r ON c.order_id = r.order_id 
LEFT JOIN ratings r2 ON c.order_id = r2.order_id
WHERE r.cancellation_new is NULL
GROUP BY customer_id , c.order_id, runner_id, rating, order_time, pickup_time_new, datepart( minute,pickup_time_new - order_time) , r.duration_minutes
ORDER BY c.customer_id
--5. If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - 
--how much money does Pizza Runner have left over after these deliveries?
WITH CTE AS (SELECT c.order_id,
                    SUM(CASE WHEN pizza_name = 'Meatlovers' THEN 12
                          ELSE 10 END) AS pizza_cost
             FROM pizza_names p
             JOIN customer_orders c ON p.pizza_id =c.pizza_id
             GROUP BY c.order_id) 

SELECT SUM(pizza_cost) AS revenue, 
       SUM(distance_km) *0.3 as total_cost,
       SUM(pizza_cost) - SUM(distance_km)*0.3 as profit
FROM runner_orders r 
JOIN CTE c ON R.order_id =C.order_id
WHERE r.cancellation_new is NULL