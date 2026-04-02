-- =========================================
-- PROJECT CONTEXT
-- =========================================

-- Objective:
-- Analyze whether Contoso’s revenue performance is sustainable 
-- or driven by discount-heavy, low-value growth.

-- Focus Areas:
-- 1. Discount dependency across channels and categories
-- 2. Revenue growth drivers (volume vs value)
-- 3. Impact of discounting on profitability

-- Data Considerations:
-- - Data filtered to 2008–2009
-- - salesamount = 0 rows excluded (returns in online_sales)
-- - Online channel sourced from online_sales (no channelkey)
-- - AOV approximated at transaction level (no order-level data for offline sales)

-- =========================================
-- DATA PREPARATION: Combined Sales Dataset
-- =========================================

-- Purpose:
-- Combine online and offline sales into a unified structure 
-- for consistent analysis across channels

CREATE VIEW combined_sales AS
	SELECT
		s.productkey,
		s.salesamount,
		s.discountamount,
		s.totalcost,
		s.unitprice,
		s.unitcost,
		s.datekey,
		s.storekey,
		c.channelname
	FROM sales s
	JOIN channel c ON s.channelkey = c.channelkey
	WHERE c.channelname <> 'Online'
	
	UNION ALL
	
	SELECT
		os.productkey,
		os.salesamount,
		os.discountamount,
		os.totalcost,
		os.unitprice,
		os.unitcost,
		os.datekey,
		os.storekey,
		'Online' AS channelname
	FROM online_sales os
	WHERE os.salesamount > 0;

-- =========================================
-- Q1: Discount Dependency Analysis
-- =========================================

-- Business Question:
-- Which channels and product categories are most dependent on discounting?

-- Tables Used:
-- sales, online_sales, channel, clean_product, product_subcategory, product_category

-- Key Decisions:
-- - Combined online + offline sales using UNION ALL
-- - Used transaction-level counting for discount dependency
-- - Calculated margin before and after discount for comparison

-- Logic:
-- discount_dependency = discounted_transactions / total_transactions
-- Compare across channels and product categories

WITH sales_data AS(
	SELECT
		s.productkey,
		discountamount,
		(unitprice - unitcost) / unitprice * 100 AS margin_before_discount,
		(salesamount - totalcost) /salesamount * 100 AS margin_after_discount,
		c.channelname,
		p.productname,
		pc.productcategoryname,
		psc.productsubcategoryname
	FROM sales s
	JOIN channel c
		ON s.channelkey = c.channelkey
	JOIN clean_product p
		ON s.productkey = p.productkey
	JOIN product_subcategory psc
		ON p.productsubcategorykey = psc.productsubcategorykey
	JOIN product_category pc
		ON psc.productcategorykey = pc.productcategorykey	
	WHERE channelname <> 'Online'
	
	UNION ALL
	
	SELECT
		os.productkey,
		discountamount,
		(unitprice - unitcost) / unitprice * 100 AS margin_before_discount,
		(salesamount - totalcost) /salesamount * 100 AS margin_after_discount,
		'Online' AS channelname,
		p.productname,
		pc.productcategoryname,
		psc.productsubcategoryname
	FROM online_sales os
	JOIN clean_product p
		ON os.productkey = p.productkey
	JOIN product_subcategory psc
		ON p.productsubcategorykey = psc.productsubcategorykey
	JOIN product_category pc
		ON psc.productcategorykey = pc.productcategorykey
	WHERE salesamount <> 0		
	)
	SELECT
		productcategoryname,
		channelname,
		ROUND(AVG(margin_before_discount), 2) AS avg_margin_before_discount,
		ROUND(AVG(margin_after_discount), 2) AS avg_margin_after_discount,
		CAST(COUNT(*) AS NUMERIC) AS totaltransactions,
		CAST(COUNT(CASE WHEN discountamount > 0 THEN 1 END)AS NUMERIC) AS discountedtransactions,
		ROUND((CAST(COUNT(CASE WHEN discountamount > 0 THEN 1 END)AS NUMERIC) / CAST(COUNT(*) AS NUMERIC)) * 100 ,2) AS discountdependencypct
	FROM sales_data
	GROUP BY productcategoryname,
	channelname

-- =========================================
-- Q2: Growth Driver Analysis (Volume vs Value)
-- =========================================

-- Business Question:
-- Which channel or region is growing revenue through transaction volume rather than order value?

-- Tables Used:
-- sales, online_sales, channel, date, store, geography, sales_territory

-- Key Decisions:
-- - Combined online and offline sales data
-- - Used transaction count as proxy for volume
-- - AOV approximated as revenue per transaction line

-- Logic:
-- AOV = total revenue / total transactions
-- Compare trends across channels, regions, and years

WITH sales_data AS(
	SELECT
		c.channelname,
		s.salesamount,
		calendaryear,
		salesterritoryregion
	FROM sales s
	JOIN channel c
		ON s.channelkey = c.channelkey
	JOIN date d
		ON s.datekey = d.datekey
	JOIN store se
		ON s.storekey = se.storekey
	JOIN geography g
		ON se.geographykey = g.geographykey
	JOIN sales_territory st
		ON se.geographykey = st.geographykey
	WHERE channelname <> 'Online'
	
	UNION ALL
	
	SELECT
		'Online' AS channelname,
		os.salesamount,
		calendaryear,
		salesterritoryregion
	FROM online_sales os
	JOIN date d
		ON os.datekey = d.datekey
	JOIN store se
		ON os.storekey = se.storekey
	JOIN geography g
		ON se.geographykey = g.geographykey
	JOIN sales_territory st
		ON se.geographykey = st.geographykey
	WHERE salesamount > 0		
	)
	SELECT
		channelname,
		calendaryear,
		salesterritoryregion,
		CAST(COUNT(*) AS NUMERIC) AS totaltransactions,
		ROUND(SUM(salesamount) / CAST(COUNT(*) AS NUMERIC), 2) AS AOV
	FROM sales_data
	GROUP BY channelname, calendaryear, salesterritoryregion

-- -----------------------------------------
-- Supporting Analysis: Revenue Validation
-- -----------------------------------------

-- Purpose:
-- Validate whether AOV trends align with total revenue trends

WITH sales_data AS(
	SELECT
		c.channelname,
		s.salesamount,
		calendaryear
	FROM sales s
	JOIN channel c
		ON s.channelkey = c.channelkey
	JOIN date d
		ON s.datekey = d.datekey
	WHERE channelname <> 'Online'
	
	UNION ALL
	
	SELECT
		'Online' AS channelname,
		os.salesamount,
		calendaryear
	FROM online_sales os
	JOIN date d
		ON os.datekey = d.datekey
	WHERE salesamount > 0		
	)
	SELECT
		channelname,
		calendaryear,
		SUM(salesamount) AS totalrevenue
	FROM sales_data 
	GROUP BY channelname, calendaryear

-- =========================================
-- Q3: Discount Sustainability Analysis
-- =========================================

-- Business Question:
-- Is discount-driven revenue sustainable for long-term profitability?

-- Tables Used:
-- sales, online_sales, channel, date

-- Key Decisions:
-- - Calculated discount rate to measure discount depth
-- - Used margin after discount to evaluate profitability
-- - Compared trends across channels and years

-- Logic:
-- discount_rate = discount / (sales + discount)
-- margin_after_discount = (sales - cost) / sales
-- Analyze relationship between discounting and margins

WITH sales_data AS(
	SELECT
		c.channelname,
		d.calendaryear,
		discountamount / (salesamount + discountamount) * 100 AS discountrate,
		(salesamount - totalcost) / salesamount * 100 AS margin_after_discount
	FROM sales s
	JOIN channel c
		ON s.channelkey = c.channelkey
	JOIN date d
		ON s.datekey = d.datekey
	WHERE channelname <> 'Online'
	
	UNION ALL
	
	SELECT
		'Online' AS channelname,
		d.calendaryear,
		discountamount / (salesamount + discountamount) * 100 AS discountrate,
		(salesamount - totalcost) / salesamount * 100 AS margin_after_discount
	FROM online_sales os
	JOIN date d
		ON os.datekey = d.datekey
	WHERE salesamount > 0
	)
	SELECT
		channelname,
		calendaryear,
		ROUND(AVG(discountrate), 2) AS avg_discount_rate,
		ROUND(AVG(margin_after_discount), 2) AS avg_margin_after_discount
	FROM sales_data
	GROUP BY channelname, calendaryear
