# Omnichannel Retail Sales ETL - PySpark
from pyspark.sql.functions import lit, col

# Extract
store_df = spark.table("samples.tpcds_sf1.store_sales")
web_df = spark.table("samples.tpcds_sf1.web_sales")
catalog_df = spark.table("samples.tpcds_sf1.catalog_sales")

# Transform: standardize schemas
store_clean = store_df.select(
    lit("Store").alias("channel"),
    col("ss_sold_date_sk").alias("date_key"),
    col("ss_item_sk").alias("item_key"),
    col("ss_customer_sk").alias("customer_key"),
    col("ss_quantity").alias("quantity"),
    col("ss_net_paid").alias("revenue"),
    col("ss_net_profit").alias("profit")
)

web_clean = web_df.select(
    lit("Web").alias("channel"),
    col("ws_sold_date_sk").alias("date_key"),
    col("ws_item_sk").alias("item_key"),
    col("ws_bill_customer_sk").alias("customer_key"),
    col("ws_quantity").alias("quantity"),
    col("ws_net_paid").alias("revenue"),
    col("ws_net_profit").alias("profit")
)

catalog_clean = catalog_df.select(
    lit("Catalog").alias("channel"),
    col("cs_sold_date_sk").alias("date_key"),
    col("cs_item_sk").alias("item_key"),
    col("cs_bill_customer_sk").alias("customer_key"),
    col("cs_quantity").alias("quantity"),
    col("cs_net_paid").alias("revenue"),
    col("cs_net_profit").alias("profit")
)

# Combine channels
all_sales = (
    store_clean
    .unionByName(web_clean)
    .unionByName(catalog_clean)
)

# Keep rows usable for core financial analysis
analysis_ready = all_sales.filter(
    col("revenue").isNotNull() &
    col("profit").isNotNull()
)

# Enrich with product and date dimensions
item_dim = spark.table("samples.tpcds_sf1.item").select(
    col("i_item_sk").alias("item_key"),
    col("i_product_name").alias("product_name"),
    col("i_category").alias("category"),
    col("i_brand").alias("brand")
)

date_dim = spark.table("samples.tpcds_sf1.date_dim").select(
    col("d_date_sk").alias("date_key"),
    col("d_date").alias("sale_date"),
    col("d_year").alias("year"),
    col("d_moy").alias("month")
)

sales_enriched = (
    analysis_ready
    .join(item_dim, on="item_key", how="left")
    .join(date_dim, on="date_key", how="left")
)

# Validation
print("Before joins:", analysis_ready.count())
print("After joins:", sales_enriched.count())
sales_enriched.groupBy("channel").count().show()

# Load
sales_enriched.write \
    .format("delta") \
    .mode("overwrite") \
    .saveAsTable("omnichannel_sales_analysis")
