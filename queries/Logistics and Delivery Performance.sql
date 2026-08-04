
-- ----------------------------------------------------------------------------
-- logistics and delivery performnace
-- ----------------------------------------------------------------------------

-- total freight value, gross merchandise value, total order, total sellers  ----------

select 
sum(oi.freight_value) as total_freight_value
from olist_order_items_dataset oi
join olist_orders_dataset o on oi.order_id = o.order_id
where order_status = 'Delivered';

-- gmv -------
select 
sum(freight_value) as gross_merchandise_value
from olist_order_items_dataset;

-- total orders ----
select 
count(order_id) as total_orders from olist_orders_dataset;

-- total sellers -----
select 
count(distinct seller_id) as seller_count
from olist_sellers_dataset;


-- on-time delivery rate --------------------------

select
count(order_id) as total_delivered_orders,
count((case when order_delivered_customer_date <= order_estimated_delivery_date then 1 end)) as on_time_delivery,
count((case when order_delivered_customer_date > order_estimated_delivery_date then 1 end)) as late_delivery,
round((count((case when order_delivered_customer_date <= order_estimated_delivery_date then 1 end)) * 100) / count(order_id), 2) as on_time_delivery_rate
from olist_orders_dataset where order_status = 'Delivered'
and order_delivered_customer_date != 'n/a';


-- delivery time distribution -------------------------------

with delivery_dayss as(
select 
datediff(order_delivered_customer_date, order_purchase_timestamp) as delivery_days
from olist_orders_dataset where order_status = 'Delivered'
and order_delivered_customer_date != 'n/a'),

delivery_category as(
select 
delivery_days,
case when delivery_days between 0 and 3 then 'very fast (0 - 3 days)'
when delivery_days between 4 and 7 then 'fast (4 - 7 days)'
when delivery_days between 8 and 14 then 'normal (8 - 14 days)'
when delivery_days between 15 and 21 then 'slow (15 - 21 days)'
when delivery_days between 22 and 30 then 'very slow (22 - 30 days)'
else 'extreme delay (above 30 days)' end as delivery_speed
from delivery_dayss)

select 
delivery_speed,
count(delivery_speed) as orders_delivered,
round((count(delivery_speed) * 100) / sum(count(delivery_speed)) over (), 2) as delivery_time_distribution_in_pct
from delivery_category
group by delivery_speed order by delivery_time_distribution_in_pct desc;


-- regional delivery performance -----------------------------------

select
c.customer_state,
count(order_id) as orders,
round(avg(datediff(order_delivered_customer_date, order_purchase_timestamp)), 2) as avg_delivery_days,
min(datediff(order_delivered_customer_date, order_purchase_timestamp)) as min_delivery_days,
max(datediff(order_delivered_customer_date, order_purchase_timestamp)) as max_delivery_days,
round(avg(datediff(order_estimated_delivery_date, order_delivered_customer_date)), 2) as avg_days_vs_estimated,
count(case when order_delivered_customer_date > order_estimated_delivery_date then 1 end) as late_deliveries,
round((count(case when order_delivered_customer_date > order_estimated_delivery_date then 1 end) * 100) / count(*), 2) as late_delivery_rate
from olist_customers_dataset c 
join olist_orders_dataset o on c.customer_id = o.customer_id
where order_status = 'Delivered' and order_delivered_customer_date != 'n/a'
group by customer_state order by avg_delivery_days;


-- delivery time vs customer satisfaction -----------------------------------

select 
case when datediff(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 3 then 'very fast (0 - 3 days)'
when datediff(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 7 then 'fast (4 - 7 days)'
when datediff(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 14 then 'normal (8 - 14 days)'
when datediff(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 21 then 'slow (15 - 21 days)'
when datediff(o.order_delivered_customer_date, o.order_purchase_timestamp) <= 30 then 'very slow (22 - 30 days)'
else 'extreme delay (above 30 days)' end as delivery_speed,
count(distinct o.order_id) as orders,
round(avg(review_score), 2) as avg_review_score,
round(count(case when review_score >= 4 then 1 end) * 100 / count(*), 2) as positive_review_score_pct,
round(count(case when review_score <= 2 then 1 end) * 100 / count(*), 2) as negative_review_score_pct  
from olist_orders_dataset o join olist_order_reviewss_dataset r on o.order_id = r.order_id
where order_status = 'Delivered'
and order_delivered_customer_date != 'n/a'
group by delivery_speed order by avg_review_score desc;


-- delivery time by product category ----------------------------------------------

select 
product_category_name,
count(distinct oi.order_id) as orders,
round(avg(datediff(o.order_delivered_customer_date, o.order_purchase_timestamp)), 2) as avg_delivery_days,
min(datediff(o.order_delivered_customer_date, o.order_purchase_timestamp)) as min_delivery_days,
max(datediff(o.order_delivered_customer_date, o.order_purchase_timestamp)) as max_delivery_days
from olist_products_dataset p
join olist_order_items_dataset oi on p.product_id = oi.product_id
join olist_orders_dataset o on oi.order_id = o.order_id
where order_status = 'Delivered'
and order_delivered_customer_date != 'n/a'
group by product_category_name
order by avg_delivery_days;


-- delivery status distribution ---------------------------------------------------

select 
order_status,
count(order_id) orders,
round(count(order_id) * 100 / sum(count(order_id)) over () , 2) as status_pct
from olist_orders_dataset
group by order_status order by orders desc;


-- freight cost by region ---------------------------------------------------------

select
c.customer_state,
count(distinct oi.order_id) as orders,
round(avg(oi.freight_value), 2) as avg_freight_cost,
sum(oi.freight_value) as total_freight_collected,
max(oi.freight_value) as max_freight,
min(oi.freight_value) as min_freight,
round(avg(oi.price)) as avg_product_price,
round((avg(oi.freight_value) * 100 )/ avg(oi.price), 2) as freight_cost_pct_of_price
from olist_customers_dataset c
join olist_orders_dataset o on c.customer_id = o.customer_id
join olist_order_items_dataset oi on o.order_id = oi.order_id
where order_status = 'Delivered'
group by customer_state order by avg_freight_cost desc;


-- freight cost by category -------------------------------------------------------

select
p.product_category_name,
count(distinct oi.order_id) as orders,
count(oi.order_id) as total_quantity_sold,
round(avg(oi.freight_value), 2) as avg_freight_cost,
sum(oi.freight_value) as total_freight_collected,
max(oi.freight_value) as max_freight,
min(oi.freight_value) as min_freight,
round(avg(oi.price)) as avg_product_price,
round((avg(oi.freight_value) * 100 )/ avg(oi.price), 2) as freight_cost_pct_of_price
from olist_products_dataset p
join olist_order_items_dataset oi on p.product_id = oi.product_id
join olist_orders_dataset o on oi.order_id = o.order_id
where order_status = 'Delivered'
group by product_category_name order by avg_freight_cost desc;


select
c.customer_state,
c.customer_id,
o.order_id,
order_Approved_at, 
order_purchase_timestamp,
order_estimated_delivery_date,
DATEDIFF(order_estimated_delivery_date, order_purchase_timestamp) AS actual_delivery_days,
timestampdiff(minute, order_purchase_timestamp, order_Approved_at) as mindiff
from olist_customers_dataset c
join olist_orders_dataset o on c.customer_id = o.customer_id
where order_status = 'Canceled'
and order_Approved_at !='n/a'
order by actual_delivery_days desc;

