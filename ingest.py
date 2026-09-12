import os
import pandas 
from sqlalchemy import create_engine, text

# Параметри підключення до бази даних PostgreSQL
DB_USER = "postgres"
DB_PASSWORD = "Theokoles_Il"
DB_HOST = "localhost"
DB_PORT = "5433"
DB_NAME = "double_domain_db"

# Створення URL підключення до бази даних
DATABASE_URL = f"postgresql://{DB_USER}:{DB_PASSWORD}@{DB_HOST}:{DB_PORT}/{DB_NAME}"

# Створення підключення до бази даних
engine = create_engine(DATABASE_URL)

# Створюємо окрему схему "raw" для сирих (необроблених) даних,
# щоб не тримати чисті та брудні дані в одній схемі. Це дозволяє краще організувати дані та уникнути плутанини.
with engine.connect() as connection:
    connection.execute(text("CREATE SCHEMA IF NOT EXISTS raw;"))
    connection.commit()
print("Schema 'raw' created successfully (if it did not exist).")

# Зчитуємо сирий CSV з статистикою ігор та перевіряємо перші 5 рядків
# щоб переконатись, що Pandas коректно зчитав дані.
df_games = pandas.read_csv("games_sales_raw.csv")
print(df_games.head(5))

# Завантажуємо дані про статистику ігор у таблицю "games_sales" в схемі raw
df_games.to_sql(
    name="games_sales",
    con=engine,
    schema="raw",
    if_exists="replace",
    index=False
)
print("Статистика ігор успішно завантажено!")

# Той самий процес для другого датасету - вакансії в data-сфері
df_jobs = pandas.read_csv("jobs_in_data.csv")
print(df_jobs.head(5))

df_jobs.to_sql(
    name="jobs_in_data",
    con=engine,
    schema="raw",
    if_exists="replace",
    index=False
)
print("Статистика робіт успішно завантажено!")