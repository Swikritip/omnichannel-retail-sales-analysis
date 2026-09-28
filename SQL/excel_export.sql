-- Excel-ready aggregate (full years only)
SELECT
    year,
    channel,
    category,
    SUM(quantity) AS units_sold,
    ROUND(SUM(revenue), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND(
        100.0 * SUM(profit) / SUM(revenue),
        2
    ) AS profit_margin_percent
FROM workspace.default.omnichannel_sales_analysis
WHERE year IS NOT NULL
  AND category IS NOT NULL
  AND year <= 2002
GROUP BY year, channel, category
ORDER BY year, channel, category;
