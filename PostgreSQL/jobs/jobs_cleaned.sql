-- We are creating a scheme for cleaning the data from these stages. --
CREATE SCHEMA IF NOT EXISTS staging;

-- Drop the table first, before starting the CTE chain --
DROP TABLE IF EXISTS staging.jobs_in_data_cleaned CASCADE;

-- Save cleaned data into staging.jobs_in_data_cleaned --
CREATE TABLE staging.jobs_in_data_cleaned AS

-- 1. CTE for normalizing text and searching for duplicates --
WITH cleaned_raw AS (
    SELECT
        work_year,
        TRIM(job_title) AS job_title,
        TRIM(job_category) AS job_category,
        UPPER(TRIM(salary_currency)) AS salary_currency,
        salary,
        salary_in_usd,
        UPPER(TRIM(employee_residence)) AS employee_residence,
        TRIM(experience_level) AS experience_level,
        TRIM(employment_type) AS employment_type,
        TRIM(work_setting) AS work_setting,
        UPPER(TRIM(company_location)) AS company_location,
        TRIM(company_size) AS company_size,
        -- ROW_NUMBER to find and remove absolute duplicates --
        ROW_NUMBER() OVER (
            PARTITION BY
                work_year,
                TRIM(job_title),
                salary_in_usd,
                UPPER(TRIM(employee_residence)),
                TRIM(experience_level)
            ORDER BY salary_in_usd DESC -- by default ASC --
        ) AS row_num
    FROM raw.jobs_in_data
    WHERE salary_in_usd IS NOT NULL
        AND salary_in_usd > 0
),

-- 2. CTE for ranking salaries and tracking year-over-year trends --
ranked_and_lagged AS (
    SELECT
        work_year,
        job_title,
        job_category,
        salary_currency,
        salary_in_usd,
        employee_residence,
        experience_level,
        employment_type,
        work_setting,
        company_location,
        company_size,
        -- RANK: Rank of vacancies by salary in the middle of the category --
        RANK() OVER(
            PARTITION BY job_category, experience_level
            ORDER BY salary_in_usd DESC -- by default ASC --
        ) AS salary_rank_in_category,
        -- LAG: Previous year's salary for the same job title --
        LAG(salary_in_usd) OVER (
            PARTITION BY job_title, experience_level
            ORDER BY work_year ASC 
        ) AS prev_year_salary_usd
    FROM cleaned_raw
    WHERE row_num = 1 -- Keep only unique records (deduplicated) --
)

-- 3. Final SELECT that becomes the table content --
SELECT 
    work_year,
    job_title,
    job_category,
    salary_currency,
    salary_in_usd,
    employee_residence,
    experience_level,
    employment_type,
    work_setting,
    company_location,
    company_size,
    salary_rank_in_category,
    COALESCE(prev_year_salary_usd, salary_in_usd) AS adjusted_prev_salary,
    (salary_in_usd - COALESCE(prev_year_salary_usd, salary_in_usd)) AS salary_diff_from_prev,
    -- Protection of input 0 and NULL --
    CASE 
        WHEN NULLIF(prev_year_salary_usd, 0) IS NOT NULL
        THEN ROUND(((salary_in_usd - prev_year_salary_usd)::numeric / prev_year_salary_usd) * 100, 2)
        ELSE 0.00
    END AS salary_growth_pct
FROM ranked_and_lagged;