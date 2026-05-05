--Ecommerce Analytics : Advance SQL Queries
--Amazon/flipkart  style data analysis

select current_database()

create table orders(
order_id TEXT, customer_id TEXT, order_date TEXT, product_id TEXT, category TEXT, price TEXT, 
quantity TEXT, discount TEXT, payment_method TEXT, city TEXT, state TEXT, delivery_time TEXT, return_flag TEXT

)
--psql cmd hai
copy orders
from '"C:\Users\NUMAN AHMAD\Desktop\Data Analyst\PROJECT Portfolio\New ecommerce claude\ecommerce-analytics-complete\data\ecommerce_100k_flipkart_style.csv"'
delimiter ','
csv header;

--changing datat types

create table orders_clean as select order_id:: int,
									customer_id:: int,
									to_date(order_date, 'dd-mm-yy') as order_date,
									product_id:: int,
									category,
									price:: numeric,
									quantity:: int,
									discount:: numeric,
									payment_method,
									city,
									state,
									delivery_time:: numeric,
									return_flag:: numeric
from orders

alter table orders_clean rename to orders

select * from orders

--QUERY 1: MONTHLY REVENUE TREND WITH MOM GROWTH & COHORT ANALYSIS

with mon_rev as(
select date_trunc('month', order_date) as month, 
		round(sum(price), 2) as revenue,
		count(distinct order_id) as total_order,
		count(distinct customer_id) as uni_cust_id
from orders
group by month order by month
)
select uni_cust_id, total_order, to_char(month, 'Mon-YY') as mon, revenue from mon_rev group by mon, revenue order by revenue


--👉 order_id unique nahi hai kyunki table “order-level” nahi, “order-item level” par stored hai.

Return Rate = Returned Orders / Total Orders



select return_flag,
		case when return_flag = 75 then 1 else 0 end as result
from orders where return_flag>0 
order by return_flag 

select return_flag from orders where return_flag>0
order by return_flag


select order_id, count(*) from orders group by order_id having count(*) >1

SELECT order_id, product_id, COUNT(*) as caunt
FROM orders
GROUP BY order_id, product_id
HAVING COUNT(*) > 2;

alter table orders
add column order_item_id serial primary key

alter table orders
rename column order_item_id to item_order_id

select * from orders 


select item_order_id, count(*) from orders group by item_order_id having count(*)>1
--koi row nahi aaya matlab duplicacy nahi hai


select order_id, rn from(
select order_id, row_number() over(partition by order_id order by order_date ) as rn from orders 
) t
where rn>1


/*
select order_id, rn from(
select order_id, row_number() over(partition by order_id order by order_date ) as rn from orders 
) t
where rn>1

delete from orders where order_id in(
select order_id, rn from(
select order_id, row_number() over(partition by order_id order by order_date ) as rn from orders 
) t
where rn>1
)
*/

--QUERY 1: MONTHLY REVENUE TREND WITH MOM GROWTH & COHORT ANALYSIS


--Actually this question has 3 combined question
-- 1st monthly Revenue
with monthly_rev as(
select date_trunc('month', order_date)::date as month, 
		round(sum(price), 2) as curr_mon_rev 
from orders group by date_trunc('month', order_date) 
			order by date_trunc('month', order_date)
)
select to_char(month, 'Mon') as month, curr_mon_rev  
from monthly_rev

-- 2nd mom growth means % growth mon-over-mon ((current-prev)/prev)*100

with monthly_rev as(
				select date_trunc('month', order_date)::date as month, round(sum(price), 2) as curr_mon_rev  
				from orders group by date_trunc('month', order_date) 	
),
mom_cal as (
		select  month,
				curr_mon_rev ,
				lag(curr_mon_rev ) over(order by month) as prev_mon_rev
				from monthly_rev
)
select to_char(month, 'Mon') as month, curr_mon_rev, prev_mon_rev, 
			round(
			(curr_mon_rev - prev_mon_rev) / nullif(prev_mon_rev, 0) * 100, 
			 2) as mom_growth_pct
			from mom_cal

/*👉 Agar prev_mon_rev = 0:

denominator = NULL
result = NULL (error nahi aata) ✅
*/


--3rd question cohort analysis=👉 Customers kab aaye (first purchase month) aur baad me kitne active rahe?
/*Jan me jo customers aaye
unme se kitne Feb, Mar me wapas aaye
*/

with cohort as(
			select customer_id, min(date_trunc('month',order_date)::date) as cohort_month   
			from orders group by customer_id
),
cohort_data as(
			select o.customer_id, c.cohort_month, 
			date_trunc('month',order_date)::date as order_month 
			from cohort c join orders o 
			on o.customer_id = c.customer_id
),
final_data as(
			select cohort_month,
			extract(year from age(order_month, cohort_month))*12 + extract (month from age(order_month, cohort_month)) as month_no,
			count(distinct customer_id) as customers
			from cohort_data group by cohort_month, extract(year from age(order_month, cohort_month))*12 + extract (month from age(order_month, cohort_month))
)
select * from final_data order by cohort_month




--🧠 🔥 Cohort Analysis kya hota hai? (Theory)

--Same time pe aaye users ka behavior track karna over time

--🧩 Cohort ka matlab

--👉 Cohort = group of users who joined in same time period



cohort_data AS (
  SELECT 
    o.customer_id,
    c.MIN(DATE_TRUNC('month', o.order_date)) AS cohort_month--(user kab aaya),
    DATE_TRUNC('month', o.order_date) AS order_month--(user kab active tha)
  FROM orders o
  JOIN cohort c 
  ON o.customer_id = c.customer_id



--🧠 Ek line mein yaad rakh

--“Cohort analysis tells you: users who came together, how long they stayed.”
/*
🔥 Real Business Questions

Cohort se answer milta hai:

Customers kitne time tak active rehte hain?
Retention improve ho raha hai ya nahi?
Kaunsa batch best perform kar raha hai?

*/

-- QUERY 2: CUSTOMER SEGMENTATION BY RFM (RECENCY, FREQUENCY, MONETARY)

/*
NTILE(n) ek window function hai jo data ko n equal groups (buckets) mein divide karta hai.

Simple: “data ko rank karke equal parts mein baant do”

🎯 5 kyun use kiya?

👉 Depends on use-case:

NTILE value	Meaning
4	Quartiles
5	Quintiles 🔥
10	Deciles

👉 RFM analysis mein:

5 use hota hai → score 1–5

🎯 Interview ready line

“I use RFM analysis to segment customers based on recency, frequency, and monetary value using window functions like NTILE.”

🎯 Interview ready answer

“RFM scoring is based on quantile ranking using NTILE, and segmentation rules are derived from business logic to classify customers into actionable groups like Champions, Loyal, and At Risk.”

*/

with rfm as(
			select customer_id, current_date - max(order_date) as recency,
					count(distinct order_id) as frequency,
					sum(price) as monetry
			from orders group by customer_id
),
rfm_score as(
			select *,
			ntile(5) over(order by recency desc) as r_score,
			ntile(5) over(order by frequency) as f_score,
			ntile(5) over(order by monetry) as m_score
			from rfm
)
select *,
		case
			when r_score = 5 and f_score =5 and m_score = 5 then 'champions'
			when r_score >= 4 and f_score >=4 then 'loyal_customer'
			when r_score <=2 then 'at_risk'
			else 'other'
			end as segment
from rfm_score
			

-- QUERY 3: TOP 20 CUSTOMERS BY REVENUE WITH PURCHASE FREQUENCY RANKING
with customer_metric as(
select customer_id, 
		sum(price) as revenue,
		count(distinct order_id) as frequency
		from orders group by customer_id
)

select * , dense_rank() over(order by revenue desc) as rev_rnk from customer_metric
order by revenue limit 20

/*
💡 Interview ready line

“RANK() skips ranks in case of ties, while DENSE_RANK() does not skip and maintains continuous ranking.”

2️⃣ OVER (...)

👉 Ye batata hai:

“Ranking ka rule kya hoga?”

✔️ Without OVER → function kaam nahi karega

🚫 2️⃣ Jab PARTITION BY use nahi karte

👉 Jab tumhe poore dataset pe ek hi calculation chahiye

RANK() OVER (ORDER BY total_revenue DESC)
👉 Sab customers ek hi list me rank honge

🎯 Golden Rule (yaad rakh 🔥)

👉

PARTITION BY = group ke andar calculation
No PARTITION BY = poore data pe calculation

*/


QUERY 4: PRODUCT CATEGORY PERFORMANCE & CROSS-CATEGORY AFFINITY

PART 1: Category Performance

👉 Har category ka total performance 

select category,
		count(distinct order_id) as total_orders,
		count(*) as total_item
from orders
group by category
order by total_orders desc

--Insight sports category is higest selling 

PART 2: Cross-Category Affinity
--👉 Kaunse categories saath me kharide jaate hain

select a.category as category_1
		b.category as category_2
		count(distinct a.order_id) as orders_count
		from orders a join orders b
		on a.order_id = b.order_id
		and a.category < b.category
		group by 1,2
		order by orders_count desc

/*👉 Meaning: Same order mein kaunse products saath mein aaye

*/
select * from orders

select a.category as cat1,
		b.category as cat2, 
		count(distinct a.order_id) as orders_count
		from orders a join orders b
		on a.order_id = b.order_id
		and a.category < b.category
		group by a.category,
		b.category
		order by orders_count desc

		
insight- sports category mein toys & games saath me kharida gaya hai 8776 time


QUERY 5: MONTHLY COHORT RETENTION ANALYSIS (COHORT MONTHS)

with cohort as(
		select customer_id,
		min(order_date) as cohort_month
from orders
group by customer_id
),
cohort_data as(
				select c.cohort_month, o.customer_id,
				date_trunc('month', o.order_date) as order_month
				from orders o join cohort as c
				on o.customer_id = c.customer_id
),
cohort_calc as(
			SELECT
    cohort_month,
    EXTRACT(YEAR FROM age(order_month, cohort_month)) * 12 +
    EXTRACT(MONTH FROM age(order_month, cohort_month)) AS month_number,
    COUNT(DISTINCT customer_id) AS customers
  FROM cohort_data
  GROUP BY 1,2
)

SELECT *, customers * 100 / first_value(customers) over(partition by cohort_month order by month_number ) as retention_pct
FROM cohort_calc
ORDER BY cohort_month, month_number;


--Customers who joined on first month churn 48% and remaining retention of customer is 52%

Interview ready line

“I group customers by their first purchase month and track retention across subsequent months using cohort analysis.”

================================================================================

QUERY 6: REPEAT PURCHASE ANALYSIS & CUSTOMER LOYALTY

Orders per customer

with customer_order as(
					select customer_id, count(distinct order_id) as total_orders
					from orders group by customer_id
)
--Repeat vs One-time

select case
			when total_orders = 1 then 'one_time'
			else 'repeat'
			end as customer_type, count(*) as customers
from customer_order
group by 1

==total 5k repeat customers

💡 STEP 3: Loyalty buckets

SELECT 
  CASE 
    WHEN total_orders = 1 THEN 'One-time'
    WHEN total_orders BETWEEN 2 AND 3 THEN 'Occasional'
    WHEN total_orders BETWEEN 4 AND 6 THEN 'Frequent'
    ELSE 'Loyal'
  END AS loyalty_segment,
  COUNT(*) AS customers
FROM customer_orders
GROUP BY 1
ORDER BY customers DESC;





🔥 STEP 4: Repeat purchase rate

SELECT 
  ROUND(
    COUNT(CASE WHEN total_orders > 1 THEN 1 END) * 100.0 
    / COUNT(*), 
  2) AS repeat_purchase_rate
FROM customer_orders;

📈 Meaning

👉 Output:

60% → 60% customers repeat kar rahe hain
40% → one-time buyers

=========================================================================

-- QUERY 7: PAYMENT METHOD & GEOGRAPHIC ANALYSIS
















