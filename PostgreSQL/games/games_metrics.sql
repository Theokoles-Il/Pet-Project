-- Schema for final analytical views --
CREATE SCHEMA IF NOT EXISTS marts;
CREATE OR REPLACE VIEW marts.games_market_analytics AS

-- 1. Core aggregates per platform/genre combination --
WITH platform_metrics AS (
	SELECT
		platform,
		COALESCE(genre, 'Unknown') AS genre,
		COUNT(*) AS total_games,
		
		-- Average & median metrics for pricing and ratings (handles NULLs & skewed data) --
		COALESCE(ROUND(AVG(price)::numeric, 2), 0.00) AS avg_price,
		COALESCE(ROUND(AVG(rating)::numeric, 2), 0.00) AS avg_rating,
		
		COALESCE(ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY price)::numeric, 2), 0.00) AS median_price,
		COALESCE(ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY rating)::numeric, 2), 0.00) AS median_rating,
		
		COALESCE(ROUND(SUM(sales_m)::numeric, 2), 0.00) AS total_sales_m
	FROM staging.games_sales_cleaned
	GROUP BY platform, genre
),

-- 2. Distribution of games by rating quality(high vs low rated) --
rating_buckets AS (
	SELECT 
		platform,
		genre,
		COUNT(CASE WHEN rating >= 8 THEN 0 END) AS high_rated_games,
		COUNT(CASE WHEN rating < 5 THEN 0 END) AS low_rated_games
	FROM staging.games_sales_cleaned
	WHERE rating IS NOT NULL -- Exclude unrated games to ensure accurate category distribution
	GROUP BY platform, genre
)

-- 3. Final SELECT: join both CTEs, compute percentages, rank genres within each platform --
SELECT 
	pm.platform,
	pm.genre,
	pm.total_games,
	pm.avg_price,
	pm.median_price,
	pm.avg_rating,
	pm.median_rating,
	pm.total_sales_m,
	
	-- Share of highly-rated games, with zero-division safety & NULL safety -- 
	CASE
		WHEN NULLIF(pm.total_games, 0) IS NOT NULL
		THEN ROUND((COALESCE(rb.high_rated_games, 0)::numeric / pm.total_games) * 100, 2)
		ELSE 0.00
	END AS high_rated_pct,
	
	-- RANK of this genre's total sales within its platform --
	RANK() OVER (
		PARTITION BY pm.platform
		ORDER BY pm.total_sales_m DESC NULLS LAST
	) AS genre_sales_rank_in_platform
	
FROM platform_metrics pm
LEFT JOIN rating_buckets rb
	ON pm.platform = rb.platform
   AND pm.genre = rb.genre;
	
SELECT * 
FROM marts.games_market_analytics LIMIT 66;