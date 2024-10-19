
How to upload a table in bigquery:
dim_bad_actors
uri = https://drive.google.com/open?id=1Aygwiu7GAKI34S6e6tG5RfeylanwpDCH 


dim_users
uri = https://drive.google.com/open?id=1653619imH4Qir1hSzDLyiygMWTzTIvCn  

agg_profile_views
uri = https://drive.google.com/open?id=1dAUzZr_H2X-YsS5lPBvQMOHv4TRCBTuR


## CREATE TABLE DIM CALENDAR
CREATE OR REPLACE  TABLE my-project-1521679904591.down.dim_calendar 
AS ( 
SELECT
  date,
  FORMAT_DATE("%A", date) as weekday,
  EXTRACT(DAY FROM date) as day,
  EXTRACT(MONTH FROM date) as month,
  EXTRACT(YEAR FROM date) AS year,
  FORMAT_DATE("%b", date) as month_name,
  FORMAT_DATE("%B", date) as month_name_full,
  EXTRACT(WEEK FROM date) AS week,
  FORMAT_DATE("%Y%m", date) as date_YYYYMM,
  FORMAT_DATE("%m-%Y", date) as date_MM_YYYY
FROM UNNEST(GENERATE_DATE_ARRAY('2012-12-14', '2024-08-31')) AS Date
ORDER BY date)



## CREATE TABLE UNIQUE USERS: view users table goes from 230768 to 174,494
CREATE TEMP FUNCTION most_frequent_value(arr ANY TYPE) AS ((
  SELECT x 
  FROM UNNEST(arr) x
  GROUP BY x
  ORDER BY COUNT(1) DESC
  LIMIT 1  
));


CREATE OR REPLACE TABLE `my-project-1521679904591.down.dim_unique_users` 
AS (
SELECT  user_id, 
CASE WHEN COUNT(DISTINCT DATE(created_at))>1 THEN TRUE ELSE FALSE END reactivated_user,
MIN(DATE(created_at)) created_at,
most_frequent_value(ARRAY_AGG(gender)) gender
FROM `my-project-1521679904591.down.dim_users` 
WHERE user_id not in (SELECT * FROM  `my-project-1521679904591.down.dim_bad_actors`)
  AND created_at < '2024-09-01'
GROUP BY  user_id 
);



CREATE OR REPLACE TABLE `my-project-1521679904591.down.dashboard_input` 
AS 
-- This table brings all the interactions between users independent of the search filter
-- I'm going to use this table to check if the view is part of an interaction or not (both profiles view each other)

WITH interactions AS (
SELECT --ds,
  viewed_user_id,
  user_id,
  SUM(cnt) AS interactions
FROM `my-project-1521679904591.down.agg_profile_views` 
WHERE 1=1
  -- exclude bad actors
  AND user_id not in (SELECT * FROM  `my-project-1521679904591.down.dim_bad_actors`)
  AND viewed_user_id not in (SELECT * FROM  `my-project-1521679904591.down.dim_bad_actors`)
GROUP BY 1,2--,3
),

-- in this table brings all the views that a user receives and if it is part of an interaction or not
exposures as (
SELECT exp.ds,
  exp.viewed_user_id AS exposed_user_id,
  CASE WHEN exp.filter_type in ('nearby','3some','hot') THEN INITCAP(exp.filter_type)
      WHEN exp.filter_type in ('los_angeles_ca','new_york_ny', 'dallas_tx', 'chicago_il') then 'City/State'
      ELSE  'Other'
    END AS filter_type,
  exp.user_id AS viewer_user_id,
  CASE WHEN int.interactions IS NOT NULL THEN TRUE 
    ELSE FALSE END AS interaction,
  exp.cnt AS profile_views_received,
  COALESCE(int.interactions,0) AS count_interactions
FROM `my-project-1521679904591.down.agg_profile_views` exp
LEFT JOIN interactions int 
  ON --exp.ds = int.ds AND
     exp.viewed_user_id = int.user_id AND
     exp.user_id = int.viewed_user_id 
WHERE 1=1
  -- exclude bad actors
  AND exp.user_id not in (SELECT * FROM  `my-project-1521679904591.down.dim_bad_actors`)
  AND exp.viewed_user_id not in (SELECT * FROM  `my-project-1521679904591.down.dim_bad_actors`)
)
--final table
SELECT exp.ds,
  exp.exposed_user_id, 
  exp.filter_type,
  exp.viewer_user_id,
  exp.interaction,
  exp.profile_views_received,
  exp.count_interactions,
  INITCAP(eu.gender) as exposed_gender,
  eu.created_at as exposed_user_creation,
  date_diff(ds, eu.created_at, DAY) exposed_days_since_sign_up, 
  eu.reactivated_user exposed_reactivated_user,
  CASE WHEN date_diff(ds, eu.created_at, DAY) < 7 THEN True ELSE False END AS exposed_new_user,
  INITCAP(vu.gender) as viewer_gender,
  vu.created_at as viewer_user_creation,
  CASE WHEN date_diff(ds, vu.created_at, DAY) < 7 THEN True ELSE False END AS viewer_new_user,
  cal.weekday,
  cal.day
FROM exposures exp
-- exposed user information
INNER JOIN  `my-project-1521679904591.down.dim_unique_users` eu on eu.user_id = exp.exposed_user_id
-- viewer user information
LEFT JOIN  `my-project-1521679904591.down.dim_unique_users` vu on vu.user_id = exp.viewer_user_id
INNER JOIN  `my-project-1521679904591.down.dim_calendar` cal on exp.ds = cal.date
where 1=1
and  date_diff(ds, eu.created_at, DAY) >= 0
and eu.gender <> 'Other'
and vu.gender <> 'Other'
--and  vw.user_id = 'Ks62zNn0urcj8a4Gv6fvIPn5mr+PMNKfUdLPKEWoM3Y='
--and  vw.viewed_user_id = 'CDwB+WW4GAYq973aGyVTi1VruIqqDbbJ0hgplxOhNx4='
;
