
-- --------------------------------------------------------------
-- customer behaviour 
-- ---------------------------------------------------------------

-- total customers -------------------------------------------------

select
count(distinct customer_id) as total_customers
from olist_customers_dataset;

-- total paying customers ----------------
select
count(distinct c.customer_id) as total_customers
from olist_customers_dataset c
join olist_orders_dataset o on c.customer_id = o.customer_id
where order_status = 'Delivered';


-- total leads, converted leads and conversion rate -----------------

with leads_generated as(
select
count(distinct m.mql_id) as total_leads,
count(distinct cd.mql_id) as converted_leads
from olist_marketing_qualified_leads_dataset m
left join olist_closed_deals_dataset cd on m.mql_id = cd.mql_id)

select
total_leads,
converted_leads,
round(((converted_leads * 100) / total_leads), 2) as conversion_rate
from leads_generated;


-- revenue per lead --------------------------------------------------

with lead_revenue as(
select
cd.mql_id,
sum(oi.price) as revenue
from olist_closed_deals_dataset cd
join olist_order_items_dataset oi on cd.seller_id = oi.seller_id
join olist_orders_dataset o on oi.order_id = o.order_id
where order_status = 'Delivered'
group by cd.mql_id),

lead_metrics as(
select 
count(distinct m.mql_id) as total_leads,
coalesce(sum(lr.revenue), 0) as total_revenue_from_leads
FROM olist_marketing_qualified_leads_dataset m
left join olist_closed_deals_dataset cd on m.mql_id = cd.mql_id
left join lead_revenue lr on cd.mql_id = lr.mql_id
)

SELECT 
total_leads,
total_revenue_from_leads,
round(total_revenue_from_leads / nullif(total_leads, 0), 2) AS revenue_per_lead
FROM lead_metrics;


-- revenue per lead by channel ------------------------------------------

with lead_revenue as(
select
cd.mql_id,
sum(oi.price) as revenue
from olist_closed_deals_dataset cd
join olist_order_items_dataset oi on cd.seller_id = oi.seller_id
join olist_orders_dataset o on oi.order_id = o.order_id
where order_status = 'Delivered'
group by cd.mql_id),

channel_metrics as(
select 
origin,
count(distinct m.mql_id) as total_leads,
coalesce(sum(lr.revenue), 0) as total_revenue_from_leads
FROM olist_marketing_qualified_leads_dataset m
left join olist_closed_deals_dataset cd on m.mql_id = cd.mql_id
left join lead_revenue lr on cd.mql_id = lr.mql_id
group by origin
)

SELECT 
origin,
total_leads,
total_revenue_from_leads,
round(sum(total_revenue_from_leads) over () / nullif(total_leads, 0), 2)  AS revenue_per_lead_by_channel
FROM channel_metrics
group by origin;


-- conversion rate by channel --------------------------------

select
origin,
count(distinct m.mql_id) as leads_count,
count(distinct cd.mql_id) as converted_leads,
round((count(distinct cd.mql_id) * 100) / count(distinct m.mql_id), 2) as conversion_rate_by_channel
from olist_marketing_qualified_leads_dataset m
left join olist_closed_deals_dataset cd on m.mql_id = cd.mql_id
group by origin
order by conversion_rate_by_channel desc;


-- rfm segmentation -------------------------------------------

with max_calendar_date as(
select
max(order_purchase_timestamp) as max_date
from olist_orders_dataset),

customer_rfm as(select 
c.customer_id,
max(order_purchase_timestamp) as last_purchase,
count(distinct oi.order_id) as frequency,
sum(oi.price) as monetary
from olist_customers_dataset c 
join olist_orders_dataset o on c.customer_id = o.customer_id
join olist_order_items_dataset oi on o.order_id = oi.order_id
where order_status = 'Delivered'
group by c.customer_id),

rfm as(
select 
customer_id,
last_purchase,
datediff(max_date, last_purchase) as recency,
frequency,
monetary
from customer_rfm 
cross join max_calendar_date),

rfm_score as(
select
customer_id,
recency,
frequency,
monetary,
-- Recency score (lower recency = higher score)
ntile(5) over (order by recency) as recency_score,
-- frequency score (higher frequency = higher score)
ntile(5) over (order by frequency) as frequency_score,
-- monetary score (higher monetary = higher score)
ntile(5) over (order by monetary) as monetary_score
from rfm),

customer_category as(
select
customer_id,
recency,
frequency,
monetary,
recency_score,
frequency_score,
monetary_score,
concat(recency_score, ' ', frequency_score, ' ', monetary_score) as rfm_scoress,
case
when recency_score >= 4 and frequency_score >= 4 and monetary_score >= 4 then 'Champions'
when recency_score >= 4 and frequency_score >= 3 and monetary_score >= 3 then 'Loyal Customers'
when recency_score >= 4 and frequency_score <= 2 then 'New Customers'
when recency_score <= 2 and frequency_score >= 4 and monetary_score >= 4 then 'At Risk'
when recency_score <= 2 and frequency_score <= 2 then 'Lost'
when recency_score >= 3 and frequency_score >= 3 and monetary_score <= 2 then 'Potential Loyalists'
when recency_score >= 3 and frequency_score <= 2 then 'promising'
when recency_score <= 2 and frequency_score >= 3 then 'need attention'
else 'Other' end as rfm_segment
from rfm_score)

select
rfm_segment,
count(rfm_segment) as segment_counts,
round((count(rfm_segment) * 100) / sum(count(rfm_segment)) over (), 2) as segment_pct
from customer_category
group by rfm_segment
order by segment_pct desc;


-- churned customers and churn rate ---------------------------

with max_calendar_date as(
select 
max(order_purchase_timestamp) as max_date
from olist_orders_dataset o),

customer_last_purchase as(
select 
c.customer_id,
max(order_purchase_timestamp) as last_purchase_date
from olist_customers_dataset c
join olist_orders_dataset o on c.customer_id = o.customer_id
where order_status = 'Delivered'
group by customer_id),

customer_seg as(
select 
customer_id,
last_purchase_date,
case 
when datediff(max_date, last_purchase_date) > 90 then 'churned'
else 'active' end as customer_status
from customer_last_purchase
cross join max_calendar_date)

select 
count(case when customer_status = 'churned' then 1 end) as churned_customers,
count(*) as total_customers,
round((count(case when customer_status = 'churned' then 1 end) * 100) / count(*), 2) as churn_rate
from customer_seg;


-- RFM (absolute not relative, most of the customers are churn already)------
-- using relative rfm would only categorise according to the data distribution and not the normal way --
-- customers churned becoming champions, that causes error --

with max_calendar_date as(
select
max(order_purchase_timestamp) as max_date
from olist_orders_dataset),

customer_rfm as(select 
c.customer_id,
max(order_purchase_timestamp) as last_purchase,
count(distinct oi.order_id) as frequency,
sum(oi.price) as monetary
from olist_customers_dataset c 
join olist_orders_dataset o on c.customer_id = o.customer_id
join olist_order_items_dataset oi on o.order_id = oi.order_id
where order_status = 'Delivered'
group by c.customer_id),

rfm as(
select 
customer_id,
last_purchase,
datediff(max_date, last_purchase) as recency,
frequency,
monetary
from customer_rfm 
cross join max_calendar_date),

rfm_score as(select
customer_id,
recency,
frequency,
monetary,
-- Recency score (lower recency = higher score)
case
when recency <= 30 then 5
when recency <= 60 then 4
when recency <= 90 then 3
when recency <= 180 then 2 else 1 end as recency_score,

-- frequency score (higher frequency = higher score)
case
when frequency > 1 then 5 else 1 end as frequency_score,

-- monetary score (higher monetary = higher score)
ntile(5) over (order by monetary) as monetary_score
from rfm),

customer_category as(select
customer_id,
recency,
frequency,
monetary,
recency_score,
frequency_score,
monetary_score,
concat(recency_score, ' ', frequency_score, ' ', monetary_score) as rfm_scoress,
case
when recency_score >= 4 and frequency_score = 1 and monetary_score >= 4 then 'New High Value'
when recency_score >= 4 and frequency_score = 1 and monetary_score = 3 then 'New Mid Value'
when recency_score >= 4 and frequency_score = 1 and monetary_score <= 2 then 'New Low Value'
when recency_score = 3 and frequency_score = 1 and monetary_score >= 4 then 'At Risk High Value'
when recency_score = 3 and frequency_score = 1 and monetary_score = 3 then 'At Risk Mid Value'
when recency_score = 3 and frequency_score = 1 and monetary_score <= 2 then 'At Risk Low Value'
when recency_score <= 2 and frequency_score = 1 and monetary_score >= 4 then 'Lost High Value'
when recency_score <= 2 and frequency_score = 1 and monetary_score = 3 then 'Lost Mid Value'
when recency_score <= 2 and frequency_score = 1 and monetary_score <= 2 then 'Low Value'
else 'Other' end as rfm_segment
from rfm_score)

select
rfm_segment,
count(rfm_segment) as segment_counts,
round((count(rfm_segment) * 100) / sum(count(rfm_segment)) over (), 2) as segment_pct
from customer_category
group by rfm_segment
order by segment_pct desc;


-- repeat purchase rate -------------------------------

with freq as(select
c.customer_id,
count(distinct oi.order_id) as frequency
from olist_customers_dataset c
join olist_orders_dataset o on c.customer_id = o.customer_id
join olist_order_items_dataset oi on o.order_id = oi.order_id
where order_status = 'Delivered'
group by c.customer_id),

repeat_purchases as(select
frequency,
case when frequency > 1 then 'repeat_purchase' else 'no_repeat_purchase' end as returning_customers
from freq)

select 
count(case when returning_customers = 'repeat_purchase' then 1 end)  as repeat_purchase,
count(*) as total_customers,
round((count(case when returning_customers = 'repeat_purchase' then 1 end) * 100) / count(*), 2) as repeat_purchase_rate
from repeat_purchases;
