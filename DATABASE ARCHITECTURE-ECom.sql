-- ====================================================================
-- E-COMMERCE BUSINESS INTELLIGENCE PLATFORM: DATABASE ARCHITECTURE
-- Database: practicezero
-- Engine: MySQL 8.0+
-- Description: Core schema, recursive date dimension, indexes, 
--              and analytical reporting marts for Power BI dashboards.
-- ====================================================================

CREATE DATABASE IF NOT EXISTS practicezero;
USE practicezero;

-- =====================================================
-- Creating order_item_refunds Table
-- =====================================================
CREATE TABLE order_item_refunds (
   order_item_refund_id INT  auto_increment PRIMARY KEY,
    created_at TIMESTAMP,
    order_item_id INT NOT NULL,
    order_id INT NOT NULL,
    refund_amount_usd DECIMAL(10, 2) NOT NULL);

-- =====================================================
-- -- Creating order_items Table
-- =====================================================
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    is_primary_item BOOLEAN DEFAULT 0,
    price_usd DECIMAL(10, 2) NOT NULL,
    cogs_usd DECIMAL(10, 2) NOT NULL,

    CONSTRAINT fk_orderitem_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(order_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_orderitem_product 
        FOREIGN KEY (product_id) 
        REFERENCES products(product_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
);

-- =====================================================
-- 1. PARENT TABLE: products
-- =====================================================
CREATE TABLE products (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    product_name VARCHAR(100) NOT NULL
) ENGINE=InnoDB;

-- =====================================================
-- 2. PARENT TABLE: website_sessions
-- =====================================================
CREATE TABLE website_sessions (
    website_session_id INT AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    user_id INT NOT NULL,
    is_repeat_session BOOLEAN DEFAULT 0,
    utm_source VARCHAR(50) DEFAULT NULL,
    utm_campaign VARCHAR(50) DEFAULT NULL,
    utm_content VARCHAR(50) DEFAULT NULL,
    device_type VARCHAR(20) DEFAULT NULL,    -- e.g., 'mobile', 'desktop'
    http_referer VARCHAR(255) DEFAULT NULL,

    INDEX idx_user_id (user_id),		
	INDEX idx_utm_source_campaign (utm_source, utm_campaign)			
															
) ENGINE=InnoDB;

-- INDEX idx_user_id (user_id)  *******
-- These two indexes are added to optimize the most frequent queries run on web traffic data: user journey analysis and marketing campaign attribution.
-- Without indexes, MySQL must perform a Full Table Scan—reading every single row on disk one by one—which makes queries crawl once the table reaches hundreds of thousands of sessions 

-- INDEX idx_utm_source_campaign (utm_source, utm_campaign) *****
-- INDEX idx_utm_source_campaign (utm_source, utm_campaign)--
-- 	This is a composite (multi-column) index built specifically for marketing performance analysis.
-- 	This index creates a fast B-tree lookup on the visitor's ID.

-- =====================================================
-- 3. CHILD TABLE: website_pageviews
-- =====================================================
CREATE TABLE website_pageviews (
    website_pageview_id INT AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    website_session_id INT NOT NULL,
    pageview_url VARCHAR(255) NOT NULL,

    INDEX idx_pageview_url (pageview_url),

    CONSTRAINT fk_pageviews_session
        FOREIGN KEY (website_session_id)
        REFERENCES website_sessions(website_session_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================
-- 4. CHILD TABLE: orders
-- =====================================================
CREATE TABLE orders (
    order_id INT AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    website_session_id INT NOT NULL,
    user_id INT NOT NULL,
    primary_product_id INT NOT NULL,
    items_purchased INT NOT NULL DEFAULT 1,
    price_usd DECIMAL(10, 2) NOT NULL,
    cogs_usd DECIMAL(10, 2) NOT NULL,

    INDEX idx_user_id (user_id),

    CONSTRAINT fk_orders_session
        FOREIGN KEY (website_session_id)
        REFERENCES website_sessions(website_session_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE,

    CONSTRAINT fk_orders_primary_product
        FOREIGN KEY (primary_product_id)
        REFERENCES products(product_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================
-- 5. LINE ITEMS TABLE: order_items (From Previous Step)
-- =====================================================
CREATE TABLE order_items (
    order_item_id INT AUTO_INCREMENT PRIMARY KEY,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    order_id INT NOT NULL,
    product_id INT NOT NULL,
    is_primary_item BOOLEAN DEFAULT 0,
    price_usd DECIMAL(10, 2) NOT NULL,
    cogs_usd DECIMAL(10, 2) NOT NULL,

    CONSTRAINT fk_orderitem_order 
        FOREIGN KEY (order_id) 
        REFERENCES orders(order_id)
        ON DELETE CASCADE
        ON UPDATE CASCADE,

    CONSTRAINT fk_orderitem_product 
        FOREIGN KEY (product_id) 
        REFERENCES products(product_id)
        ON DELETE RESTRICT
        ON UPDATE CASCADE
) ENGINE=InnoDB;

-- =====================================================
-- Now Loading Data Into Tables From the CSV File of a Large Industrial Data.
-- Main Source - Maven Analytics
-- =====================================================
SET GLOBAL local_infile = 1;
SET FOREIGN_KEY_CHECKS = 0; -- Disables FK validation during bulk loading
SET autocommit = 0;         -- Speeds up bulk imports drastically

LOAD DATA LOCAL INFILE 'E:/Project_Datasets/products.csv'
INTO TABLE products
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(product_id, created_at, product_name);


LOAD DATA LOCAL INFILE 'E:/Project_Datasets/website_sessions.csv'
INTO TABLE website_sessions
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    website_session_id, 
    created_at, 
    user_id, 
    is_repeat_session, 
    @utm_source, 
    @utm_campaign, 
    @utm_content, 
    @device_type, 
    @http_referer
)
SET 
    utm_source = NULLIF(@utm_source, ''),
    utm_campaign = NULLIF(@utm_campaign, ''),
    utm_content = NULLIF(@utm_content, ''),
    device_type = NULLIF(@device_type, ''),
    http_referer = NULLIF(@http_referer, '');
    
LOAD DATA LOCAL INFILE 'E:/Project_Datasets/website_pageviews.csv'
INTO TABLE website_pageviews
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    website_pageview_id, 
    created_at, 
    website_session_id, 
    pageview_url
);

LOAD DATA LOCAL INFILE 'E:/Project_Datasets/orders.csv'
INTO TABLE orders
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    order_id, 
    created_at, 
    website_session_id, 
    user_id, 
    primary_product_id, 
    items_purchased, 
    price_usd, 
    cogs_usd
);

LOAD DATA LOCAL INFILE 'E:/Project_Datasets/order_items.csv'
INTO TABLE order_items
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    order_item_id, 
    created_at, 
    order_id, 
    product_id, 
    is_primary_item, 
    price_usd, 
    cogs_usd
);

LOAD DATA LOCAL INFILE 'E:/Project_Datasets/order_item_refunds.csv'
INTO TABLE order_item_refunds
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\r\n'
IGNORE 1 ROWS
(
    order_item_refund_id, 
    created_at, 
    order_item_id, 
    order_id, 
    refund_amount_usd
);

COMMIT;

SET FOREIGN_KEY_CHECKS = 1;
SET autocommit = 1;

-- Checking Data Accuracy & Protection
SELECT 'products' AS table_name, COUNT(*) AS row_count FROM products
UNION ALL
SELECT 'website_sessions', COUNT(*) FROM website_sessions
UNION ALL
SELECT 'website_pageviews', COUNT(*) FROM website_pageviews
UNION ALL
SELECT 'orders', COUNT(*) FROM orders
UNION ALL
SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL
SELECT 'order_item_refunds', COUNT(*) FROM order_item_refunds;

-- Finding Max & Min Date From The Whole Data Set
    SELECT 
    MIN(min_date) AS absolute_min_date,
    MAX(max_date) AS absolute_max_date
FROM (
    SELECT CAST(MIN(created_at) AS DATE) AS min_date, CAST(MAX(created_at) AS DATE) AS max_date FROM website_sessions
    UNION ALL
    SELECT CAST(MIN(created_at) AS DATE), CAST(MAX(created_at) AS DATE) FROM website_pageviews
    UNION ALL
    SELECT CAST(MIN(created_at) AS DATE), CAST(MAX(created_at) AS DATE) FROM orders
    UNION ALL
    SELECT CAST(MIN(created_at) AS DATE), CAST(MAX(created_at) AS DATE) FROM order_items
    UNION ALL
    SELECT CAST(MIN(created_at) AS DATE), CAST(MAX(created_at) AS DATE) FROM order_item_refunds
) AS date_boundaries;

-- Creating Date Table
set foreign_key_checks = 0;
drop table if exists dim_date;
set foreign_key_checks = 1;
CREATE TABLE dim_date (
    date_id DATE PRIMARY KEY,
    year INT NOT NULL,
    quarter INT NOT NULL,
    month INT NOT NULL,
    month_name VARCHAR(15) NOT NULL,
    week INT NOT NULL,
    day_of_week VARCHAR(15) NOT NULL,
    is_weekend BOOLEAN NOT NULL
);
-- Checking
SELECT 
    COUNT(*) AS total_days,
    MIN(date_id) AS earliest_date,
    MAX(date_id) AS latest_date
FROM dim_date;

-- Procedure or recursive CTE to populate dates:
SET SESSION cte_max_recursion_depth = 5000;

INSERT INTO dim_date
WITH RECURSIVE date_series AS (
    SELECT '2012-01-01' AS dt
    UNION ALL
    SELECT dt + INTERVAL 1 DAY FROM date_series WHERE dt < '2015-04-02'
)
SELECT 
    dt AS date_id,
    YEAR(dt) AS year,
    QUARTER(dt) AS quarter,
    MONTH(dt) AS month,
    MONTHNAME(dt) AS month_name,
    WEEK(dt, 1) AS week,
    DAYNAME(dt) AS day_of_week,
    IF(DAYOFWEEK(dt) IN (1, 7), 1, 0) AS is_weekend
FROM date_series;

-- The large Data Set not Loaded properly Due to mixed Characters like \
-- So for the resolution i have Changed from \r\n to \n 
SET FOREIGN_KEY_CHECKS = 0;
TRUNCATE TABLE website_pageviews;

LOAD DATA LOCAL INFILE 'E:/Project_Datasets/website_pageviews.csv'
INTO TABLE website_pageviews
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'    -- Changed from \r\n to \n
IGNORE 1 ROWS
(website_pageview_id, created_at, website_session_id, pageview_url);

SET FOREIGN_KEY_CHECKS = 1;

-- Now the Full Data hase Been Loaded (More Than 1 M rows)
SELECT COUNT(*) FROM website_pageviews;


    
		-- 1. Products with the Highest Refund Rate
select 
p.product_id,
p.product_name,
count(distinct oi.order_item_id) as total_units_sold,
count(distinct oir.order_item_refund_id) as total_units_refunded,
round(count(distinct oir.order_item_refund_id)/count(distinct oi.order_item_id) * 100, 2) as refund_rate_perc,
round(sum(oi.price_usd),2) as gross_revenue,
round(coalesce(sum(oir.refund_amount_usd),0), 2) as total_amount_refunded_usd
from products p
join order_items oi
	on p.product_id = oi.product_id
left join order_item_refunds oir
	on oi.order_item_id = oir.order_item_id
group by p.product_id, p.product_name
order by refund_rate_perc desc
limit 1;

-- 2. Highest-Selling Products (Volume vs. Net Revenue)

select 
p.product_name,
count( distinct oi.order_item_id) as highest_selling_product,
round(sum(oi.price_usd),2) as total_revenue,
round(sum(oi.cogs_usd),2) as total_cogs,
round((sum(oi.price_usd)-sum(oi.cogs_usd))-coalesce(sum(oir.refund_amount_usd)),2) as net_profit
from products p
join order_items oi
	on p.product_id = oi.product_id
left join order_item_refunds oir
	on oi.order_item_id = oir.order_item_id
group by p.product_name
order by highest_selling_product desc
limit 1;

-- 3. Total Successful Orders vs. Refunded Orders

select 
count(distinct o.order_id) as total_orders_placed,
count(distinct 
			case
				when oir.order_item_refund_id is null Then o.order_id
			End) as fully_successful_orders,
count(distinct 
			case
				when oir.order_item_refund_id is not null Then o.order_id
			End) as refunded_orders,
round(count(distinct 
			case when oir.order_item_refund_id is null Then o.order_id End)/count(distinct o.order_id)*100, 2
		) as successful_order_pct,
round(sum(oi.price_usd),2) as total_gross_revenue
from orders o
left join order_items oi
	on o.order_id= oi.order_id
left join order_item_refunds oir
	on oi.order_item_id = oir.order_item_id;
;




-- Creating New Separated Date and Time Columns in the Tables from the Existing Column created_at

-- =====================================================
-- 1. PARENT TABLE: products
-- =====================================================
ALTER TABLE products
ADD COLUMN product_created_date DATE GENERATED ALWAYS AS (CAST(created_at AS DATE)) STORED,
ADD COLUMN product_created_time TIME GENERATED ALWAYS AS (CAST(created_at AS TIME)) STORED,
ADD COLUMN product_created_hour TINYINT GENERATED ALWAYS AS (HOUR(created_at)) STORED;

-- =====================================================
-- 2. CHILD TABLE: website_pageviews
-- =====================================================
ALTER TABLE website_pageviews
ADD COLUMN pageview_date DATE GENERATED ALWAYS AS (CAST(created_at AS DATE)) STORED,
ADD COLUMN pageview_time TIME GENERATED ALWAYS AS (CAST(created_at AS TIME)) STORED,
ADD COLUMN pageview_hour TINYINT GENERATED ALWAYS AS (HOUR(created_at)) STORED;

-- =====================================================
-- 3. CHILD TABLE: orders
-- =====================================================
ALTER TABLE orders
ADD COLUMN order_date DATE GENERATED ALWAYS AS (CAST(created_at AS DATE)) STORED,
ADD COLUMN order_time TIME GENERATED ALWAYS AS (CAST(created_at AS TIME)) STORED,
ADD COLUMN order_hour TINYINT GENERATED ALWAYS AS (HOUR(created_at)) STORED;

-- =====================================================
-- 4. LINE ITEMS TABLE: order_items
-- =====================================================
ALTER TABLE order_items
ADD COLUMN item_date DATE GENERATED ALWAYS AS (CAST(created_at AS DATE)) STORED,
ADD COLUMN item_time TIME GENERATED ALWAYS AS (CAST(created_at AS TIME)) STORED,
ADD COLUMN item_hour TINYINT GENERATED ALWAYS AS (HOUR(created_at)) STORED;

-- =====================================================
-- 5. REFUNDS TABLE: order_item_refunds
-- =====================================================
ALTER TABLE order_item_refunds
ADD COLUMN refund_date DATE GENERATED ALWAYS AS (CAST(created_at AS DATE)) STORED,
ADD COLUMN refund_time TIME GENERATED ALWAYS AS (CAST(created_at AS TIME)) STORED,
ADD COLUMN refund_hour TINYINT GENERATED ALWAYS AS (HOUR(created_at)) STORED;
-- -----------------------------------------------------------------------------------------

USE practicezero;

-- Using a database view instead of raw tables for visualizations provides a centralized, secure, and pre-optimized dataset that dramatically speeds up dashboard performance and simplifies report maintenance.
CREATE OR REPLACE VIEW practicezero.vw_dim_products AS
SELECT 
    product_id,
    product_name,
    product_created_date
FROM products;


CREATE OR REPLACE VIEW practicezero.vw_fact_sessions AS
SELECT 
    website_session_id,
    user_id,
    session_date,
    session_time,
    session_hour,
    is_repeat_session,
    COALESCE(utm_source, 'direct') AS utm_source,
    COALESCE(utm_campaign, 'none') AS utm_campaign,
    COALESCE(utm_content, 'none') AS utm_content,
    COALESCE(device_type, 'unknown') AS device_type,
    COALESCE(http_referer, 'direct') AS http_referer
FROM website_sessions;

CREATE OR REPLACE VIEW practicezero.vw_fact_order_items AS
SELECT 
    oi.order_item_id,
    oi.order_id,
    oi.item_date AS order_date,
    oi.item_time AS order_time,
    oi.item_hour AS order_hour,
    o.user_id,
    o.website_session_id,
    oi.product_id,
    oi.is_primary_item,
    oi.price_usd,
    oi.cogs_usd,
    ROUND(oi.price_usd - oi.cogs_usd, 2) AS gross_profit_usd
FROM order_items oi
JOIN orders o ON oi.order_id = o.order_id;

CREATE OR REPLACE VIEW practicezero.vw_fact_refunds AS
SELECT 
    order_item_refund_id,
    order_item_id,
    order_id,
    refund_date,
    refund_time,
    refund_hour,
    refund_amount_usd
FROM order_item_refunds;

CREATE OR REPLACE VIEW practicezero.vw_custom_funnel_dropoff AS
SELECT 
    s.website_session_id,
    s.session_date,
    s.device_type,
    s.utm_source,
    -- Funnel Step Flags (1 = reached step, 0 = dropped before)
    MAX(CASE WHEN p.pageview_url IN ('/home', '/lander-1', '/lander-2', '/lander-3', '/lander-4', '/lander-5') THEN 1 ELSE 0 END) AS step_1_lander,
    MAX(CASE WHEN p.pageview_url = '/products' THEN 1 ELSE 0 END) AS step_2_products,
    MAX(CASE WHEN p.pageview_url LIKE '/the-%' THEN 1 ELSE 0 END) AS step_3_product_detail,
    MAX(CASE WHEN p.pageview_url = '/cart' THEN 1 ELSE 0 END) AS step_4_cart,
    MAX(CASE WHEN p.pageview_url = '/shipping' THEN 1 ELSE 0 END) AS step_5_shipping,
    MAX(CASE WHEN p.pageview_url = '/billing' OR p.pageview_url = '/billing-2' THEN 1 ELSE 0 END) AS step_6_billing,
    MAX(CASE WHEN p.pageview_url = '/thank-you-for-your-order' THEN 1 ELSE 0 END) AS step_7_thank_you
FROM website_sessions s
LEFT JOIN website_pageviews p ON s.website_session_id = p.website_session_id
GROUP BY 
    s.website_session_id, 
    s.session_date, 
    s.device_type, 
    s.utm_source;
    
CREATE OR REPLACE VIEW practicezero.vw_custom_product_refund_leakage AS
SELECT 
    p.product_id,
    p.product_name,
    COUNT(DISTINCT oi.order_item_id) AS total_units_sold,
    COUNT(DISTINCT oir.order_item_refund_id) AS total_units_refunded,
    ROUND(COUNT(DISTINCT oir.order_item_refund_id) / COUNT(DISTINCT oi.order_item_id) * 100, 2) AS refund_rate_pct,
    ROUND(SUM(oi.price_usd), 2) AS gross_revenue_usd,
    ROUND(COALESCE(SUM(oir.refund_amount_usd), 0), 2) AS total_refund_amount_usd,
    ROUND(SUM(oi.price_usd) - COALESCE(SUM(oir.refund_amount_usd), 0), 2) AS net_revenue_usd,
    ROUND(COALESCE(SUM(oir.refund_amount_usd), 0) / SUM(oi.price_usd) * 100, 2) AS refund_to_revenue_loss_pct
FROM products p
JOIN order_items oi ON p.product_id = oi.product_id
LEFT JOIN order_item_refunds oir ON oi.order_item_id = oir.order_item_id
GROUP BY 
    p.product_id, 
    p.product_name;
    
CREATE OR REPLACE VIEW practicezero.vw_custom_cross_sell_matrix AS
SELECT 
	
    p1.product_name AS primary_product,
    p2.product_name AS cross_sold_product,
    COUNT(DISTINCT oi_cross.order_id) AS times_bought_together,
    ROUND(SUM(oi_cross.price_usd), 2) AS cross_sell_revenue_generated
FROM order_items oi_primary
JOIN order_items oi_cross 
    ON oi_primary.order_id = oi_cross.order_id 
    AND oi_primary.order_item_id <> oi_cross.order_item_id
JOIN products p1 ON oi_primary.product_id = p1.product_id
JOIN products p2 ON oi_cross.product_id = p2.product_id
WHERE oi_primary.is_primary_item = 1 
  AND oi_cross.is_primary_item = 0
GROUP BY 
    p1.product_name, 
    p2.product_name;
    
ALTER TABLE orders ADD INDEX idx_user_created (user_id, created_at);


CREATE OR REPLACE VIEW practicezero.vw_custom_customer_cohorts AS
WITH customer_order_ranking AS (
    SELECT 
		o.website_session_id,
        o.order_id,
        o.user_id,
        o.created_at,
        CAST(o.created_at AS DATE) AS order_date,
        o.price_usd,
        ROW_NUMBER() OVER (PARTITION BY o.user_id ORDER BY o.created_at) AS order_sequence_number,
        MIN(CAST(o.created_at AS DATE)) OVER (PARTITION BY o.user_id) AS first_order_date
    FROM orders o
)
SELECT 
	website_session_id
    order_id,
    user_id,
    order_date,
    first_order_date,
    DATE_FORMAT(first_order_date, '%Y-%m') AS cohort_month,
    order_sequence_number,
    CASE WHEN order_sequence_number = 1 THEN 'New Customer' ELSE 'Repeat Customer' END AS customer_order_type,
    DATEDIFF(order_date, first_order_date) AS days_since_first_order,
    price_usd AS order_revenue
FROM customer_order_ranking;

CREATE OR REPLACE VIEW practicezero.vw_custom_hourly_conversion AS
SELECT 
	s.website_session_id,
    s.session_hour,
    s.device_type,
    COUNT(DISTINCT s.website_session_id) AS total_sessions,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(COUNT(DISTINCT o.order_id) / COUNT(DISTINCT s.website_session_id) * 100, 2) AS hourly_conversion_rate_pct,
    ROUND(COALESCE(SUM(o.price_usd), 0), 2) AS gross_revenue_usd
FROM website_sessions s
LEFT JOIN orders o ON s.website_session_id = o.website_session_id
GROUP BY 
    s.session_hour, 
    s.device_type,
    s.website_session_id;
    
-- All Tables
select * from dim_date;
select * from products;
select * from order_item_refunds;
select * from order_items;
select * from orders;
select * from website_sessions;
select * from website_pageviews;

-- All Views (Except The Table dim_date)
select * from dim_date;
select * from vw_dim_products;
select * from vw_fact_sessions;
select * from vw_fact_order_items;
select * from vw_fact_refunds;
select * from vw_custom_funnel_dropoff;
select * from vw_custom_product_refund_leakage;
select * from vw_custom_cross_sell_matrix;
select * from vw_custom_customer_cohorts;
select * from vw_custom_hourly_conversion;

