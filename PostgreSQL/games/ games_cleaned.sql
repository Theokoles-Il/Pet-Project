-- Schema for cleaned data --
CREATE SCHEMA IF NOT EXISTS staging;

-- Drop the table first, before starting the CTE chain --
DROP TABLE IF EXISTS staging.games_sales_cleaned CASCADE;

CREATE TABLE staging.games_sales_cleaned AS

-- 1. Remove exact duplicate rows (same id was intentionally duplicated in the raw file) --
WITH deduped AS (
	SELECT DISTINCT ON (id) *
	FROM raw.games_sales
	ORDER BY id
),

-- 2. Normalize text, parse mixed date formats, and null out corrupted numeric values --
normalized AS (
	SELECT
		id,
		COALESCE(INITCAP(TRIM("gameNm")), 'Unknown Game') AS game_name,
		
		-- Platform values arrive in inconsistent casing/naming - map them to fixed categories --
		CASE
			WHEN UPPER(TRIM(platform)) IN ('PC', 'P.C.') THEN 'PC'
			WHEN UPPER(TRIM(platform)) LIKE 'PLAYSTATION%' OR UPPER(TRIM(platform)) = 'PS' THEN 'PlayStation'
			WHEN UPPER(TRIM(platform)) LIKE 'XBOX%' THEN 'Xbox'
			WHEN UPPER(TRIM(platform)) LIKE '%SWITCH%' THEN 'Switch'
			WHEN UPPER(TRIM(platform)) LIKE 'MOBILE' OR UPPER(TRIM(platform)) = 'IOS/ANDROID' THEN 'Mobile'
			ELSE 'Unknown'
		END AS platform_clean,
		
		TRIM(genre) AS genre,
		
		--
		CASE
    		-- 1. ISO formats (Year ahead: YYYY-MM-DD, YYYY/MM/DD, YYYY.MM.DD) --
		    WHEN release_dt ~ '^\d{4}-\d{1,2}-\d{1,2}$' THEN TO_DATE(release_dt, 'YYYY-MM-DD')
		    WHEN release_dt ~ '^\d{4}/\d{1,2}/\d{1,2}$' THEN TO_DATE(release_dt, 'YYYY/MM/DD')
		    WHEN release_dt ~ '^\d{4}\.\d{1,2}\.\d{1,2}$' THEN TO_DATE(release_dt, 'YYYY.MM.DD')
		
		    -- 2. Special format for the US format (MM-DD-YYYY): if the first number is <= 12 and the second is > 12. --
		    WHEN release_dt ~ '^\d{1,2}-\d{1,2}-\d{4}$' 
		         AND SPLIT_PART(release_dt, '-', 1)::INT <= 12 
		         AND SPLIT_PART(release_dt, '-', 2)::INT > 12 
		         THEN TO_DATE(release_dt, 'MM-DD-YYYY')
		
		    -- 3. EU formats with a period or slash (DD.MM.YYYY or DD/MM/YYYY) --
		    WHEN release_dt ~ '^\d{1,2}\.\d{1,2}\.\d{4}$' THEN TO_DATE(release_dt, 'DD.MM.YYYY')
		    WHEN release_dt ~ '^\d{1,2}/\d{1,2}/\d{4}$' THEN TO_DATE(release_dt, 'DD/MM/YYYY')
		    
		    -- 4. Standard 4-digit hyphenated formats (default: US MM-DD-YYYY) --
		    WHEN release_dt ~ '^\d{1,2}-\d{1,2}-\d{4}$' THEN TO_DATE(release_dt, 'MM-DD-YYYY')
		
		    -- 5. Abbreviated years (YY instead of YYYY): for example, 15/03/24 or 2024-05-12 --
		    WHEN release_dt ~ '^\d{1,2}/\d{1,2}/\d{2}$' THEN TO_DATE(release_dt, 'DD/MM/YY')
		    WHEN release_dt ~ '^\d{1,2}-\d{1,2}-\d{2}$' THEN TO_DATE(release_dt, 'MM-DD-YY')
		
		    -- 6. Text-based months (for example: 15-Mar-2024, Mar 15, 2024) --
		    WHEN release_dt ~* '^\d{1,2}-[a-z]{3}-\d{4}$' THEN TO_DATE(release_dt, 'DD-Mon-YYYY')
		    WHEN release_dt ~* '^[a-z]{3} \d{1,2}, \d{4}$' THEN TO_DATE(release_dt, 'Mon DD, YYYY')

	    	ELSE NULL
		END AS release_date,
		
		-- Negative prices and unrealistic placeholdes values (999.999 / 1500.00) are treated as corrupted --
		CASE 
			WHEN price IS NULL OR price <= 0 OR price > 200 THEN NULL
			ELSE price
		END AS price_clean,
		
		-- Rating must stay within the 0-10 scale; anything outside that range is invalid data --
		CASE
			WHEN rating IS NULL OR rating < 0 OR rating > 10 THEN NULL
			ELSE rating
		END AS rating_clean,
		
		-- Sales above 50M are unrealistic outliers for this dataset --
		CASE 
			WHEN sales_m IS NULL OR sales_m > 50 THEN NULL
			ELSE sales_m
		END AS sales_m_clean
		
	FROM deduped
)

-- 3. Final SELECT: rank each game's sales within its own platform --
SELECT
	id,
	game_name,
	platform_clean AS platform,
	genre,
	release_date,
	price_clean AS price,
	rating_clean AS rating,
	sales_m_clean AS sales_m,
	
	-- RANK: how this game's sales compare to others on the same platfrom --
	RANK() OVER (
		PARTITION BY platform_clean
		ORDER BY sales_m_clean DESC NULLS LAST 
	) AS sales_rank_in_platform
	
FROM normalized;

