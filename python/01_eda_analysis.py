"""
═══════════════════════════════════════════════════════════════════════════════
         END-TO-END E-COMMERCE ANALYTICS: PYTHON EDA SCRIPT
         Production-Ready Data Analysis for Flipkart/Amazon Style Data
═══════════════════════════════════════════════════════════════════════════════
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from scipy import stats
import warnings
warnings.filterwarnings('ignore')

# ─── Setup ──────────────────────────────────────────────────────────────────
sns.set_style("whitegrid")
sns.set_palette("husl")
plt.rcParams['figure.figsize'] = (14, 8)
plt.rcParams['font.size'] = 10

print("\n" + "="*80)
print("E-COMMERCE ANALYTICS: END-TO-END EXPLORATORY DATA ANALYSIS".center(80))
print("="*80)

# ─── 1. LOAD & UNDERSTAND DATA ──────────────────────────────────────────────
print("\n[STEP 1] LOADING & UNDERSTANDING DATA")
print("-" * 80)

df = pd.read_csv('data/ecommerce_100k_flipkart_style.csv')
df['order_date'] = pd.to_datetime(df['order_date'])

print(f"Dataset shape: {df.shape}")
print(f"Records: {len(df):,} | Columns: {df.shape[1]}")
print(f"Date range: {df['order_date'].min().date()} to {df['order_date'].max().date()}")
print(f"Unique customers: {df['customer_id'].nunique():,}")
print(f"Missing values: {df.isnull().sum().sum():,} ({df.isnull().sum().sum()/len(df)*100:.2f}%)")
print(f"\nData types:\n{df.dtypes}")

# ─── 2. DATA CLEANING ──────────────────────────────────────────────────────
print("\n[STEP 2] DATA CLEANING")
print("-" * 80)

# Handle missing values
print(f"Missing values before: {df.isnull().sum().sum():,}")
df['price'].fillna(df['price'].median(), inplace=True)
df = df.dropna()
print(f"Missing values after: {df.isnull().sum().sum():,}")

# Remove duplicates
duplicates_before = len(df)
df = df.drop_duplicates()
duplicates_removed = duplicates_before - len(df)
print(f"Duplicates removed: {duplicates_removed:,}")

# Handle outliers using IQR
Q1 = df['price'].quantile(0.25)
Q3 = df['price'].quantile(0.75)
IQR = Q3 - Q1
upper_bound = Q3 + 1.5 * IQR
outliers = (df['price'] > upper_bound).sum()
df.loc[df['price'] > upper_bound, 'price'] = upper_bound
print(f"Price outliers capped: {outliers}")

df['revenue'] = (df['price'] * df['quantity'] * (1 - df['discount'] / 100)).astype(int)

# ─── 3. UNIVARIATE ANALYSIS ────────────────────────────────────────────────
print("\n[STEP 3] UNIVARIATE ANALYSIS")
print("-" * 80)

numeric_cols = ['price', 'quantity', 'discount', 'delivery_time', 'revenue']
print(f"\nNumeric columns summary:")
print(df[numeric_cols].describe().round(2))

print(f"\nSkewness & Kurtosis:")
for col in numeric_cols:
    sk = stats.skew(df[col])
    ku = stats.kurtosis(df[col])
    print(f"  {col:15} - Skewness: {sk:7.3f}, Kurtosis: {ku:7.3f}")

print(f"\nCategorical columns:")
print(f"  Categories: {df['category'].nunique()} unique")
print(f"  Cities: {df['city'].nunique()} unique")
print(f"  States: {df['state'].nunique()} unique")
print(f"  Payment methods: {df['payment_method'].nunique()} unique")

# ─── 4. BIVARIATE ANALYSIS ─────────────────────────────────────────────────
print("\n[STEP 4] BIVARIATE & MULTIVARIATE ANALYSIS")
print("-" * 80)

# Correlation
corr_with_revenue = df[numeric_cols].corr()['revenue'].sort_values(ascending=False)
print(f"\nCorrelation with revenue:")
print(corr_with_revenue)

# Category performance
print(f"\nTop categories by revenue:")
category_revenue = df.groupby('category').agg({
    'order_id': 'count',
    'revenue': ['sum', 'mean'],
    'return_flag': 'mean'
}).round(2)
category_revenue.columns = ['Orders', 'Revenue', 'Avg_Order_Value', 'Return_Rate']
category_revenue = category_revenue.sort_values('Revenue', ascending=False)
print(category_revenue)

# ─── 5. CUSTOMER SEGMENTATION (RFM) ─────────────────────────────────────────
print("\n[STEP 5] CUSTOMER SEGMENTATION (RFM ANALYSIS)")
print("-" * 80)

snapshot_date = df['order_date'].max() + pd.Timedelta(days=1)

rfm = df.groupby('customer_id').agg({
    'order_date': lambda x: (snapshot_date - x.max()).days,
    'order_id': 'count',
    'revenue': 'sum'
}).rename(columns={
    'order_date': 'recency',
    'order_id': 'frequency',
    'revenue': 'monetary'
})

# Score
rfm['r_score'] = pd.qcut(rfm['recency'], q=5, labels=[5,4,3,2,1], duplicates='drop')
rfm['f_score'] = pd.qcut(rfm['frequency'].rank(method='first'), q=5, labels=[1,2,3,4,5], duplicates='drop')
rfm['m_score'] = pd.qcut(rfm['monetary'], q=5, labels=[1,2,3,4,5], duplicates='drop')

# Segment
def segment(row):
    r, f = int(row['r_score']), int(row['f_score'])
    if r >= 4 and f >= 4: return 'Champion'
    if r >= 3 and f >= 3: return 'Loyal'
    if r >= 3 and f <= 2: return 'Potential'
    if r >= 4 and f <= 1: return 'New'
    if r <= 2 and f >= 3: return 'At Risk'
    return 'Lost'

rfm['segment'] = rfm.apply(segment, axis=1)

print(f"\nRFM Segments:")
seg_analysis = rfm.groupby('segment').agg({
    'monetary': ['count', 'mean', 'sum']
}).round(2)
seg_analysis.columns = ['Count', 'Avg_CLV', 'Total_Revenue']
print(seg_analysis.sort_values('Total_Revenue', ascending=False))

# ─── 6. KEY METRICS & INSIGHTS ──────────────────────────────────────────────
print("\n[STEP 6] KEY BUSINESS METRICS")
print("-" * 80)

total_revenue = df['revenue'].sum()
total_orders = len(df)
unique_customers = df['customer_id'].nunique()
avg_order_value = df['revenue'].mean()
repeat_customers = (df.groupby('customer_id').size() > 1).sum()
repeat_rate = repeat_customers / unique_customers * 100

print(f"Total Revenue: ₹{total_revenue:,.0f}")
print(f"Total Orders: {total_orders:,}")
print(f"Unique Customers: {unique_customers:,}")
print(f"Average Order Value: ₹{avg_order_value:,.0f}")
print(f"Repeat Customer Rate: {repeat_rate:.1f}%")
print(f"Return Rate: {(df['return_flag'].mean() * 100):.2f}%")

# City performance
print(f"\nTop 5 cities by revenue:")
print(df.groupby('city')['revenue'].sum().nlargest(5))

# Payment method
print(f"\nPayment method distribution:")
print(df['payment_method'].value_counts())

# ─── 7. VISUALIZATION: DISTRIBUTIONS ────────────────────────────────────────
print("\n[STEP 7] CREATING VISUALIZATIONS")
print("-" * 80)

fig, axes = plt.subplots(2, 3, figsize=(16, 10))
fig.suptitle('E-Commerce Analytics: Distribution Analysis', fontsize=16, fontweight='bold')

axes[0, 0].hist(df['revenue'], bins=50, color='steelblue', edgecolor='black', alpha=0.7)
axes[0, 0].set_title('Revenue Distribution')
axes[0, 0].set_xlabel('Revenue (₹)')

axes[0, 1].hist(df['price'], bins=50, color='coral', edgecolor='black', alpha=0.7)
axes[0, 1].set_title('Price Distribution')
axes[0, 1].set_xlabel('Price (₹)')

axes[0, 2].hist(df['discount'], bins=20, color='seagreen', edgecolor='black', alpha=0.7)
axes[0, 2].set_title('Discount Distribution')
axes[0, 2].set_xlabel('Discount (%)')

axes[1, 0].hist(df['quantity'], bins=10, color='purple', edgecolor='black', alpha=0.7)
axes[1, 0].set_title('Quantity Distribution')
axes[1, 0].set_xlabel('Quantity')

axes[1, 1].hist(df['delivery_time'], bins=10, color='gold', edgecolor='black', alpha=0.7)
axes[1, 1].set_title('Delivery Time Distribution')
axes[1, 1].set_xlabel('Days')

axes[1, 2].barh(df['category'].value_counts().index, df['category'].value_counts().values, color='teal', alpha=0.7)
axes[1, 2].set_title('Orders by Category')
axes[1, 2].set_xlabel('Number of Orders')

plt.tight_layout()
plt.savefig('output_charts/01_distributions.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 01_distributions.png")
plt.close()

# ─── VISUALIZATION: CATEGORY PERFORMANCE ───────────────────────────────────
fig, axes = plt.subplots(2, 2, figsize=(14, 10))
fig.suptitle('Category Performance Analysis', fontsize=16, fontweight='bold')

cat_rev = df.groupby('category')['revenue'].sum().sort_values(ascending=False)
axes[0, 0].barh(cat_rev.index, cat_rev.values, color='steelblue', alpha=0.7)
axes[0, 0].set_title('Revenue by Category')
axes[0, 0].set_xlabel('Revenue (₹)')

cat_orders = df['category'].value_counts()
axes[0, 1].barh(cat_orders.index, cat_orders.values, color='coral', alpha=0.7)
axes[0, 1].set_title('Orders by Category')
axes[0, 1].set_xlabel('Number of Orders')

cat_aov = df.groupby('category')['revenue'].mean().sort_values(ascending=False)
axes[1, 0].barh(cat_aov.index, cat_aov.values, color='seagreen', alpha=0.7)
axes[1, 0].set_title('Average Order Value by Category')
axes[1, 0].set_xlabel('AOV (₹)')

cat_return = df.groupby('category')['return_flag'].mean().sort_values(ascending=False) * 100
axes[1, 1].barh(cat_return.index, cat_return.values, color='crimson', alpha=0.7)
axes[1, 1].set_title('Return Rate by Category')
axes[1, 1].set_xlabel('Return Rate (%)')

plt.tight_layout()
plt.savefig('output_charts/02_category_performance.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 02_category_performance.png")
plt.close()

# ─── VISUALIZATION: RFM SEGMENTS ───────────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(14, 5))
fig.suptitle('RFM Customer Segmentation', fontsize=16, fontweight='bold')

seg_count = rfm['segment'].value_counts()
axes[0].barh(seg_count.index, seg_count.values, color=['green', 'blue', 'orange', 'red', 'purple', 'gray'])
axes[0].set_title('Customer Count by Segment')
axes[0].set_xlabel('Number of Customers')

seg_revenue = rfm.groupby('segment')['monetary'].sum().sort_values(ascending=True)
axes[1].barh(seg_revenue.index, seg_revenue.values, color=['gray', 'red', 'purple', 'orange', 'blue', 'green'])
axes[1].set_title('Revenue Contribution by Segment')
axes[1].set_xlabel('Total Revenue (₹)')

plt.tight_layout()
plt.savefig('output_charts/03_rfm_segments.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 03_rfm_segments.png")
plt.close()

# ─── VISUALIZATION: TEMPORAL TRENDS ────────────────────────────────────────
monthly_data = df.groupby(df['order_date'].dt.to_period('M')).agg({
    'revenue': 'sum',
    'order_id': 'count'
}).reset_index()
monthly_data['order_date'] = monthly_data['order_date'].astype(str)

fig, axes = plt.subplots(1, 2, figsize=(14, 5))
fig.suptitle('Temporal Analysis', fontsize=16, fontweight='bold')

axes[0].plot(range(len(monthly_data)), monthly_data['revenue'], marker='o', linewidth=2, markersize=8, color='steelblue')
axes[0].set_title('Monthly Revenue Trend')
axes[0].set_ylabel('Revenue (₹)')
axes[0].grid(True, alpha=0.3)

axes[1].bar(range(len(monthly_data)), monthly_data['order_id'], color='coral', alpha=0.7)
axes[1].set_title('Monthly Order Count')
axes[1].set_ylabel('Number of Orders')
axes[1].grid(True, alpha=0.3, axis='y')

plt.tight_layout()
plt.savefig('output_charts/04_temporal_trends.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 04_temporal_trends.png")
plt.close()

# ─── VISUALIZATION: PAYMENT & DELIVERY ─────────────────────────────────────
fig, axes = plt.subplots(1, 2, figsize=(14, 5))
fig.suptitle('Payment & Delivery Analysis', fontsize=16, fontweight='bold')

payment_data = df['payment_method'].value_counts()
axes[0].pie(payment_data.values, labels=payment_data.index, autopct='%1.1f%%', startangle=90)
axes[0].set_title('Payment Method Distribution')

delivery_data = df['delivery_time'].value_counts().sort_index()
axes[1].bar(delivery_data.index, delivery_data.values, color='teal', alpha=0.7, edgecolor='black')
axes[1].set_title('Delivery Time Distribution')
axes[1].set_xlabel('Days')
axes[1].set_ylabel('Frequency')

plt.tight_layout()
plt.savefig('output_charts/05_payment_delivery.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 05_payment_delivery.png")
plt.close()

# ─── VISUALIZATION: COHORT RETENTION ───────────────────────────────────────
def calculate_cohort(df):
    df['cohort_month'] = df.groupby('customer_id')['order_date'].transform('min').dt.to_period('M')
    df['order_month'] = df['order_date'].dt.to_period('M')
    df['month_index'] = (df['order_month'] - df['cohort_month']).apply(lambda x: x.n if x.n >= 0 else -1)
    
    cohort_data = df[df['month_index'] >= 0].groupby(['cohort_month', 'month_index'])['customer_id'].nunique().unstack(fill_value=0)
    cohort_size = df.groupby('cohort_month')['customer_id'].nunique()
    cohort_ret = cohort_data.div(cohort_size, axis=0) * 100
    return cohort_ret.iloc[:12, :7]

cohort_retention = calculate_cohort(df)

fig, ax = plt.subplots(figsize=(12, 8))
sns.heatmap(cohort_retention, annot=True, fmt='.0f', cmap='RdYlGn', ax=ax, cbar_kws={'label': 'Retention %'})
ax.set_title('Cohort Retention Heatmap (% of Cohort)', fontsize=14, fontweight='bold')
ax.set_xlabel('Months After First Purchase')
ax.set_ylabel('Acquisition Cohort')
plt.tight_layout()
plt.savefig('output_charts/06_cohort_retention.png', dpi=300, bbox_inches='tight')
print("✓ Saved: 06_cohort_retention.png")
plt.close()

# ─── SUMMARY ───────────────────────────────────────────────────────────────
print("\n" + "="*80)
print("EDA ANALYSIS COMPLETE".center(80))
print("="*80)
print(f"\n✓ All visualizations saved to output_charts/ folder")
print(f"✓ Analysis span: {df['order_date'].min().date()} to {df['order_date'].max().date()}")
print(f"✓ Final dataset: {len(df):,} clean records")

print("\n" + "="*80)
