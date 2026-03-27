-- =========================================================
-- E-Commerce Seller Analytics Pipeline
-- This script builds the data warehouse, feature tables,
-- and final analytics dataset for ML and BI.
-- =========================================================
-- Create raw schema for imported source tables
CREATE SCHEMA IF NOT EXISTS raw;

-- Create closed_deals table with text columns to avoid import issues from Excel/CSV
DROP TABLE IF EXISTS raw.closed_deals;

CREATE TABLE raw.closed_deals (
  mql_id text,
  seller_id text,
  sdr_id text,
  sr_id text,
  won_date text,
  business_segment text,
  lead_type text,
  lead_behaviour_profile text,
  has_company text,
  has_gtin text,
  average_stock text,
  business_type text,
  declared_product_catalog_size text,
  declared_monthly_revenue text
);
 -- Validate closed_deals import
 SELECT COUNT(*) FROM raw.closed_deals;
-- Create marketing funnel lead table
DROP TABLE IF EXISTS raw.marketing_qualified_leads;

CREATE TABLE raw.marketing_qualified_leads (
  mql_id text,
  first_contact_date text,
  landing_page_id text,
  origin text
);
-- Validate marketing_qualified_leads import
SELECT COUNT(*) FROM raw.marketing_qualified_leads;

-- Check whether all closed deals can be linked to a marketing lead

SELECT COUNT(*) 
FROM raw.closed_deals cd
JOIN raw.marketing_qualified_leads m
  ON cd.mql_id = m.mql_id;
  
-- Create sellers table from marketplace dataset 

DROP TABLE IF EXISTS raw.sellers;

CREATE TABLE raw.sellers (
  seller_id text,
  seller_zip_code_prefix text,
  seller_city text,
  seller_state text
);
-- Validate sellers import
SELECT COUNT(*) FROM raw.sellers;

-- Check overlap between funnel sellers and marketplace sellers
SELECT COUNT(DISTINCT cd.seller_id) AS sellers_in_both
FROM raw.closed_deals cd
JOIN raw.sellers s
  ON cd.seller_id = s.seller_id;

-- Create order_items table
DROP TABLE IF EXISTS raw.order_items;

CREATE TABLE raw.order_items (
  order_id text,
  order_item_id text,
  product_id text,
  seller_id text,
  shipping_limit_date text,
  price text,
  freight_value text
);

-- Validate order_items import
SELECT COUNT(*) FROM raw.order_items;

-- Create orders table
DROP TABLE IF EXISTS raw.orders;

CREATE TABLE raw.orders (
  order_id text,
  customer_id text,
  order_status text,
  order_purchase_timestamp text,
  order_approved_at text,
  order_delivered_carrier_date text,
  order_delivered_customer_date text,
  order_estimated_delivery_date text
);

-- Validate orders import
SELECT COUNT(*) FROM raw.orders;
-- Create order_payments table
DROP TABLE IF EXISTS raw.order_payments;

CREATE TABLE raw.order_payments (
  order_id text,
  payment_sequential text,
  payment_type text,
  payment_installments text,
  payment_value text
);
-- Validate order_payments import
SELECT COUNT(*) FROM raw.order_payments;

-- Initial revenue exploration using payment_value at seller level
SELECT
    oi.seller_id,
    SUM(REPLACE(op.payment_value, ',', '.')::numeric) AS revenue
FROM raw.order_items oi
JOIN raw.order_payments op
    ON oi.order_id = op.order_id
GROUP BY oi.seller_id
ORDER BY revenue DESC
LIMIT 10;

-- Revenue exploration restricted to sellers that exist in closed_deals

SELECT
    oi.seller_id,
    SUM(REPLACE(op.payment_value, ',', '.')::numeric) AS revenue
FROM raw.order_items oi
JOIN raw.order_payments op
    ON oi.order_id = op.order_id
JOIN raw.closed_deals cd
    ON oi.seller_id = cd.seller_id
GROUP BY oi.seller_id
ORDER BY revenue DESC;

-- Calculate revenue distribution threshold using payment-based seller revenue

WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        SUM(REPLACE(op.payment_value, ',', '.')::numeric) AS revenue
    FROM raw.order_items oi
    JOIN raw.order_payments op
        ON oi.order_id = op.order_id
    JOIN raw.closed_deals cd
        ON oi.seller_id = cd.seller_id
    GROUP BY oi.seller_id
)

SELECT
    percentile_cont(0.8) WITHIN GROUP (ORDER BY revenue) AS p80_revenue
FROM seller_revenue;

-- Create mart schema for analytics and modeling tables
CREATE SCHEMA mart;

-- create seller revenue seller_revenue with logic based on order items product price  
DROP TABLE IF EXISTS mart.seller_revenue;

CREATE TABLE mart.seller_revenue AS
WITH seller_revenue AS (
    SELECT
        oi.seller_id,
        SUM(REPLACE(oi.price, ',', '.')::numeric) AS revenue
    FROM raw.order_items oi
    JOIN raw.closed_deals cd
        ON oi.seller_id = cd.seller_id
    GROUP BY oi.seller_id
),
p80 AS (
    SELECT
        percentile_cont(0.8) WITHIN GROUP (ORDER BY revenue) AS p80_revenue
    FROM seller_revenue
)
SELECT
    sr.seller_id,
    sr.revenue,
    CASE
        WHEN sr.revenue > p.p80_revenue THEN 1
        ELSE 0
    END AS high_value_seller
FROM seller_revenue sr
CROSS JOIN p80 p;

-- Validate initial seller_revenue table

SELECT COUNT(*) FROM mart.seller_revenue;

-- Inspect top sellers by revenue

SELECT *
FROM mart.seller_revenue
ORDER BY revenue DESC
LIMIT 10;

-- Check class balance for high-value vs normal sellers
SELECT
    high_value_seller,
    COUNT(*) AS seller_count
FROM mart.seller_revenue
GROUP BY high_value_seller;
-- Check revenue share of high-value vs normal sellers
SELECT
    high_value_seller,
    COUNT(*) AS sellers,
    SUM(revenue) AS total_revenue,
    ROUND(SUM(revenue) / SUM(SUM(revenue)) OVER (), 2) AS revenue_share
FROM mart.seller_revenue
GROUP BY high_value_seller;

-- Summary statistics for seller revenue distribution

SELECT
    MIN(revenue) AS min_revenue,
    PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY revenue) AS median_revenue,
    AVG(revenue) AS avg_revenue,
    MAX(revenue) AS max_revenue
FROM mart.seller_revenue;

-- Analyze high-value rate by lead origin / acquisition channel
SELECT
    COALESCE(NULLIF(m.origin, ''), 'missing') AS origin,
    COUNT(*) AS sellers,
    SUM(sr.high_value_seller) AS high_value_sellers,
    ROUND(AVG(sr.high_value_seller), 3) AS high_value_rate
FROM raw.marketing_qualified_leads m
JOIN raw.closed_deals cd
    ON m.mql_id = cd.mql_id
JOIN mart.seller_revenue sr
    ON cd.seller_id = sr.seller_id
GROUP BY origin
ORDER BY high_value_rate DESC;

-- Analyze high-value rate by business segment
SELECT
    COALESCE(NULLIF(cd.business_segment, ''), 'missing') AS business_segment,
    COUNT(*) AS sellers,
    SUM(sr.high_value_seller) AS high_value_sellers,
    ROUND(AVG(sr.high_value_seller), 3) AS high_value_rate
FROM raw.closed_deals cd
JOIN mart.seller_revenue sr
    ON cd.seller_id = sr.seller_id
GROUP BY business_segment
ORDER BY high_value_rate DESC;


-- Analyze total and average revenue by business segment

SELECT
    COALESCE(NULLIF(cd.business_segment, ''), 'missing') AS business_segment,
    COUNT(*) AS sellers,
    SUM(sr.revenue) AS total_revenue,
    ROUND(AVG(sr.revenue), 2) AS avg_revenue
FROM raw.closed_deals cd
JOIN mart.seller_revenue sr
    ON cd.seller_id = sr.seller_id
GROUP BY business_segment
ORDER BY total_revenue DESC;


-- Analyze high-value rate by lead behaviour profile

SELECT
    COALESCE(NULLIF(cd.lead_behaviour_profile, ''), 'missing') AS lead_behaviour_profile,
    COUNT(*) AS sellers,
    SUM(sr.high_value_seller) AS high_value_sellers,
    ROUND(AVG(sr.high_value_seller), 3) AS high_value_rate
FROM raw.closed_deals cd
JOIN mart.seller_revenue sr
    ON cd.seller_id = sr.seller_id
GROUP BY lead_behaviour_profile
ORDER BY high_value_rate DESC;

-- Create seller-level feature table for modeling

DROP TABLE IF EXISTS mart.ml_seller_features;

CREATE TABLE mart.ml_seller_features AS
SELECT
    cd.seller_id,

    COALESCE(NULLIF(m.origin, ''), 'missing') AS origin,
    COALESCE(NULLIF(cd.business_segment, ''), 'missing') AS business_segment,
    COALESCE(NULLIF(cd.lead_type, ''), 'missing') AS lead_type,
    COALESCE(NULLIF(cd.lead_behaviour_profile, ''), 'missing') AS lead_behaviour_profile,

    cd.has_company,
    cd.has_gtin,

    TO_DATE(cd.won_date, 'DD.MM.YYYY')
        - TO_DATE(m.first_contact_date, 'DD.MM.YYYY') AS time_to_close_days,

    sr.revenue,
    sr.high_value_seller

FROM raw.closed_deals cd
JOIN raw.marketing_qualified_leads m
    ON cd.mql_id = m.mql_id
JOIN mart.seller_revenue sr
    ON cd.seller_id = sr.seller_id;

-- Validate seller feature table

SELECT COUNT(*) FROM mart.ml_seller_features;

-- Check missing values to decide which features should be kept for modeling

SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN origin IS NULL OR origin = 'missing' THEN 1 ELSE 0 END) AS missing_origin,
    SUM(CASE WHEN business_segment IS NULL OR business_segment = 'missing' THEN 1 ELSE 0 END) AS missing_business_segment,
    SUM(CASE WHEN lead_type IS NULL OR lead_type = 'missing' THEN 1 ELSE 0 END) AS missing_lead_type,
    SUM(CASE WHEN lead_behaviour_profile IS NULL OR lead_behaviour_profile = 'missing' THEN 1 ELSE 0 END) AS missing_lead_behaviour_profile,
    SUM(CASE WHEN has_company IS NULL OR has_company = '' THEN 1 ELSE 0 END) AS missing_has_company,
    SUM(CASE WHEN has_gtin IS NULL OR has_gtin = '' THEN 1 ELSE 0 END) AS missing_has_gtin,
    SUM(CASE WHEN time_to_close_days IS NULL THEN 1 ELSE 0 END) AS missing_time_to_close_days
FROM mart.ml_seller_features;

-- Create final machine-learning dataset with selected features

DROP TABLE IF EXISTS mart.ml_model_dataset;

CREATE TABLE mart.ml_model_dataset AS
SELECT
    seller_id,
    origin,
    business_segment,
    lead_type,
    lead_behaviour_profile,
    time_to_close_days,
    revenue,
    high_value_seller
FROM mart.ml_seller_features;

-- Validate final model dataset

SELECT COUNT(*) FROM mart.ml_model_dataset;

-- Recreate read-only user permissions as in executed workflow
CREATE USER ds_user WITH PASSWORD '<SET_PASSWORD_MANUALLY>';

GRANT CONNECT ON DATABASE olist TO ds_user;

GRANT USAGE ON SCHEMA raw TO ds_user;
GRANT USAGE ON SCHEMA mart TO ds_user;

GRANT SELECT ON ALL TABLES IN SCHEMA raw TO ds_user;
GRANT SELECT ON ALL TABLES IN SCHEMA mart TO ds_user;

-- Repeated import/setup block kept as executed in the working script

DROP TABLE IF EXISTS mart.seller_analytics;

CREATE TABLE mart.seller_analytics AS
SELECT
    seller_id,
    revenue,
    high_value_seller,
    origin,
    lead_type,
    lead_behaviour_profile,
    business_segment,
    time_to_close_days
FROM mart.ml_model_dataset;

SELECT COUNT(*) FROM mart.seller_analytics;

GRANT SELECT ON mart.seller_analytics TO ds_user;
