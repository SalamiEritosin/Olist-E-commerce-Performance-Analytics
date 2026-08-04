
-- --------------------------------------------
-- product performance and review
-- --------------------------------------------

-- top 10 best selling product ----------------

select
product_category_name,
count(oi.order_id) as units_sold,
count(distinct oi.order_id) as orders
from olist_products_dataset p
join olist_order_items_dataset oi on p.product_id = oi.product_id
join olist_orders_dataset o on oi.order_id = o.order_id
where order_status = 'Delivered'
group by product_category_name
order by units_sold desc
limit 10;


-- top 10 low selling product ---------------------

select
product_category_name,
count(oi.order_id) as units_sold,
count(distinct oi.order_id) as orders
from olist_products_dataset p
join olist_order_items_dataset oi on p.product_id = oi.product_id
join olist_orders_dataset o on oi.order_id = o.order_id
where order_status = 'Delivered'
group by product_category_name
order by units_sold asc
limit 10;


-- top 10 product category by revenue ----------------------

select
product_category_name,
sum(oi.price) as revenue
from olist_products_dataset p
join olist_order_items_dataset oi on p.product_id = oi.product_id
join olist_orders_dataset o on oi.order_id = o.order_id
where order_status = 'Delivered'
group by product_category_name
order by sum(oi.price) desc
limit 10;


-- average review score ------------------------------------

select
round(avg(r.review_score), 2) as avg_review_score,
count(r.order_id) as total_review_count,
min(r.review_score) as min_review_score,
max(r.review_score) as max_review_score
from olist_order_reviewss_dataset r
join olist_orders_dataset o on r.order_id = o.order_id
where order_status = 'Delivered';


-- review score distribution -------------------------------

select
r.review_score,
count(*) as review_count,
round(count(*) * 100 / sum(count(*)) over(), 2)  as review_pct
from olist_order_reviewss_dataset r
join olist_orders_dataset o on r.order_id = o.order_id
where order_status = 'Delivered'
group by r.review_score
order by review_pct desc;


-- average review score by region ----------------------------

select 
customer_state,
round(avg(r.review_score), 2) as avg_review_score,
min(r.review_score) as min_score,
max(r.review_score) as max_score
from olist_customers_dataset c
join olist_orders_dataset o on c.customer_id = o.customer_id
join olist_order_reviewss_dataset r on o.order_id = r.order_id
where order_status = 'Delivered'
group by customer_state
order by avg_review_score desc;


-- average review score by product category -------------------

select 
product_category_name,
round(avg(r.review_score), 2) as avg_review_score,
min(r.review_score) as min_score,
max(r.review_score) as max_score
from olist_products_dataset p
join olist_order_items_dataset oi on p.product_id = oi.product_id
join olist_order_reviewss_dataset r on oi.order_id = r.order_id
join olist_orders_dataset o on r.order_id = o.order_id
where order_status = 'Delivered'
group by product_category_name
order by avg_review_score desc;


-- cause of 1 review score ------------
select
c.customer_id,
c.customer_state,
price,
product_category_name,
count(distinct oi.order_id) as orders,
count(oi.order_item_id) as qty,
datediff(order_estimated_delivery_date, order_delivered_customer_date) as h
from olist_customers_dataset c
join olist_orders_dataset o on c.customer_id = o.customer_id
join olist_order_reviewss_dataset r on o.order_id = r.order_id
join olist_order_items_dataset oi on r.order_id = oi.order_id
join olist_products_dataset p on oi.product_id = p.product_id
where order_status = 'Delivered'
and review_score = 1
group by c.customer_id, c.customer_state, h, price, product_category_name order by h desc;

