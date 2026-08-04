
-- -----------------------------------------
-- sales and revenue performance analysis
-- ----------------------------------------

-- metrics ---------------------------------------------------------------------------------------
-- total_revenue, total_units_sold, total_orders, average_order_value, gross_merchandis_value 
-- -----------------------------------------------------------------------------------------------

with delivered_status_metrics as(
select 
o.customer_id,
count(distinct oi.order_id) as orders,
count(oi.order_id) as units_sold,
sum(oi.price) as order_revenue
from olist_orders_dataset o
join olist_order_items_dataset oi on o.order_id = oi.order_id
where order_status = 'Delivered'
group by o.customer_id)
select 
sum(order_revenue) as total_revenue,
sum(units_sold) as total_units_sold,
sum(orders) as total_orders,
round(sum(order_revenue)/sum(orders), 2) as average_order_value
from delivered_status_metrics;


select
sum(price) as GMV
from olist_order_items_dataset;

-- ---------------------------------------------------
-- monthly revenue trend and growth rate
-- ---------------------------------------------------

with monthly_revenue as(
select
year(o.order_purchase_timestamp) as year,
month(o.order_purchase_timestamp) as month,
monthname(o.order_purchase_timestamp) as month_name,
sum(oi.price) as revenue,
count(distinct o.order_id) as orders
from olist_orders_dataset o
join olist_order_items_dataset oi on o.order_id = oi.order_id
where order_status = 'Delivered'
group by year, month, monthname(o.order_purchase_timestamp)
order by year, month)

select
year,
month,
month_name,
revenue,
orders,
round(revenue / orders, 2) as aov,
lag(revenue) over(partition by year order by year, month) as prev_month_revenue,
round((revenue - (lag(revenue) over(partition by year order by year, month))) * 100 / nullif(lag(revenue) over(partition by year order by year, month),0),2) as mom_growth_rate
from monthly_revenue
order by year, month;

-- ---------------------------------------------------------------------------
-- yearly revenue trend and growth rate
-- ---------------------------------------------------------------------------

with yearly_revenue as(
select
year(o.order_purchase_timestamp) as year,
sum(oi.price) as revenue,
count(distinct o.order_id) as orders,
count(oi.order_id) as units_sold
from olist_orders_dataset o
join olist_order_items_dataset oi on o.order_id = oi.order_id
where order_status = 'Delivered'
group by year(o.order_purchase_timestamp)
order by year(o.order_purchase_timestamp))

select
year,
revenue,
orders,
units_sold,
round((revenue / orders), 2) as avg_order_value,
lag(revenue) over(order by year) as prev_year_revenue,
round((revenue - lag(revenue) over(order by year)) * 100 / nullif(lag(revenue) over(order by year), 0), 2) as yoy_growth_rate
from yearly_revenue
order by year;


-- -----------------------------------------------------------------
-- revenue performance by region
-- -----------------------------------------------------------------

select
c.customer_state,
sum(oi.price) as regional_revenue
from olist_customers_dataset c
join olist_orders_dataset o on c.customer_id = o.customer_id
join olist_order_items_dataset oi on o.order_id = oi.order_id
where order_status = 'Delivered'
group by c.customer_state
order by sum(oi.price) desc;


-- -----------------------------------------------------------------
-- revenue performance by product category
-- -----------------------------------------------------------------

select
p.product_category_name,
sum(oi.price) as revenue
from olist_products_dataset p
join olist_order_items_dataset oi on p.product_id = oi.product_id
join olist_orders_dataset o on oi.order_id = o.order_id
where order_status = 'Delivered'
group by p.product_category_name
order by sum(oi.price) desc;


-- -----------------------------------------------------------------
-- payment method distribution
-- -----------------------------------------------------------------

select
op.payment_type,
count(op.order_id) as usage_count,
round(count(op.order_id) * 100 / sum(count(op.order_id)) over(), 2) as usage_pct
from olist_order_payments_dataset op
join olist_orders_dataset o on op.order_id = o.order_id
where order_status = 'Delivered'
group by op.payment_type
order by count(op.order_id) desc;

-- -----------------------------------------------------------------
-- payment sequential distribution
-- -----------------------------------------------------------------

with checkout_system as(
select
op.order_id,
count(op.order_id) as payment_methods_used,
case when count(op.order_id) = 1 then 'single_payment' else 'multiple_payment' end as checkout_type
from olist_order_payments_dataset op
join olist_orders_dataset o on op.order_id = o.order_id
where order_status = 'Delivered'
group by op.order_id)

select
checkout_type,
count(checkout_type)order_count,
round(count(checkout_type) * 100 / sum(count(checkout_type)) over(), 2) as check_out_rate
from checkout_system
group by checkout_type;


-- -----------------------------------------------------------------
-- payment installment distribution
-- -----------------------------------------------------------------

with installment_type as(
select
payment_installments,
op.order_id,
payment_value,
case when payment_installments = 1 then 'full payment' when payment_installments <= 3 then 'short term payment' 
when payment_installments <= 6 then 'medium term payment' when payment_installments <= 12 then 'long term payment' 
else 'extended payment' end as installment_category
from olist_order_payments_dataset op
join olist_orders_dataset o on op.order_id = o.order_id
where order_status = 'Delivered')

select
installment_category,
count(distinct order_id) as order_count,
round(count(distinct order_id) * 100 / sum(count(distinct order_id)) over(), 2) as installment_distribution_pct,
sum(payment_value) as total_value
from installment_type
group by installment_category
order by installment_distribution_pct desc;


-- ---------------------------------------------------------------------------
-- price vs quantity sold by product category perfromance
-- ---------------------------------------------------------------------------

select
p.product_category_name,
sum(oi.price) as product_revenue,
count(oi.order_id) as product_quantity_sold,
count(distinct oi.order_id) as product_order
from olist_products_dataset p
join olist_order_items_dataset oi on p.product_id = oi.product_id
join olist_orders_dataset o on oi.order_id = o.order_id
where order_status = 'Delivered' 
group by p.product_category_name order by product_revenue desc;

-- --------------------------------------------------------------------------
-- drivers of revenue (price or quantity sold) 
-- --------------------------------------------------------------------------

with category_metrics as(
select
p.product_category_name,
sum(oi.price) as product_revenue,
count(oi.order_id) as product_quantity_sold,
round(avg(oi.price), 2) as avg_price
from olist_products_dataset p
join olist_order_items_dataset oi on p.product_id = oi.product_id
join olist_orders_dataset o on oi.order_id = o.order_id
where order_status = 'Delivered'
group by p.product_category_name
order by sum(oi.price) desc),

median_benchmark_rank as(
select
product_category_name,
product_revenue,
product_quantity_sold,
avg_price,
round(percent_rank() over (order by avg_price), 2) AS price_percentile,
round(percent_rank() over (order by product_quantity_sold), 2) AS volume_percentile
FROM category_metrics
group by product_category_name)

select
product_category_name,
product_revenue,
product_quantity_sold,
avg_price,
case when price_percentile >= 0.7 and volume_percentile >= 0.7 then 'star (high price, high volume)'
when price_percentile >= 0.7 and volume_percentile < 0.3 then 'premium (high price, low volume)'
when price_percentile < 0.3 and volume_percentile >= 0.7 then 'volume (low price, high volume)'
when price_percentile < 0.3 and volume_percentile < 0.3 then 'niche (low price, low volume)'
else 'balanced' end as category_type
from median_benchmark_rank
order by product_revenue desc;
