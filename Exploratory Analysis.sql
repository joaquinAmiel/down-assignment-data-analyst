## top expose users
SELECT viewed_user_id, count(distinct user_id) 
FROM `my-project-1521679904591.down.agg_profile_views` 
group by viewed_user_id 
order by 2 desc
LIMIT 10
;



## Top viewer users
SELECT  user_id, count(*) 
FROM `my-project-1521679904591.down.agg_profile_views` 
group by  user_id 
order by 2 desc
LIMIT 10
;


## filter_type categories analysis (how the user is found)
WITH aux AS (
SELECT filter_type, COUNT(DISTINCT user_id) unique_users, 
count(*) as table_rows, 
Round(count(*)/COUNT(DISTINCT user_id),2)  as ratio 
FROM `my-project-1521679904591.down.agg_profile_views` 
GROUP BY filter_type 
ORDER BY 2 DESC)

SELECT *, 
  ROUND(
    100.0 * SUM(table_rows) OVER(PARTITION BY filter_type) / 
    SUM(table_rows) OVER()
    ,1) 
    AS rows_perc, 
  ROUND(
    100.0 * SUM(table_rows) OVER (ORDER BY table_rows desc ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) / 
    SUM(table_rows) OVER()
    ,1) 
    AS rows_cummulative_perc,
SUM(table_rows) OVER() total_rows
FROM aux
ORDER BY 3 DESC;


## study of count/ interations
SELECT 
  vw.user_id,
  vw.viewed_user_id,
  filter_type,
  sum(cnt),
  count(cnt)
FROM `my-project-1521679904591.down.agg_profile_views` vw
group by 1,2,3
order by 5 desc;

SELECT *
FROM `my-project-1521679904591.down.agg_profile_views` 
where 1=1
and  user_id = 'eUGMGDNP+sug1jJ0/7+Q2d6mbh3uD7ceVWpKenha8LQ='
and viewed_user_id = '+RjXurKChswfGXO24P2Q3pP9BaMkV8+yWB+ChylX4wY='
;

## time window checking
SELECT min(created_at), max(created_at)
FROM `my-project-1521679904591.down.dim_unique_users`
;

SELECT min(ds), max(ds)
FROM `my-project-1521679904591.down.agg_profile_views`
;


## Define how many days a user can be classified as is a new user
WITH users as (
SELECT user_id, created_at, COUNT(DISTINCT user_id) over() total_users
FROM `my-project-1521679904591.down.dim_unique_users`
WHERE created_at between '2024-08-01'and  '2024-08-02')

SELECT date_diff(ds, created_at, DAY) days_since_creation, 
COUNT(DISTINCT u.user_id) active_users, 
COUNT(DISTINCT u.user_id)/AVG(total_users) active_users_perc, 
SUM(cnt) profile_views,
SUM(cnt)/COUNT(DISTINCT u.user_id) views_per_user
FROM `my-project-1521679904591.down.agg_profile_views` vw
JOIN users u using(user_id)
WHERE 1=1
and date_diff(ds, created_at, DAY)>=0 
--and user_id = 'AK8KvVnMNDPrz2IFkx4RFWRDuUCzr+hZz1JJwsE0fwc='
GROUP BY 1
ORDER BY 1
; 

---exposed users
SELECT COUNT(DISTINCT user_id) new_user,
COUNT(DISTINCT CASE WHEN user_id in (SELECT DISTINCT  viewed_user_id FROM `my-project-1521679904591.down.agg_profile_views`) THEN user_id ELSE NULL END) user_viewed, 
COUNT(DISTINCT CASE WHEN user_id in (SELECT DISTINCT   user_id FROM `my-project-1521679904591.down.agg_profile_views`) THEN user_id ELSE NULL END) user_viewer
FROM `my-project-1521679904591.down.dim_unique_users` 
WHERE 1=1
  -- exclude bad actors
  AND user_id not in (SELECT * FROM  `my-project-1521679904591.down.dim_bad_actors`)
  AND created_at between '2024-08-01' and '2024-08-13'

