-- Omnichannel Retail Sales Analysis
-- Databricks SQL

-- 1) Store sales data quality summary
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT ss_ticket_number) AS total_transactions,
    COUNT(*) - COUNT(ss_item_sk) AS missing_item,
    COUNT(*) - COUNT(ss_quantity) AS missing_quantity,
    COUNT(*) - COUNT(ss_sales_price) AS missing_sales_price,
    COUNT(*) - COUNT(ss_net_profit) AS missing_profit,
    SUM(CASE WHEN ss_net_profit < 0 THEN 1 ELSE 0 END) AS negative_profit_rows
FROM samples.tpcds_sf1.store_sales;

-- 2) Incomplete financial rows
SELECT
    COUNT(*) AS total_rows,
    SUM(
        CASE
            WHEN ss_quantity IS NULL
              OR ss_sales_price IS NULL
              OR ss_net_paid IS NULL
              OR ss_net_profit IS NULL
            THEN 1 ELSE 0
        END
    ) AS incomplete_sales_rows,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN ss_quantity IS NULL
                  OR ss_sales_price IS NULL
                  OR ss_net_paid IS NULL
                  OR ss_net_profit IS NULL
                THEN 1 ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS incomplete_percentage
FROM samples.tpcds_sf1.store_sales;

-- 3) Referential integrity checks
SELECT COUNT(*) AS unmatched_items
FROM samples.tpcds_sf1.store_sales s
LEFT JOIN samples.tpcds_sf1.item i
    ON s.ss_item_sk = i.i_item_sk
WHERE i.i_item_sk IS NULL;

SELECT COUNT(*) AS unmatched_stores
FROM samples.tpcds_sf1.store_sales s
LEFT JOIN samples.tpcds_sf1.store st
    ON s.ss_store_sk = st.s_store_sk
WHERE s.ss_store_sk IS NOT NULL
  AND st.s_store_sk IS NULL;

SELECT COUNT(*) AS unmatched_customers
FROM samples.tpcds_sf1.store_sales s
LEFT JOIN samples.tpcds_sf1.customer c
    ON s.ss_customer_sk = c.c_customer_sk
WHERE s.ss_customer_sk IS NOT NULL
  AND c.c_customer_sk IS NULL;

SELECT COUNT(*) AS unmatched_dates
FROM samples.tpcds_sf1.store_sales s
LEFT JOIN samples.tpcds_sf1.date_dim d
    ON s.ss_sold_date_sk = d.d_date_sk
WHERE s.ss_sold_date_sk IS NOT NULL
  AND d.d_date_sk IS NULL;

-- 4) Category performance
SELECT
    i.i_category,
    COUNT(*) AS sales_rows,
    SUM(s.ss_quantity) AS units_sold,
    ROUND(SUM(s.ss_net_paid), 2) AS total_revenue,
    ROUND(SUM(s.ss_net_profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(s.ss_net_profit) / SUM(s.ss_net_paid),
        2
    ) AS profit_margin_percent,
    ROUND(
        100.0 *
        SUM(
            CASE
                WHEN s.ss_sales_price < s.ss_wholesale_cost THEN 1
                ELSE 0
            END
        ) / COUNT(*),
        2
    ) AS below_cost_percent
FROM samples.tpcds_sf1.store_sales s
JOIN samples.tpcds_sf1.item i
    ON s.ss_item_sk = i.i_item_sk
WHERE s.ss_net_paid IS NOT NULL
  AND s.ss_net_profit IS NOT NULL
  AND s.ss_sales_price IS NOT NULL
  AND s.ss_wholesale_cost IS NOT NULL
  AND i.i_category IS NOT NULL
GROUP BY i.i_category
ORDER BY total_revenue DESC;

-- 5) Monthly revenue/profit trend
SELECT
    d.d_year,
    d.d_moy AS month,
    ROUND(SUM(s.ss_net_paid), 2) AS total_revenue,
    ROUND(SUM(s.ss_net_profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(s.ss_net_profit) / SUM(s.ss_net_paid),
        2
    ) AS profit_margin_percent
FROM samples.tpcds_sf1.store_sales s
JOIN samples.tpcds_sf1.date_dim d
    ON s.ss_sold_date_sk = d.d_date_sk
WHERE s.ss_net_paid IS NOT NULL
  AND s.ss_net_profit IS NOT NULL
GROUP BY d.d_year, d.d_moy
ORDER BY d.d_year, d.d_moy;

-- 6) Product ranking using CTEs + window functions
WITH product_summary AS (
    SELECT
        i.i_item_id,
        i.i_product_name,
        ROUND(SUM(s.ss_net_paid), 2) AS total_revenue,
        ROUND(SUM(s.ss_net_profit), 2) AS total_profit
    FROM samples.tpcds_sf1.store_sales s
    JOIN samples.tpcds_sf1.item i
        ON s.ss_item_sk = i.i_item_sk
    WHERE s.ss_net_paid IS NOT NULL
      AND s.ss_net_profit IS NOT NULL
    GROUP BY i.i_item_id, i.i_product_name
),
ranked_products AS (
    SELECT
        *,
        RANK() OVER (ORDER BY total_profit DESC) AS best_rank,
        RANK() OVER (ORDER BY total_profit ASC) AS worst_rank
    FROM product_summary
)
SELECT *
FROM ranked_products
WHERE best_rank <= 5
   OR worst_rank <= 5
ORDER BY total_profit DESC;

-- 7) Channel comparison
SELECT
    'Store' AS channel,
    COUNT(*) AS sales_rows,
    SUM(ss_quantity) AS units_sold,
    ROUND(SUM(ss_net_paid), 2) AS total_revenue,
    ROUND(SUM(ss_net_profit), 2) AS total_profit,
    ROUND(100.0 * SUM(ss_net_profit) / SUM(ss_net_paid), 2) AS profit_margin_percent
FROM samples.tpcds_sf1.store_sales
WHERE ss_net_paid IS NOT NULL
  AND ss_net_profit IS NOT NULL

UNION ALL

SELECT
    'Web' AS channel,
    COUNT(*) AS sales_rows,
    SUM(ws_quantity) AS units_sold,
    ROUND(SUM(ws_net_paid), 2),
    ROUND(SUM(ws_net_profit), 2),
    ROUND(100.0 * SUM(ws_net_profit) / SUM(ws_net_paid), 2)
FROM samples.tpcds_sf1.web_sales
WHERE ws_net_paid IS NOT NULL
  AND ws_net_profit IS NOT NULL

UNION ALL

SELECT
    'Catalog' AS channel,
    COUNT(*) AS sales_rows,
    SUM(cs_quantity) AS units_sold,
    ROUND(SUM(cs_net_paid), 2),
    ROUND(SUM(cs_net_profit), 2),
    ROUND(100.0 * SUM(cs_net_profit) / SUM(cs_net_paid), 2)
FROM samples.tpcds_sf1.catalog_sales
WHERE cs_net_paid IS NOT NULL
  AND cs_net_profit IS NOT NULL;
