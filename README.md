# Pet-Project
Data cleaning & analysis pipeline built with PostgreSQL, Python (Pandas), and Docker — following a Bronze → Silver → Gold architecture (raw → staging → marts).

## Status

✅ Data ingestion (raw layer)
✅ Data cleaning & transformation (staging layer)
✅ Analytical views with business metrics (marts layer)
🔲 Visualization (Tableau) — in progress

## Tech Stack

- **PostgreSQL** — database, running in Docker
- **Python / Pandas** — data ingestion from CSV into PostgreSQL
- **SQL** — CTEs, window functions (`ROW_NUMBER`, `RANK`, `LAG`), `CASE WHEN`, `COALESCE`, `NULLIF`
- **Docker** — local PostgreSQL environment
- **Git** — version control
- **Tableau** — dashboards (coming soon)

## Datasets

Two independent datasets, each with its own cleaning and metrics pipeline:

### 1. Data Jobs Market (`jobs/`)
Job listings in the data industry (job title, category, salary, experience level, work setting, location).

### 2. Games Sales (`games/`)
Intentionally messy synthetic dataset simulating real-world data quality issues: inconsistent casing, mixed date formats, NULLs, duplicates, and outliers.

## Project Structure

Pet-Project/
├── ingest.py # Loads raw CSV data into PostgreSQL (raw schema)
├── games_sales_raw.csv
├── jobs_in_data.csv
├── PostgreSQL/
│ ├── jobs/
│ │ ├── jobs_cleaned.sql # Staging: dedup, normalize text, rank & lag salaries
│ │ └── jobs_metrics.sql # Marts: aggregated view with business metrics
│ └── games/
│ ├── games_cleaned.sql # Staging: dedup, normalize platform/dates, clean outliers
│ └── games_metrics.sql # Marts: aggregated view with business metrics
└── README.md


## Architecture

raw → games_sales, jobs_in_data (loaded as-is via Pandas)
staging → games_sales_cleaned, jobs_in_data_cleaned (deduplicated, normalized)
marts → games_market_analytics, it_market_comprehensive_analytics (aggregated views)


## Data Cleaning Highlights

**Jobs pipeline:**
- Deduplication via `ROW_NUMBER()` on key fields
- Salary ranking within category/experience level via `RANK()`
- Year-over-year salary comparison via `LAG()`
- Safe percentage growth calculation (division-by-zero protection via `NULLIF`)

**Games pipeline:**
- Platform name normalization (handles inconsistent casing: `PC`, `pc`, `Pc`, etc.)
- Multi-format date parsing (ISO, US, EU, abbreviated years, text-based months) via regex pattern matching
- Outlier detection for price, rating, and sales figures
- `NULL` values preserved as `NULL` (not silently converted to 0) in the cleaned layer; explicit `COALESCE` to `'Unknown'` / `0` only applied at the aggregation (marts) layer where needed for reporting

## How to Run

1. Start PostgreSQL in Docker (container must be running on port `5433`)
2. Set the database password as an environment variable:
```bash
   export DB_PASSWORD="your_password_here"
```
3. Run `python3 ingest.py` to load raw CSVs into the `raw` schema
4. Execute `jobs/jobs_cleaned.sql` → `jobs/jobs_metrics.sql`
5. Execute `games/games_cleaned.sql` → `games/games_metrics.sql`
6. Query the resulting views:
```sql
   SELECT * FROM marts.it_market_comprehensive_analytics LIMIT 132;
   SELECT * FROM marts.games_market_analytics LIMIT 66;
```

## Next Steps

- Build Tableau dashboards for both datasets
- Add data quality notes / assumptions documentation
