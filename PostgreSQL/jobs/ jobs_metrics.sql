-- Create Schema marts for pre-built analytical views (VIEW) --
CREATE SCHEMA IF NOT EXISTS marts;
CREATE OR REPLACE VIEW marts.it_market_comprehensive_analytics AS

-- 1. Core market aggregates partitioned by granularity dimensions --
WITH category_metrics AS (
    SELECT
        work_year,
        job_category,
        experience_level, 
        employment_type,
        COUNT(*) AS total_vacancies, 
        SUM(salary_in_usd) AS total_payroll_usd,
        ROUND(AVG(salary_in_usd)::numeric, 2) AS avg_salary_usd,
        PERCENTILE_CONT(0.5) WITHIN GROUP(ORDER BY salary_in_usd) AS median_salary_usd 
    FROM staging.jobs_in_data_cleaned
    GROUP BY work_year, job_category, experience_level, employment_type
),

-- 2. CTE Distribution matrix for work settings (Remote, Hybrid, In-person) --
work_setting_metrics AS (
    SELECT
        work_year,
        job_category,
        experience_level, 
        employment_type,
        COUNT(CASE WHEN LOWER(work_setting) = 'remote' THEN 1 END) AS remote_vacancies, 
        COUNT(CASE WHEN LOWER(work_setting) = 'hybrid' THEN 1 END) AS hybrid_vacancies,
        COUNT(CASE WHEN LOWER(work_setting) = 'in-person' THEN 1 END) AS in_person_vacancies
    FROM staging.jobs_in_data_cleaned
    GROUP BY 1, 2, 3, 4
)

-- 3. Final Analytical Layer with percentages and window functions --
SELECT 
    cm.work_year,
    cm.job_category,
    cm.experience_level, 
    cm.employment_type,  

    -- Finances & Volumes
    cm.total_vacancies,
    cm.total_payroll_usd,
    cm.avg_salary_usd,
    cm.median_salary_usd,

    -- Work Setting Shares (%) with zero-division safety --
    CASE 
        WHEN NULLIF(cm.total_vacancies, 0) IS NOT NULL 
        THEN ROUND((COALESCE(wm.remote_vacancies, 0)::numeric / cm.total_vacancies) * 100, 2)
        ELSE 0.00  
    END AS remote_vacancies_pct,

    CASE 
        WHEN NULLIF(cm.total_vacancies, 0) IS NOT NULL 
        THEN ROUND((COALESCE(wm.hybrid_vacancies, 0)::numeric / cm.total_vacancies) * 100, 2)
        ELSE 0.00  
    END AS hybrid_vacancies_pct,

    CASE 
        WHEN NULLIF(cm.total_vacancies, 0) IS NOT NULL 
        THEN ROUND((COALESCE(wm.in_person_vacancies, 0)::numeric / cm.total_vacancies) * 100, 2)
        ELSE 0.00  
    END AS in_person_vacancies_pct,

    -- Category Salary Rank grouped by year and experience level --
    RANK() OVER (
        PARTITION BY cm.work_year, cm.experience_level
        ORDER BY cm.avg_salary_usd DESC
    ) AS category_salary_rank_by_exp

FROM category_metrics cm
LEFT JOIN work_setting_metrics wm
    ON cm.work_year = wm.work_year
   AND cm.job_category = wm.job_category
   AND cm.experience_level = wm.experience_level 
   AND cm.employment_type = wm.employment_type;

SELECT * FROM marts.it_market_comprehensive_analytics LIMIT 132;