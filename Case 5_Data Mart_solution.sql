--A. Data Cleansing Steps

--In a single query, perform the following operations and generate a new table in the data_mart schema named clean_weekly_sales:
-- Convert the week_date to a DATE format
-- Add a week_number as the second column for each week_date value, for example any value from the 1st of January to 7th of January will be 1, 8th to 14th will be 2 etc
-- Add a month_number with the calendar month for each week_date value as the 3rd column
-- Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values
-- Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value
-- Add a new demographic column using the following mapping for the first letter in the segment values
-- Ensure all null string values with an "unknown" string value in the original segment column as well as the new age_band and demographic columns
-- Generate a new avg_transaction column as the sales value divided by transactions rounded to 2 decimal places for each record
DROP TABLE IF EXISTS clean_weekly_sales;

SELECT CONVERT(date, week_date,3) as week_date,
        DATEPART(week,CONVERT(date,week_date,3)) as week_number, 
        DATEPART(month,CONVERT(date,week_date,3)) as month_number,
        DATEPART(year,CONVERT(date,week_date,3)) as calendar_year,
        CASE WHEN SUBSTRING(segment,2,1) = '1' THEN 'Young Adults'
            WHEN SUBSTRING(segment,2,1) = '2' THEN  'Middle Aged'
            WHEN SUBSTRING(segment,2,1) = '3' or SUBSTRING(segment,1,1) = '4' THEN 'Retirees'
            ELSE 'unknown' 
            END AS age_band ,
        CASE WHEN SUBSTRING(segment,1,1) = 'C' THEN 'Couples'
            WHEN SUBSTRING(segment,1,1) = 'F' THEN 'Families'
            ELSE 'unknown'
            END AS demographic,
        region,
        platform,
        customer_type,
        transactions,
        sales,
        cast (cast(sales as float)/transactions as decimal(10,2)) as avg_transaction 
INTO clean_weekly_sales
FROM weekly_sales;

--B. Data Exploration

SELECT * FROM weekly_sales
--1. What day of the week is used for each week_date value?
SELECT DISTINCT DATENAME(WEEKDAY,week_date) AS week_day
FROM clean_weekly_sales;
--2. What range of week numbers are missing from the dataset?
WITH numbers_week AS (
      SELECT 52 as week_number_year
      UNION all
      SELECT week_number_year - 1
      FROM numbers_week
      WHERE week_number_year > 1
     ),

WEEK_data as (
    SELECT DISTINCT week_number
    FROM clean_weekly_sales)

SELECT COUNT(*) AS missing_weeks
FROM numbers_week w1 
LEFT JOIN WEEK_data w2 ON w1.week_number_year = w2.week_number
WHERE week_number is NULL;
--3. How many total transactions were there for each year in the dataset?
SELECT DISTINCT calendar_year, 
        SUM(transactions) AS total_transaction
FROM clean_weekly_sales
GROUP BY calendar_year;
--4. What is the total sales for each region for each month?
ALTER TABLE clean_weekly_sales
ALTER COLUMN sales BIGINT 

SELECT  region,
        month_number,
        SUM (sales) AS total_sales
FROM clean_weekly_sales
GROUP BY region,month_number
ORDER BY region,month_number
--5. What is the total count of transactions for each platform
SELECT platform,
        COUNT(transactions) as total_transaction
FROM clean_weekly_sales
GROUP BY platform
--6. What is the percentage of sales for Retail vs Shopify for each month?
SELECT DISTINCT platform,  
        calendar_year,
        month_number,
        SUM(sales) OVER (PARTITION BY month_number,calendar_year,platform order by platform  ) as sale_monthly,
        100 * CAST(SUM(sales) OVER (PARTITION BY month_number,calendar_year,platform order by platform  ) AS FLOAT)  
            /  (SUM(sales) OVER (PARTITION BY calendar_year,platform order by platform  )) AS Percent_sales_monthly
FROM clean_weekly_sales
order by platform,calendar_year,month_number;
--7. What is the percentage of sales by demographic for each year in the dataset?
SELECT DISTINCT demographic,
        calendar_year,
        SUM(sales) OVER (PARTITION BY calendar_year, demographic order by demographic) AS total_sale,
        100 * CAST(SUM(sales) OVER (PARTITION BY calendar_year, demographic order by demographic) AS FLOAT)
        /  SUM(sales) OVER (PARTITION BY calendar_year) AS percent_sale
FROM clean_weekly_sales
ORDER BY demographic, calendar_year;
--8. Which age_band and demographic values contribute the most to Retail sales?
SELECT DISTINCT age_band, 
        demographic,
        SUM(sales) OVER (PARTITION BY age_band,demographic) as total_sale,
        100 * CAST(SUM(sales) OVER (PARTITION BY age_band,demographic) AS FLOAT)
        / (SELECT SUM(sales) from clean_weekly_sales) AS percent_sale
FROM clean_weekly_sales
ORDER BY percent_sale DESC;
--9. Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?
SELECT platform, 
        calendar_year, 
        AVG(avg_transaction) as avg_transaction_row,
        SUM(sales) / sum(transactions) AS avg_transaction_group
FROM clean_weekly_sales
GROUP BY platform, calendar_year
ORDER BY platform,calendar_year;

--C. Before & After Analysis

-- This technique is usually used when we inspect an important event and want to inspect the impact before and after a certain point in time.
-- Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart sustainable packaging changes came into effect.
-- We would include all week_date values for 2020-06-15 as the start of the period after the change and the previous week_date values would be before
-- Using this analysis approach - answer the following questions:

--1. What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?
SELECT  DISTINCT week_number
FROM clean_weekly_sales
WHERE week_date = '2020-06-15';

WITH CTE AS (
        SELECT 
                SUM (CASE WHEN week_number BETWEEN 21 AND 24 THEN sales END) AS before_change,
                SUM (CASE WHEN week_number BETWEEN 25 AND 28 THEN sales END) AS after_change
        FROM clean_weekly_sales
        WHERE calendar_year = '2020' 
                AND week_number BETWEEN 21 AND 28
                )

SELECT *, 
        (after_change - before_change ) AS sale_change,
        100 * (cast(after_change as float) - before_change) / before_change as rate_change
FROM CTE ;
--2. What about the entire 12 weeks before and after?
WITH CTE AS (
        SELECT 
                SUM (CASE WHEN week_number BETWEEN 13 AND 24 THEN sales END) AS before_change,
                SUM (CASE WHEN week_number BETWEEN 25 AND 36 THEN sales END) AS after_change
        FROM clean_weekly_sales
        WHERE calendar_year = '2020' 
                AND week_number BETWEEN 13 AND 36
                )

SELECT *, 
        (after_change - before_change ) AS sale_change,
        100 * (cast(after_change as float) - before_change) / before_change as rate_change
FROM CTE ;
--3. How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
--Part 1: How do the sale metrics for 4 weeks before and after compare with the previous years in 2018 and 2019?
WITH CTE_4w AS (SELECT calendar_year,
                      SUM (CASE WHEN week_number BETWEEN 21 AND 24 THEN sales END) AS before_change_4_week,
                      SUM (CASE WHEN week_number BETWEEN 25 AND 28 THEN sales END) AS after_change_4_week,
                      SUM (CASE WHEN week_number BETWEEN 13 AND 24 THEN sales END) AS before_change_12_week,
                      SUM (CASE WHEN week_number BETWEEN 25 AND 36 THEN sales END) AS after_change_12_week
                FROM clean_weekly_sales
                GROUP BY calendar_year)

SELECT calendar_year,
        before_change_4_week,
        after_change_4_week,
        (after_change_4_week - before_change_4_week ) AS sale_change_4w,
        round(100 * (cast(after_change_4_week as float) - before_change_4_week) / before_change_4_week,2) as rate_change_4w
FROM CTE_4w
order by calendar_year;
--Part 2: How do the sale metrics for 12 weeks before and after compare with the previous years in 2018 and 2019?
WITH CTE_12w AS (SELECT calendar_year,
                        SUM (CASE WHEN week_number BETWEEN 13 AND 24 THEN sales END) AS before_change_12_week,
                        SUM (CASE WHEN week_number BETWEEN 25 AND 36 THEN sales END) AS after_change_12_week
                FROM clean_weekly_sales
                GROUP BY calendar_year)

SELECT calendar_year,
        before_change_12_week,
        after_change_12_week,
        (after_change_12_week - before_change_12_week ) AS sale_change_12w,
        round(100 * (cast(after_change_12_week as float) - before_change_12_week) / before_change_12_week,2) as rate_change_12w
FROM CTE_12w
order by calendar_year;