-- ═══════════════════════════════════════════════════════════════════════════
-- ECOMMERCE ANALYTICS: ADVANCED SQL QUERIES
-- Flipkart/Amazon Style Data Analysis
-- ═══════════════════════════════════════════════════════════════════════════

-- QUERY 1: MONTHLY REVENUE TREND WITH MOM GROWTH & COHORT ANALYSIS
-- Purpose: Track revenue trajectory, identify seasonality, calculate growth rates
-- Business Impact: Revenue planning, forecasting, seasonal strategy
WITH monthly_metrics AS (
  SELECT
    DATE_TRUNC('month', order_date)::DATE AS month,
    COUNT(DISTINCT order_id) AS total_orders,
    COUNT(DISTINCT customer_id) AS unique_customers,
    SUM(revenue) AS total_revenue,
    ROUND(AVG(revenue), 2) AS avg_order_value,
    SUM(CASE WHEN return_flag = 1 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) AS return_rate_pct
  FROM orders
  WHERE return_flag IN (0, 1)
  GROUP BY 1
)
SELECT
  month,
  total_orders,
  unique_customers,
  total_revenue,
  avg_order_value,
  return_rate_pct * 100 AS return_rate,
  LAG(total_revenue) OVER (ORDER BY month) AS prev_month_revenue,
  ROUND(((total_revenue - LAG(total_revenue) OVER (ORDER BY month)) / 
         LAG(total_revenue) OVER (ORDER BY month) * 100), 2) AS mom_growth_pct,
  ROUND(AVG(total_revenue) OVER (ORDER BY month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 0) AS moving_avg_3m
FROM monthly_metrics
ORDER BY month DESC;

-- ═══════════════════════════════════════════════════════════════════════════

-- QUERY 2: CUSTOMER SEGMENTATION BY RFM (RECENCY, FREQUENCY, MONETARY)
-- Purpose: Segment customers for targeted campaigns
-- Business Impact: Personalization, retention strategy, revenue maximization
WITH snapshot AS (
  SELECT MAX(order_date) + 1 AS today FROM orders
),
rfm_metrics AS (
  SELECT
    o.customer_id,
    (SELECT today FROM snapshot) - MAX(o.order_date) AS recency_days,
    COUNT(DISTINCT o.order_id) AS frequency,
    SUM(o.revenue) AS monetary,
    COUNT(DISTINCT DATE_TRUNC('month', o.order_date)) AS months_active
  FROM orders o
  WHERE o.return_flag IN (0, 1)
  GROUP BY o.customer_id
),
rfm_scores AS (
  SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,  -- Higher is better (recently active)
    NTILE(5) OVER (ORDER BY frequency DESC) AS f_score,      -- Higher is better (frequent buyer)
    NTILE(5) OVER (ORDER BY monetary DESC) AS m_score         -- Higher is better (high value)
  FROM rfm_metrics
),
customer_segments AS (
  SELECT
    customer_id,
    recency_days,
    frequency,
    monetary,
    r_score,
    f_score,
    m_score,
    CASE
      WHEN r_score >= 4 AND f_score >= 4 THEN 'Champion'
      WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal'
      WHEN r_score >= 4 AND f_score <= 2 THEN 'New Customer'
      WHEN r_score BETWEEN 2 AND 3 AND f_score >= 3 THEN 'At Risk'
      WHEN r_score <= 1 AND f_score >= 3 THEN 'Lost'
      ELSE 'Need Attention'
    END AS segment
  FROM rfm_scores
)
SELECT
  segment,
  COUNT(*) AS customer_count,
  ROUND(COUNT(*)::FLOAT / SUM(COUNT(*)) OVER () * 100, 2) AS pct_of_base,
  ROUND(AVG(recency_days), 1) AS avg_recency_days,
  ROUND(AVG(frequency), 2) AS avg_purchase_frequency,
  ROUND(AVG(monetary), 2) AS avg_clv,
  SUM(monetary) AS total_segment_revenue,
  ROUND(SUM(monetary)::FLOAT / SUM(SUM(monetary)) OVER () * 100, 2) AS revenue_contribution_pct
FROM customer_segments
GROUP BY segment
ORDER BY total_segment_revenue DESC;

-- ═══════════════════════════════════════════════════════════════════════════

-- QUERY 3: TOP 20 CUSTOMERS BY REVENUE WITH PURCHASE FREQUENCY RANKING
-- Purpose: Identify VIP customers, personalization targets
-- Business Impact: Focus retention on high-value customers
SELECT
  o.customer_id,
  COUNT(DISTINCT o.order_id) AS total_purchases,
  COUNT(DISTINCT DATE_TRUNC('month', o.order_date)::DATE) AS months_active,
  SUM(o.revenue) AS total_lifetime_value,
  ROUND(AVG(o.revenue), 2) AS avg_order_value,
  MAX(o.order_date) AS last_purchase_date,
  (CURRENT_DATE - MAX(o.order_date)::DATE) AS days_since_last_purchase,
  RANK() OVER (ORDER BY SUM(o.revenue) DESC) AS revenue_rank,
  ROUND(SUM(o.revenue)::FLOAT / SUM(SUM(o.revenue)) OVER () * 100, 3) AS pct_of_total_revenue
FROM orders o
WHERE o.return_flag IN (0, 1)
GROUP BY o.customer_id
ORDER BY total_lifetime_value DESC
LIMIT 20;

-- ═══════════════════════════════════════════════════════════════════════════

-- QUERY 4: PRODUCT CATEGORY PERFORMANCE & CROSS-CATEGORY AFFINITY
-- Purpose: Identify high-performing categories, bundling opportunities
-- Business Impact: Category marketing, inventory optimization, pricing strategy
SELECT
  category,
  COUNT(DISTINCT order_id) AS order_count,
  COUNT(DISTINCT customer_id) AS unique_customers,
  SUM(quantity) AS units_sold,
  SUM(revenue) AS total_revenue,
  ROUND(AVG(revenue), 2) AS avg_order_value,
  ROUND(SUM(revenue) / COUNT(DISTINCT order_id), 2) AS revenue_per_order,
  ROUND(SUM(CASE WHEN return_flag = 1 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 2) AS return_rate_pct,
  ROUND(SUM(discount) / COUNT(*), 2) AS avg_discount_given,
  ROUND(AVG(delivery_time), 1) AS avg_delivery_days,
  RANK() OVER (ORDER BY SUM(revenue) DESC) AS revenue_rank,
  PERCENT_RANK() OVER (ORDER BY SUM(revenue) DESC) AS revenue_percentile
FROM orders
WHERE return_flag IN (0, 1)
GROUP BY category
ORDER BY total_revenue DESC;

-- ═══════════════════════════════════════════════════════════════════════════

-- QUERY 5: MONTHLY COHORT RETENTION ANALYSIS (COHORT MONTHS)
-- Purpose: Understand customer lifecycle, retention dropoff, reactivation opportunities
-- Business Impact: Retention strategy, cohort-specific interventions, LTV modeling
WITH cohort_analysis AS (
  SELECT
    o.customer_id,
    DATE_TRUNC('month', MIN(o.order_date))::DATE AS cohort_month,
    DATE_TRUNC('month', o.order_date)::DATE AS order_month,
    COUNT(DISTINCT o.order_id) AS orders_in_month
  FROM orders o
  WHERE o.return_flag IN (0, 1)
  GROUP BY o.customer_id, DATE_TRUNC('month', o.order_date)::DATE
),
cohort_with_offset AS (
  SELECT
    cohort_month,
    order_month,
    (EXTRACT(YEAR FROM order_month)::INT * 12 + EXTRACT(MONTH FROM order_month)::INT) -
    (EXTRACT(YEAR FROM cohort_month)::INT * 12 + EXTRACT(MONTH FROM cohort_month)::INT) AS month_offset,
    COUNT(DISTINCT customer_id) AS active_customers
  FROM cohort_analysis
  GROUP BY cohort_month, order_month
),
cohort_size AS (
  SELECT
    cohort_month,
    COUNT(DISTINCT customer_id) AS cohort_customers
  FROM cohort_analysis
  WHERE month_offset = 0
  GROUP BY cohort_month
)
SELECT
  c.cohort_month,
  cs.cohort_customers,
  c.month_offset,
  c.active_customers,
  ROUND(c.active_customers::FLOAT / cs.cohort_customers * 100, 1) AS retention_pct
FROM cohort_with_offset c
JOIN cohort_size cs ON c.cohort_month = cs.cohort_month
WHERE month_offset BETWEEN 0 AND 12
ORDER BY cohort_month DESC, month_offset;

-- ═══════════════════════════════════════════════════════════════════════════

-- QUERY 6: REPEAT PURCHASE ANALYSIS & CUSTOMER LOYALTY
-- Purpose: Identify repeat buyers vs one-time purchasers, calculate loyalty metrics
-- Business Impact: Repeat rate improvement, acquisition vs retention spend
WITH customer_purchase_count AS (
  SELECT
    customer_id,
    COUNT(DISTINCT order_id) AS purchase_count,
    SUM(revenue) AS lifetime_value,
    MIN(order_date) AS first_purchase_date,
    MAX(order_date) AS last_purchase_date,
    (MAX(order_date)::DATE - MIN(order_date)::DATE) AS customer_lifetime_days
  FROM orders
  WHERE return_flag IN (0, 1)
  GROUP BY customer_id
)
SELECT
  CASE
    WHEN purchase_count = 1 THEN '1 Purchase'
    WHEN purchase_count BETWEEN 2 AND 3 THEN '2-3 Purchases'
    WHEN purchase_count BETWEEN 4 AND 6 THEN '4-6 Purchases'
    WHEN purchase_count >= 7 THEN '7+ Purchases'
  END AS purchase_frequency,
  COUNT(*) AS customer_count,
  ROUND(COUNT(*)::FLOAT / SUM(COUNT(*)) OVER () * 100, 2) AS pct_of_customers,
  ROUND(AVG(lifetime_value), 2) AS avg_clv,
  SUM(lifetime_value) AS segment_revenue,
  ROUND(AVG(customer_lifetime_days), 0) AS avg_customer_tenure_days,
  ROUND(SUM(lifetime_value) / SUM(SUM(lifetime_value)) OVER () * 100, 2) AS revenue_contribution_pct
FROM customer_purchase_count
GROUP BY purchase_frequency
ORDER BY CAST(SPLIT_PART(purchase_frequency, ' ', 1) AS INT);

-- ═══════════════════════════════════════════════════════════════════════════

-- QUERY 7: PAYMENT METHOD & GEOGRAPHIC ANALYSIS
-- Purpose: Understand payment preferences, regional performance
-- Business Impact: Payment gateway optimization, regional marketing strategy
SELECT
  payment_method,
  state,
  city,
  COUNT(DISTINCT order_id) AS order_count,
  COUNT(DISTINCT customer_id) AS unique_customers,
  SUM(revenue) AS total_revenue,
  ROUND(AVG(revenue), 2) AS avg_order_value,
  ROUND(SUM(CASE WHEN return_flag = 1 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 2) AS return_rate_pct,
  ROUND(AVG(delivery_time), 1) AS avg_delivery_days,
  RANK() OVER (PARTITION BY payment_method ORDER BY SUM(revenue) DESC) AS rank_by_payment
FROM orders
WHERE return_flag IN (0, 1)
GROUP BY payment_method, state, city
ORDER BY payment_method, total_revenue DESC;

-- ═══════════════════════════════════════════════════════════════════════════

-- QUERY 8: RETURN RATE ANALYSIS & PRODUCT QUALITY SCORING
-- Purpose: Identify problematic products/categories, quality issues
-- Business Impact: Supply chain optimization, product culling, vendor management
SELECT
  category,
  COUNT(DISTINCT product_id) AS product_count,
  COUNT(DISTINCT order_id) AS total_orders,
  SUM(CASE WHEN return_flag = 1 THEN 1 ELSE 0 END) AS return_count,
  ROUND(SUM(CASE WHEN return_flag = 1 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) * 100, 2) AS return_rate_pct,
  SUM(CASE WHEN return_flag = 0 THEN revenue ELSE 0 END) AS net_revenue_kept,
  SUM(CASE WHEN return_flag = 1 THEN revenue ELSE 0 END) AS lost_revenue_to_returns,
  ROUND(SUM(CASE WHEN return_flag = 1 THEN revenue ELSE 0 END)::FLOAT / SUM(revenue) * 100, 2) AS pct_revenue_lost,
  ROUND(AVG(delivery_time), 1) AS avg_delivery_days,
  CASE
    WHEN SUM(CASE WHEN return_flag = 1 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) < 0.05 THEN 'Excellent'
    WHEN SUM(CASE WHEN return_flag = 1 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) < 0.1 THEN 'Good'
    WHEN SUM(CASE WHEN return_flag = 1 THEN 1 ELSE 0 END)::FLOAT / COUNT(*) < 0.15 THEN 'Fair'
    ELSE 'Poor'
  END AS quality_rating
FROM orders
GROUP BY category
ORDER BY return_rate_pct DESC;

-- ═══════════════════════════════════════════════════════════════════════════
-- END OF QUERIES
-- ═══════════════════════════════════════════════════════════════════════════
