-- ============================================================
-- CONTOSO REVENUE DECLINE INVESTIGATION
-- ============================================================

/*
Business Problem
----------------
Why did Online revenue quality deteriorate despite relatively
stable pricing conditions, and which product categories
contributed most to the decline?

Analytical Objective
--------------------
1. Separate pricing effects from structural category mix effects.
2. Validate whether deterioration represents a structural break.
3. Compare Online and Offline channel behaviour.
4. Classify product categories into strategic business signals.

Dataset
-------
Source : Microsoft Contoso Retail Dataset
Period : 2008–2009

Key Metric
----------
ARTL (Average Revenue per Transaction Line)

ARTL is used as a proxy for Average Order Value because
order-level identifiers are unavailable for Offline sales.
*/

-- ============================================================
-- STAGE 1
-- ROOT CAUSE INVESTIGATION
-- ============================================================

---------------------------------------------------------------
-- STEP 1A & 1B
-- ACTUAL VS STANDARD ARTL + PRICING GAP VALIDATION
---------------------------------------------------------------

-- Business Questions:
-- 1. Does Online ARTL deterioration persist after removing
--    discount effects?
-- 2. How much of the observed deterioration can be explained
--    by pricing differences?

-- Why this matters:
-- Comparing Actual and Standard ARTL allows pricing effects
-- to be separated from structural category mix effects.

-- Calculate actual revenue per transaction line (proxy for AOV)
-- Using line-level aggregation due to absence of order-level identifiers
-- This ensures consistency across online and offline datasets

WITH actual AS
(
	SELECT
		d.calendaryear,
		SUM(salesamount),
		COUNT(*),
		ROUND(SUM(salesamount) / COUNT(*), 2) as actual_ARTL
	FROM online_sales AS os
	JOIN date AS d
	ON d.datekey = os.datekey
	WHERE salesamount > 0
		GROUP BY d.calendaryear
)
-- Calculate standard-price revenue per line (removes discount impact)
-- Used to isolate pricing effect from product mix effect

, standard AS
(
	SELECT 
		d.calendaryear,
		SUM(salesquantity * unitprice),
		COUNT(*),
		ROUND(SUM(salesquantity * unitprice) / COUNT(*), 2) as standard_ARTL
	FROM online_sales AS os
	JOIN date AS d
	ON d.datekey = os.datekey
	WHERE salesamount > 0
	GROUP BY d.calendaryear
)
SELECT 
	a.calendaryear,
	actual_ARTL,
	standard_ARTL,
	ROUND((standard_ARTL - actual_ARTL) / standard_ARTL, 2) AS prct_gap
FROM actual as a
JOIN standard as s
ON a.calendaryear = s.calendaryear

-- Key Findings:
-- • Standard ARTL also declined between 2008 and 2009.
-- • The pricing gap explains only a limited portion of the
--   deterioration.
-- • The evidence supports a structural category mix shift
--   rather than a pricing-driven decline.

-- ============================================================
-- STAGE 1C
-- CATEGORY MIX VALIDATION
-- ============================================================

-- Business Question:
-- Which categories gained or lost share, and how does their
-- value profile affect Online ARTL?

WITH base_data AS
(
SELECT 
    pc.productcategoryname AS category,
    d.calendaryear AS year,
    COUNT(*) AS volume,
	
    -- total per year
    SUM(COUNT(*)) OVER (PARTITION BY d.calendaryear) AS total_volume,

    -- volume share per year
    COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY d.calendaryear) AS volume_share,

    -- category ARTL
    SUM(os.salesquantity * os.unitprice) / COUNT(*) AS category_ARTL

FROM online_sales AS os
JOIN date AS d
    ON os.datekey = d.datekey
JOIN product AS p
    ON p.productkey = os.productkey
JOIN product_subcategory AS psc
    ON p.productsubcategorykey = psc.productsubcategorykey
JOIN product_category AS pc
    ON psc.productcategorykey = pc.productcategorykey

WHERE os.salesamount > 0
GROUP BY pc.productcategoryname, d.calendaryear
),

-- pivot shares
shareperyear AS
(
SELECT 
    category,
    MAX(CASE WHEN year = 2008 THEN volume_share END) AS share_2008,
    MAX(CASE WHEN year = 2009 THEN volume_share END) AS share_2009
FROM base_data
GROUP BY category
),

-- overall ARTL using PARTITION 
overall_artl AS
(
SELECT DISTINCT
    year,
    SUM(category_ARTL * volume_share) OVER (PARTITION BY year) AS overall_ARTL
FROM base_data
),
sharechange AS
(
SELECT 
	category, 
	(share_2009 - share_2008) AS share_change 
FROM shareperyear 
)
SELECT
    sy.category,
    sy.share_2008,
    sy.share_2009,
    sc.share_change,

    bd.category_ARTL,
    oa.overall_ARTL,

    CASE 
        WHEN sc.share_change > 0 AND bd.category_ARTL < oa.overall_ARTL THEN 'Pulling down'
        WHEN sc.share_change > 0 AND bd.category_ARTL > oa.overall_ARTL THEN 'Pushing up'
        WHEN sc.share_change < 0 AND bd.category_ARTL < oa.overall_ARTL THEN 'Pushing up'
        WHEN sc.share_change < 0 AND bd.category_ARTL > oa.overall_ARTL THEN 'Pulling down'
        ELSE 'No impact'
    END AS impact_direction

FROM shareperyear AS sy 
JOIN sharechange AS sc 
	ON sy.category = sc.category

-- only 2009 category values
JOIN base_data bd
    ON sy.category = bd.category
   AND bd.year = 2009

-- join overall ARTL for 2009
JOIN overall_artl oa
    ON oa.year = 2009
ORDER BY 
    (sc.share_change * (bd.category_artl - oa.overall_artl)) ASC	;

-- Key Finding:
-- High-value categories lost share while lower-value categories
-- expanded, creating a structural deterioration in Online
-- revenue quality.

-- ============================================================
-- STAGE 2
-- STRUCTURAL BREAK VALIDATION
-- ============================================================

-- Business Question:
-- Is the decline gradual or concentrated within a specific
-- period?

SELECT
	*,
	(quarter_ARTL - previousquarter_ARTL)/ previousquarter_ARTL * 100 AS QoQ_ARTLchange

FROM
(
SELECT 
	d.calendarquarter AS quarter,

	COUNT(*) AS volume,

	SUM(os.salesquantity * os.unitprice) / COUNT(*)
		AS quarter_ARTL,

	LAG(SUM(os.salesquantity * os.unitprice) / COUNT(*))
		OVER(ORDER BY d.calendarquarter)
		AS previousquarter_ARTL

FROM online_sales AS os

JOIN date AS d
	ON os.datekey = d.datekey

WHERE salesamount > 0

GROUP BY d.calendarquarter

) AS q;

-- Key Finding:
-- Quarter-over-quarter ARTL analysis identifies Q1 2009 as a
-- clear structural break, with the largest observed decline.

-- ============================================================
-- STAGE 3
-- CHANNEL VALIDATION
-- ============================================================

-- Business Question:
-- Is the deterioration company-wide or isolated to the Online
-- channel?

WITH sales_data AS
(
SELECT 
	'Offline' AS channelname,
	d.calendarquarter AS quarter,
	COUNT(*) AS volume,
	SUM(s.salesquantity * s.unitprice) / COUNT(*)
		AS quarter_ARTL
FROM sales AS s
JOIN channel AS c
	ON s.channelkey = c.channelkey
JOIN date AS d
	ON s.datekey = d.datekey
WHERE c.channelname <> 'Online'
GROUP BY d.calendarquarter

UNION ALL

SELECT 
	'Online' AS channelname,
	d.calendarquarter AS quarter,
	COUNT(*) AS volume,
	SUM(os.salesquantity * os.unitprice) / COUNT(*)
		AS quarter_ARTL
FROM online_sales AS os
JOIN date AS d
	ON os.datekey = d.datekey
WHERE salesamount > 0
GROUP BY d.calendarquarter
),
lag_data AS
(
SELECT
	quarter,
	channelname,
	LAG(quarter_ARTL)
		OVER(PARTITION BY channelname ORDER BY quarter)
		AS previousquarter_ARTL
FROM sales_data
)		
SELECT
	sd.quarter,
	sd.channelname,
	sd.volume,
	sd.quarter_artl,
	ld.previousquarter_artl,
	(quarter_ARTL - previousquarter_ARTL)/ previousquarter_ARTL * 100 AS QoQ_ARTLchange
FROM sales_data AS sd
JOIN lag_data AS ld
	ON sd.quarter = ld.quarter
	AND sd.channelname = ld.channelname

-- Key Finding:
-- Offline ARTL remains comparatively stable while Online ARTL
-- experiences a significant decline, confirming that the issue
-- is channel-specific rather than enterprise-wide.

-- ============================================================
-- STAGE 4
-- STRATEGIC CATEGORY CLASSIFICATION
-- ============================================================

-- Business Question:
-- Which categories represent Recovery Opportunities,
-- Structural Drags, Weak but Self-Correcting categories,
-- or No Impact?

WITH base_data AS
(
SELECT 
    pc.productcategoryname AS category,
    d.calendaryear AS year,
    COUNT(*) AS volume,
	
    -- total per year
    SUM(COUNT(*)) OVER (PARTITION BY d.calendaryear) AS total_volume,

    -- volume share per year
    COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY d.calendaryear) AS volume_share,

    -- category ARTL
    SUM(os.salesquantity * os.unitprice) / COUNT(*) AS category_ARTL
	
FROM online_sales AS os
JOIN date AS d
    ON os.datekey = d.datekey
JOIN product AS p
    ON p.productkey = os.productkey
JOIN product_subcategory AS psc
    ON p.productsubcategorykey = psc.productsubcategorykey
JOIN product_category AS pc
    ON psc.productcategorykey = pc.productcategorykey

WHERE os.salesamount > 0
GROUP BY pc.productcategoryname, d.calendaryear
),

-- pivot shares
shareperyear AS
(
SELECT 
    category,
    MAX(CASE WHEN year = 2008 THEN volume_share END) AS share_2008,
    MAX(CASE WHEN year = 2009 THEN volume_share END) AS share_2009
FROM base_data
GROUP BY category
),

-- overall ARTL
overall_artl AS
(
SELECT
    SUM(os.salesquantity * os.unitprice) / COUNT(*) AS overall_artl
FROM online_sales os
JOIN date d
    ON os.datekey = d.datekey
WHERE d.calendaryear = 2008
  AND os.salesamount > 0
),	

sharechange AS
(
SELECT 
	category, 
	(share_2009 - share_2008) AS share_change 
FROM shareperyear 
),
final_output AS
(
SELECT
    sy.category,
    sy.share_2008,
    sy.share_2009,
    sc.share_change,

    bd.category_ARTL,
    oa.overall_ARTL,

    CASE
        WHEN sc.share_change > 0
             AND bd.category_ARTL < oa.overall_ARTL
             THEN 'Structural Drag'

        WHEN sc.share_change > 0
             AND bd.category_ARTL > oa.overall_ARTL
             THEN 'Core Strength'

        WHEN sc.share_change < 0
             AND bd.category_ARTL < oa.overall_ARTL
             THEN 'Weak but Self-Correcting'

        WHEN sc.share_change < 0
             AND bd.category_ARTL > oa.overall_ARTL
             THEN 'Recovery Opportunity'

        ELSE 'No Impact'
    END AS impact_direction

FROM shareperyear AS sy

JOIN sharechange AS sc
    ON sy.category = sc.category

JOIN base_data AS bd
    ON sy.category = bd.category
   AND bd.year = 2009

CROSS JOIN overall_artl AS oa
)
SELECT *
FROM final_output
ORDER BY
ABS(
    share_change *
    (category_ARTL - overall_ARTL)
) DESC;

-- Key Finding:
-- TV & Video, Home Appliances and Cameras & Camcorders
-- emerge as Recovery Opportunities, while Cell Phones and
-- Games & Toys act as Structural Drags on Online revenue
-- quality.

-- ============================================================
-- INVESTIGATION SUMMARY
-- ============================================================

/*
The investigation demonstrates that Online revenue quality
deterioration is primarily driven by structural category mix
changes rather than pricing effects.

High-value categories consistently lost transaction share while
lower-value categories gained prominence, reducing overall
Online ARTL.

These findings provide the analytical foundation for the Python
scenario modelling and Power BI executive dashboard included
elsewhere in this repository.
*/
