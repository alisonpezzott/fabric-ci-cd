# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }

# CELL ********************

# =================== Description ===============================
# This notebook spark load all csv files in Files/Raw/ directory
# Build schemas for each file and saves in Tables.
# ===============================================================

# Author: Alison Pezzott
# Last update: 2025-02-22 10:07:00
# Subscribe: https://youtube.com/@alisonpezzott

# ===================== Start of Script =========================

# Parameters
workspace_name = "Fabric_CI_CD_01_PROD"
lakehouse_name = "lakehouse_001"

root_path = f"abfss://{workspace_name}@onelake.dfs.fabric.microsoft.com/{lakehouse_name}.Lakehouse"
files_path = f"{root_path}/Files/Raw"

# Imports
# import zipfile
# import io
# import pandas as pd
# import notebookutils
from pyspark.sql.types import *

# =============== Load Csv Files to Tables ==================

# Function to save each table
def load_csv_to_table(table_name, schema, type):
    df = spark.read.csv(
        f"{files_path}/{table_name}.csv",
        sep=",",
        header=True,
        schema=schema
    )

    df.write.format("delta")\
        .mode("overwrite")\
        .option("overwriteSchema", "true")\
        .save(f"{root_path}/Tables/{type}_{table_name}")

# =================== Schemas definition ==========================

fact_sales_schema = StructType([
    StructField("OrderKey", IntegerType(), True), 
    StructField("LineNumber", IntegerType(), True), 
    StructField("OrderDate", DateType(), True), 
    StructField("DeliveryDate", DateType(), True), 
    StructField("CustomerKey", IntegerType(), True), 
    StructField("StoreKey", IntegerType(), True), 
    StructField("ProductKey", IntegerType(), True), 
    StructField("Quantity", IntegerType(), True), 
    StructField("UnitPrice", DoubleType(), True), 
    StructField("NetPrice", DoubleType(), True), 
    StructField("UnitCost", DoubleType(), True), 
    StructField("CurrencyCode", StringType(), True),
    StructField("ExchangeRate", DoubleType(), True)
])

dim_customer_schema = StructType([
    StructField("CustomerKey", IntegerType(), True),
    StructField("GeoAreaKey", IntegerType(), True),
    StructField("StartDT", DateType(), True),
    StructField("EndDT", DateType(), True),
    StructField("Continent", StringType(), True),
    StructField("Gender", StringType(), True),
    StructField("Title", StringType(), True),
    StructField("GivenName", StringType(), True),
    StructField("MiddleInitial", StringType(), True),
    StructField("Surname", StringType(), True),
    StructField("StreetAddress", StringType(), True),
    StructField("City", StringType(), True),
    StructField("State", StringType(), True),
    StructField("StateFull", StringType(), True),
    StructField("ZipCode", StringType(), True),
    StructField("Country", StringType(), True),
    StructField("CountryFull", StringType(), True),
    StructField("Birthday", DateType(), True),
    StructField("Age", IntegerType(), True),
    StructField("Occupation", StringType(), True),
    StructField("Company", StringType(), True),
    StructField("Vehicle", StringType(), True),
    StructField("Latitude", DoubleType(), True),
    StructField("Longitude", DoubleType(), True)
])

dim_product_schema = StructType([
    StructField("ProductKey", IntegerType(), True),
    StructField("ProductCode", StringType(), True),
    StructField("ProductName", StringType(), True),
    StructField("Manufacturer", StringType(), True),
    StructField("Brand", StringType(), True),
    StructField("Color", StringType(), True),
    StructField("WeightUnit", StringType(), True),
    StructField("Weight", DoubleType(), True),
    StructField("Cost", DoubleType(), True),
    StructField("Price", DoubleType(), True),
    StructField("CategoryKey", IntegerType(), True),
    StructField("CategoryName", StringType(), True),
    StructField("SubCategoryKey", IntegerType(), True),
    StructField("SubCategoryName", StringType(), True)
])

dim_store_schema = StructType([
    StructField("StoreKey", IntegerType(), True),
    StructField("StoreCode", StringType(), True),
    StructField("GeoAreaKey", IntegerType(), True),
    StructField("CountryCode", StringType(), True),
    StructField("CountryName", StringType(), True),
    StructField("State", StringType(), True),
    StructField("OpenDate", DateType(), True),
    StructField("CloseDate", DateType(), True),
    StructField("Description", StringType(), True),
    StructField("SquareMeters", DoubleType(), True),
    StructField("Status", StringType(), True)
])

dim_date_schema = StructType([
    StructField("Date", DateType(), True),
    StructField("DateKey", IntegerType(), True),
    StructField("Year", IntegerType(), True),
    StructField("YearQuarter", StringType(), True),
    StructField("YearQuarterNumber", IntegerType(), True),
    StructField("Quarter", StringType(), True),
    StructField("YearMonth", StringType(), True),
    StructField("YearMonthShort", StringType(), True),
    StructField("YearMonthNumber", IntegerType(), True),
    StructField("Month", StringType(), True),
    StructField("MonthShort", StringType(), True),
    StructField("MonthNumber", IntegerType(), True),
    StructField("DayofWeek", StringType(), True),
    StructField("DayofWeekShort", StringType(), True),
    StructField("DayofWeekNumber", IntegerType(), True),
    StructField("WorkingDay", StringType(), True),
    StructField("WorkingDayNumber", IntegerType(), True)
])

fact_currencyexchange_schema = StructType([
    StructField("Date", DateType(), True),
    StructField("FromCurrency", StringType(), True),
    StructField("ToCurrency", StringType(), True),
    StructField("Exchange", DoubleType(), True)
])

# ================ Execute the Load =====================

load_csv_to_table("sales", fact_sales_schema, "fact")
load_csv_to_table("customer", dim_customer_schema, "dim")
load_csv_to_table("product", dim_product_schema, "dim")
load_csv_to_table("store", dim_store_schema, "dim")
load_csv_to_table("date", dim_date_schema, "dim")

# ================ End of script =========================



# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
