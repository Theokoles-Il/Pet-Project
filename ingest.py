import os
import pandas
from sqlalchemy import create_engine, text

# PostgreSQL connection parameters (loaded from environment variables)
DB_USER = os.getenv("DB_USER", "postgres")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_HOST = os.getenv("DB_HOST", "localhost")
DB_PORT = os.getenv("DB_PORT", "5433")
DB_NAME = os.getenv("DB_NAME", "double_domain_db")

if not DB_PASSWORD:
    raise ValueError("DB_PASSWORD environment variable is not set. Run: export DB_PASSWORD='your_password'")

# Build the database connection URL
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# Create the database connection engine
engine = create_engine(DATABASE_URL)

# Create a separate "raw" schema for unprocessed data,
# so raw and cleaned data don't mix in the same schema.
# This keeps the database organized and avoids confusion.
with engine.connect() as connection:
    connection.execute(text("CREATE SCHEMA IF NOT EXISTS raw;"))
    connection.commit()
print("Schema 'raw' created successfully (if it did not already exist).")

# Read the raw games sales CSV and preview the first 5 rows
# to confirm Pandas parsed the data correctly.
if os.path.exists("games_sales_raw.csv"):
    df_games = pandas.read_csv("games_sales_raw.csv")
    print(df_games.head(5))

    # Load the games data into the "games_sales" table in the raw schema
    df_games.to_sql(
        name="games_sales",
        con=engine,
        schema="raw",
        if_exists="replace",
        index=False
    )
    print("Games sales data loaded successfully!")
else:
    print("[ERROR] games_sales_raw.csv not found!")

# Same process for the second dataset - data industry job listings
if os.path.exists("jobs_in_data.csv"):
    df_jobs = pandas.read_csv("jobs_in_data.csv")
    print(df_jobs.head(5))

    df_jobs.to_sql(
        name="jobs_in_data",
        con=engine,
        schema="raw",
        if_exists="replace",
        index=False
    )
    print("Jobs data loaded successfully!")
else:
    print("[ERROR] jobs_in_data.csv not found!")