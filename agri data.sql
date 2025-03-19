SELECT * FROM agri_data.cropproduction;
use agri_data;
select * from cropproduction;

SHOW TABLES;
DESC agri_data;


-- 1.Year-wise Trend of Rice Production Across States (Top 3)

SELECT year, state_name, total_rice_production
FROM (
    SELECT 
        year, 
        state_name, 
        SUM(rice_production) AS total_rice_production,
        RANK() OVER (PARTITION BY year ORDER BY SUM(rice_production) DESC) AS rank_pos
    FROM cropproduction
    GROUP BY year, state_name
) AS RankedRiceProduction
WHERE rank_pos <= 3
ORDER BY year, rank_pos
limit 10;


-- 2.Top 5 Districts by Wheat Yield Increase Over the Last 5 Years

WITH WheatYieldGrowth AS (
    SELECT 
        dist_code,
        dist_name,
        state_name,
        year,
        wheat_yield,
        LAG(wheat_yield, 5) OVER (PARTITION BY dist_code ORDER BY year) AS wheat_yield_5yr_ago
    FROM agri_data.cropproduction
    WHERE wheat_yield IS NOT NULL
)
SELECT 
    dist_code,
    dist_name,
    state_name,
    (wheat_yield - wheat_yield_5yr_ago) AS yield_increase
FROM WheatYieldGrowth
WHERE wheat_yield_5yr_ago IS NOT NULL
ORDER BY yield_increase DESC
LIMIT 5;


-- 3.States with the Highest Growth in Oilseed Production (5-Year Growth Rate)

WITH OilseedGrowth AS (
    SELECT 
        state_name,
        year,
        SUM(oilseeds_production) AS total_production
    FROM cropproduction
    GROUP BY state_name, year
),
GrowthRate AS (
    SELECT 
        state_name,
        MIN(year) AS start_year,
        MAX(year) AS end_year,
        (MAX(total_production) - MIN(total_production)) * 100.0 / NULLIF(MIN(total_production), 0) AS growth_rate
    FROM OilseedGrowth
    WHERE year >= (SELECT MAX(year) - 5 FROM cropproduction) -- last 5 years
    GROUP BY state_name
)
SELECT state_name, growth_rate
FROM GrowthRate
ORDER BY growth_rate DESC
LIMIT 5;

-- 4.District-wise Correlation Between Area and Production for Major Crops (Rice, Wheat, and Maize)

WITH Stats AS (
    SELECT 
        dist_name,
        COUNT(*) AS n,
        SUM(rice_area) AS sum_x_rice, SUM(rice_production) AS sum_y_rice,
        SUM(rice_area * rice_production) AS sum_xy_rice,
        SUM(rice_area * rice_area) AS sum_x2_rice, SUM(rice_production * rice_production) AS sum_y2_rice,
        
        SUM(wheat_area) AS sum_x_wheat, SUM(wheat_production) AS sum_y_wheat,
        SUM(wheat_area * wheat_production) AS sum_xy_wheat,
        SUM(wheat_area * wheat_area) AS sum_x2_wheat, SUM(wheat_production * wheat_production) AS sum_y2_wheat,
        
        SUM(maize_area) AS sum_x_maize, SUM(maize_production) AS sum_y_maize,
        SUM(maize_area * maize_production) AS sum_xy_maize,
        SUM(maize_area * maize_area) AS sum_x2_maize, SUM(maize_production * maize_production) AS sum_y2_maize
    FROM agri_data.cropproduction
    GROUP BY dist_name
)
SELECT 
    dist_name,
    ( (sum_xy_rice - (sum_x_rice * sum_y_rice) / n) / 
      SQRT((sum_x2_rice - (sum_x_rice * sum_x_rice) / n) * (sum_y2_rice - (sum_y_rice * sum_y_rice) / n)) 
    ) AS rice_corr,

    ( (sum_xy_wheat - (sum_x_wheat * sum_y_wheat) / n) / 
      SQRT((sum_x2_wheat - (sum_x_wheat * sum_x_wheat) / n) * (sum_y2_wheat - (sum_y_wheat * sum_y_wheat) / n)) 
    ) AS wheat_corr,

    ( (sum_xy_maize - (sum_x_maize * sum_y_maize) / n) / 
      SQRT((sum_x2_maize - (sum_x_maize * sum_x_maize) / n) * (sum_y2_maize - (sum_y_maize * sum_y_maize) / n)) 
    ) AS maize_corr
FROM Stats
ORDER BY rice_corr DESC, wheat_corr DESC, maize_corr DESC
limit 10;

-- 5.Yearly Production Growth of Cotton in Top 5 Cotton Producing States

WITH TopCottonStates AS (
    SELECT state_name
    FROM agri_data.cropproduction
    WHERE year = (SELECT MAX(year) FROM agri_data.cropproduction)
    GROUP BY state_name
    ORDER BY SUM(cotton_production) DESC
    LIMIT 5
)

SELECT cp.year, cp.state_name, 
       SUM(cp.cotton_production) AS total_cotton_production,
       LAG(SUM(cp.cotton_production)) OVER (PARTITION BY cp.state_name ORDER BY cp.year) AS prev_year_production,
       ROUND((SUM(cp.cotton_production) - LAG(SUM(cp.cotton_production)) OVER (PARTITION BY cp.state_name ORDER BY cp.year)) 
             / NULLIF(LAG(SUM(cp.cotton_production)) OVER (PARTITION BY cp.state_name ORDER BY cp.year), 0) * 100, 2) AS yearly_growth_rate
FROM agri_data.cropproduction cp
JOIN TopCottonStates tcs ON cp.state_name = tcs.state_name
GROUP BY cp.year, cp.state_name
ORDER BY cp.state_name, cp.year
limit 10;


-- 6.Districts with the Highest Groundnut Production in 2020

SELECT dist_code, dist_name, state_name, groundnut_production
FROM agri_data.cropproduction
WHERE year = 2017
ORDER BY groundnut_production DESC
LIMIT 10;


-- 7.Annual Average Maize Yield Across All States
SELECT 
    year, 
    state_name, 
    AVG(maize_yield) AS avg_maize_yield
FROM cropproduction
WHERE maize_yield IS NOT NULL
GROUP BY year, state_name
ORDER BY year, avg_maize_yield DESC
limit 10;

-- 8.Total Area Cultivated for Oilseeds in Each State

SELECT 
    state_name, 
    SUM(oilseeds_area) AS total_oilseeds_area
FROM agri_data.cropproduction
GROUP BY state_name
ORDER BY total_oilseeds_area DESC
limit 10;

-- 9.Districts with the Highest Rice Yield
SELECT 
    dist_code, 
    dist_name, 
    state_name, 
    year, 
    rice_yield
FROM cropproduction
WHERE rice_yield IS NOT NULL
ORDER BY rice_yield DESC
LIMIT 10;


-- 10.Compare the Production of Wheat and Rice for the Top 5 States Over 10 Years

WITH Top5States AS (
    SELECT state_name
    FROM cropproduction
    WHERE year BETWEEN YEAR(CURDATE()) - 10 AND YEAR(CURDATE()) 
    GROUP BY state_name
    ORDER BY SUM(rice_production + wheat_production) DESC
    LIMIT 5
)
SELECT 
    c.year, 
    c.state_name, 
    SUM(c.rice_production) AS total_rice_production, 
    SUM(c.wheat_production) AS total_wheat_production
FROM cropproduction c
JOIN Top5States t ON c.state_name = t.state_name
WHERE c.year BETWEEN YEAR(CURDATE()) - 10 AND YEAR(CURDATE())
GROUP BY c.year, c.state_name
ORDER BY c.year ASC, total_rice_production DESC, total_wheat_production DESC
limit 10;





















