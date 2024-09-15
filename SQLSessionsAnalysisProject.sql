/*
Расчет продуктовых метрик и когортный анализ retention для онлайн магазина в PostgreSQL
Навыки: Joins, CTE's, Window Functions, Aggregate Functions, Creating Views, Converting Data Types

*/
-- Создаем таблицу с необходимой структурой
CREATE TABLE sessions (
event_time TIMESTAMP WITH TIME ZONE,
event_type VARCHAR,
product_id VARCHAR,
category_id VARCHAR,
category_code VARCHAR,
brand VARCHAR,
price REAL,
user_id VARCHAR,
user_session PRIMARY KEY 
)
--проверяем наличие пустых значений
SELECT * FROM sessions
WHERE  category_id IS NULL OR
               event_type IS NULL OR 
               product_id IS NULL OR
               category_id IS NULL OR
               user_id IS NULL OR
               user_session IS NULL
--Считаем для скольки дней из каждого месяца у нас есть данные
SELECT 
    COUNT(DISTINCT to_char(event_time,’YYYY-MM-DD’) ) days_of_month,
    to_char(event_time,’YYYY-MM’) as month
FROM sessions
GROUP BY to_char(event_time,’YYYY-MM’)

--Удаляем данные для сентября и марта, так как только несколько дней из этих месяцев задокументированы и последующий расчет метрик может быть затруднен.

DELETE FROM sessions 
WHERE to_char(event_time,’YYYY-MM’) IN (‘2020-09’,’2021-03’)

--Рассчитываем MAU

SELECT to_char(event_time,’YYYY-MM’) months,
              COUNT(DISTINCT user_id) MAU
FROM sessions
GROUP BY months 

--Рассчитаем также среднее MAU для всего периода

SELECT ROUND(AVG(MAU),2) avg_MAU
FROM (SELECT to_char(event_time, ’YYYY-MM’) months, COUNT(DISTINCT user_id) MAU
             FROM sessions
             GROUP BY months)
--Рассчитываем DAU 
SELECT to_char(event_time,’YYYY-MM-DD’) days,
              COUNT(DISTINCT user_id) DAU
FROM sessions
GROUP BY days 

--Среднее DAU

SELECT ROUND(AVG(DAU),2) avg_DAU
FROM (SELECT to_char(event_time,’YYYY-MM-DD’) days, COUNT(DISTINCT user_id) DAU
            FROM sessions
            GROUP BY days 

--WAU
SELECT DATE_PART('week', event_time) week,
              COUNT(DISTINCT user_id) WAU
FROM sessions
GROUP BY week

--Среднее WAU

SELECT AVG(wau) avg_wau
FROM (
	SELECT DATE_PART('week', event_time) week,
           COUNT(DISTINCT user_id) WAU
    FROM sessions
    GROUP BY week 
)

--расчет sticky factor

with am as (SELECT ROUND(AVG(MAU),2) avg_MAU
            FROM (SELECT to_char(event_time, 'YYYY-MM') months, 
                         COUNT(DISTINCT user_id) MAU 
                  FROM sessions
                  GROUP BY months)

	),

ad as (SELECT ROUND(AVG(DAU),2) avg_DAU
            FROM (SELECT to_char(event_time,'YYYY-MM-DD') days, 
                         COUNT(DISTINCT user_id) DAU 
                  FROM sessions
                  GROUP BY days 
)
     )

SELECT ROUND(avg_dau/avg_mau*100.0,2) sticky_factor
FROM am, ad

--

SELECT product_id,
       ROUND(SUM(price)::numeric, 2) total,
       (SELECT ROUND(SUM(price)::numeric,2) grand_total       
        FROM sessions 
        WHERE event_type = 'purchase')
FROM sessions 
WHERE event_type = 'purchase'
GROUP BY product_id
ORDER BY total DESC

--Посчитаем количество раз каждый продукт был куплен, а также суммарную прибыль для каждого продукта (важно помнить, что для некоторых продуктов сумма покупок может быть нулевой, поэтому необходимо применить JOIN cо списком id всех продуктов)

CREATE VIEW rev_per_product as (
with purchase_counts as (
             SELECT
                 product_id,
                 COUNT(event_type) purchase_count,
	             SUM(price) rev_per_product
             FROM
                 sessions
             WHERE event_type = 'purchase'
             GROUP BY
                 product_id
)

SELECT all_ids.product_id,
       COALESCE(purchase_count,0) purchase_count,
	   COALESCE(rev_per_product,0) rev_per_product
FROM 
	(SELECT DISTINCT product_id FROM sessions ) all_ids 
LEFT JOIN 
	purchase_counts ON all_ids.product_id = purchase_counts.product_id
ORDER BY rev_per_product desc
)

--Проведем ABC анализ 

CREATE VIEW abc_class as (
 with rev as (
       SELECT product_id,   
              total,
       (SELECT ROUND(SUM(price)::numeric, 2)
        FROM sessions 
        WHERE event_type = 'purchase') grand_total 
FROM rev_per_product 
)

SELECT *,
	   CASE 
          WHEN roll_sum >= 0 AND roll_sum < 51 THEN 'A'
          WHEN roll_sum >= 51 AND roll_sum < 81 THEN 'B'
          WHEN roll_sum >= 81 AND roll_sum <= 100 THEN 'C'
       END ABC
FROM (
       SELECT *,
              total/grand_total*100 total_rev_percent,
	          SUM( total/grand_total*100) over(ORDER BY total DESC) roll_sum
       FROM rev
	 )
)

--рассчитаем прибыль в месяц для каждого продукта

 CREATE VIEW monthly_rev_per_product as (
with month_product_rev as (
	SELECT to_char(event_time,'YYYY-MM') months,
       product_id,
       SUM(price) months_total  
    FROM sessions 
    WHERE event_type='purchase'
    GROUP BY product_id, months
    ORDER BY product_id,months
)

SELECT pm.product_id,
	   pm.months,
       COALESCE(months_total,0) months_total
FROM (  (SELECT DISTINCT product_id FROM sessions)     
       CROSS JOIN
        (SELECT DISTINCT to_char(event_time,'YYYY-MM') months       
         FROM sessions)
	) pm
       LEFT JOIN month_product_rev mpr ON pm.product_id=mpr.product_id AND pm.months=mpr.months  
ORDER BY pm.product_id, pm.months
)

--проведем XYZ анализ 

CREATE VIEW xyz_class as(
with cf as (
	SELECT product_id,
	   STDDEV(months_total),
	   AVG(months_total),
	   CASE WHEN AVG(months_total)=0 THEN NULL
	        ELSE STDDEV(months_total)/AVG(months_total)*100 
    	END cf
     FROM monthly_rev_per_product 
     GROUP BY product_id
     order by cf 
)

SELECT *,
       CASE WHEN cf>=0 AND cf<=10 THEN 'x'
            WHEN cf>10 AND cf<=25 THEN 'y'
            WHEN cf>25 OR cf is NULL THEN 'z'
	   END XYZ
FROM cf
)

--соединим результаты и сохраним их в таблицу для дальнейшего анализа будущем 

CREATE TABLE abc_xyz_class as(
SELECT a.product_id,
       ABC,
       XYZ
FROM abc_class a JOIN xyz_class x ON a.product_id=x.product_id
ORDER BY abc, xyz asc
)

-- в заключении проведем когортный анализ retention

with days_from_entry as (
	SELECT event_time::date, 
	       user_id,
	       to_char(event_time,'YYYY-MM') cohort,
           min(event_time::date) over(partition by user_id) first_entry,
	      (event_time::date - min(event_time::date) over(partition by user_id)) diff           
    FROM sessions    
    ORDER BY event_time
),

diff_count as (
	SELECT  diff,
	        cohort,
            COUNT(DISTINCT user_id)cnt
    FROM days_from_entry
    GROUP BY cohort, diff
),

retention as (
	SELECT diff,
	       cohort,
           cnt*1.0/(first_value(cnt) over (partition by cohort order by diff)) rt
FROM diff_count
)

SELECT cohort,
	   sum(rt)  retention_by_cohort
FROM retention 
GROUP BY cohort
