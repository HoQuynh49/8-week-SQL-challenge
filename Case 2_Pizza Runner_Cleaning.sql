--CLEANING TABLE "customer-orders"
--Convert "null" or " " to value which is NULL for the fileds: exclusions & extras

SELECT * 
FROM customer_orders

ALTER TABLE customer_orders
ADD exclusions_new varchar(4);
UPDATE customer_orders
SET exclusions_new = CASE WHEN exclusions = 'null' then NULL
						WHEN exclusions = ' ' then NULL
						ELSE exclusions
						END 

ALTER TABLE customer_orders
ADD extras_new varchar(4);
UPDATE customer_orders
SET extras_new = CASE WHEN extras = 'null' then NULL
						WHEN extras = ' ' then NULL
						ELSE extras
						END 
--Delete unused columns
ALTER TABLE customer_orders
DROP COLUMN exclusions, extras

--CLEANING TABLE "runner_orders"
SELECT * 
FROM runner_orders
--Convert "null" or " " to value which is NULL for the fields: pickup_time, distance, duration, cancellation
ALTER TABLE runner_orders
ADD pickup_time_new varchar(19);
UPDATE runner_orders
SET pickup_time_new = CASE WHEN pickup_time = 'null' then NULL
						ELSE pickup_time
						END 

ALTER TABLE runner_orders
ADD distance_new varchar(7);
UPDATE runner_orders
SET distance_new = CASE WHEN distance = 'null' then NULL
						ELSE distance
						END 

ALTER TABLE runner_orders
ADD duration_new varchar(10);
UPDATE runner_orders
SET duration_new = CASE WHEN duration = 'null' then NULL
						ELSE duration
						END 

ALTER TABLE runner_orders
ADD cancellation_new varchar(23);
UPDATE runner_orders
SET cancellation_new = CASE WHEN cancellation = 'null' then NULL
						WHEN cancellation = ' ' then NULL
						ELSE cancellation
						END 
--Convert "distance_new" and "duration_new" to float
ALTER TABLE runner_orders
ADD distance_km float;

UPDATE runner_orders
SET distance_km = CONVERT(float, REPLACE(distance_new, 'km',''))

ALTER TABLE runner_orders
ADD duration_minutes float;

UPDATE runner_orders
SET duration_minutes = CASE WHEN duration_new like '%minutes' THEN CONVERT(float,REPLACE(duration_new, 'minutes', ''))
						WHEN duration_new like '%minute' THEN CONVERT(float,REPLACE(duration_new, 'minute', ''))
						WHEN duration_new like '%mins' THEN CONVERT(float,REPLACE(duration_new, 'mins', ''))
						ELSE duration_new
						END

--Delete unused columns
ALTER TABLE runner_orders
DROP COLUMN pickup_time, distance, duration, cancellation

ALTER TABLE runner_orders
DROP COLUMN distance_new, duration_new
