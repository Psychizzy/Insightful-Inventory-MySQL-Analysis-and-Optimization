use techelectro;
-- after data exploration
-- data cleaning and manipulations i.e changing data type from
-- sales date (text), GDP (double), Inflation rate (double), seasonal factor (decimal) TO
-- data type should be as follows, sales date (Date), GDP (decimal 15,2), Inflation rate (decimal 5,2), Seasonal Factor(decimal 5,2)

select * from external_factors;
describe external_factors;



UPDATE external_factors
SET `Sales Date` = STR_TO_DATE(`Sales Date`, '%d/%m/%Y');
SELECT 
    `Sales Date`, 
    GDP,
    `Inflation Rate`, 
    `Seasonal Factor` 
FROM external_factors 
LIMIT 10;

ALTER TABLE external_factors
MODIFY COLUMN `sales date`DATE;

ALTER TABLE external_factors 
MODIFY COLUMN GDP DECIMAL(15,2);

ALTER TABLE external_factors 
MODIFY COLUMN `Inflation rate` DECIMAL(5,2);

ALTER TABLE external_factors 
MODIFY COLUMN `Seasonal factor` DECIMAL(5,2);

SELECT 
    `Sales Date`, 
    GDP,
    `Inflation Rate`, 
    `Seasonal Factor` 
FROM external_factors 
LIMIT 10;
describe external_factors;

-- product data 

DESCRIBE PRODUCT_DATA;
SELECT * FROM product_data;

ALTER TABLE product_data
MODIFY promotions ENUM ('YES', 'NO');

-- sales data after
DESCRIBE sales_data;

UPDATE sales_data
SET `Sales Date` = STR_TO_DATE(`Sales Date`, '%d/%m/%Y');
ALTER TABLE sales_data
MODIFY COLUMN `sales date`DATE;

ALTER TABLE sales_data
MODIFY COLUMN `product cost` double;

-- identify missing value in each dataset
-- for external factors
select 
sum(case when `sales date` is null then 1 else 0 end) as missing_value,
sum(case when GDP is null then 1 else 0 end) as missing_value,
sum(case when `Inflation rate` is null then 1 else 0 end),
sum(case when `Seasonal factor` is null then 1 else 0 end)
from external_factors;

-- Sales data
select
 sum(case when `Product ID` is null then 1 else 0 end),
 sum(case when `sales date` is null then 1 else 0 end),
 sum(case when `Inventory Quantity` is null then 1 else 0 end),
 sum(case when `product cost` is null then 1 else 0 end)
 from sales_data;
 
 -- for product data
 select
 sum(case when `Product ID` is null then 1 else 0 end),
 sum(case when `Product Category` is null then 1 else 0 end),
 sum(case when promotions is null then 1 else 0 end)
 from Product_data;
 
 -- checking for duplicate in all the data set 
 -- for external factors
 describe external_factors;
 select `sales date`, count(*) as duplicate
 from external_factors
 group by `sales date`
 having count(*) > 1;
 
 -- this is just give me the exact figure of duplicate all together
 select count(*) as total_number_of_duplicate from (select `sales date`, count(*) 
 from external_factors
 group by `sales date`
 having count(*) > 1) as dup;
 
 -- for sales dataset
 
 select * from sales_data;
select `sales date`, `Product ID`, count(*) as duplicate
 from Sales_data
 group by `sales date`, `Product ID`
 having count(*) > 1;
 
 -- for Product_data
 
 select  `Product ID`, count(*) as duplicate
 from Product_data
 group by  `Product ID`
 having count(*) > 1;
 
 select count(*) as total_number_of_dup from (select  `Product ID`, count(*) as duplicate
 from Product_data
 group by  `Product ID`
 having count(*) > 1) as dup;

-- No duplicate on sales data
-- Handling duplicate in external factors and product_data
-- external factors 

DELETE e1 from external_factors e1
INNER JOIN(SELECT `sales date`, ROW_NUMBER() OVER (PARTITION BY `sales date` ORDER BY `sales date`) as rn
from external_factors) e2 ON e1.`sales date` = e2.`sales date`
WHERE e2.rn >1;

-- Product_data
DELETE p1  from product_data p1
INNER JOIN (SELECT `product id`, ROW_NUMBER() OVER (PARTITION BY `product id`) as rn
from Product_data )
p2 ON p1.`product id` = p2.`product id`
WHERE p2.rn >1;
select * from external_factors;
-- Data integrations 
-- Thats combining of sales data and product data
CREATE VIEW sales_product_data as
select 
s.`Product ID`,
s. `sales date`,
s. `Inventory Quantity`,
s. `product cost`,
p. `product Category`,
p. promotions
from sales_data s
join product_data p on  s.`product ID` = p.`product ID`;

-- combining sales product data and external
CREATE view Inventory_sales_data as 
select
sp.`Product ID`,
sp. `sales date`,
sp. `Inventory Quantity`,
sp. `product cost`,
sp. `product Category`,
sp. promotions,
e. GDP,
e. `Inflation rate`,
e.`Seasonal factor`
 from sales_product_data sp
 join external_factors e on sp.`sales date` = e.`sales date`;
 
 -- Descriptive analysis
 -- average sales of each product
 
 select `product id`,
 avg(`product cost` * `inventory quantity`) as average_sales
 from inventory_sales_data
 group by `product id`
 order by average_sales desc;
 
 -- Median stock level (inventory quantity)
 
 WITH RankedData AS 
 (SELECT 
`Product ID`,
`Inventory Quantity`,
ROW_NUMBER() OVER (PARTITION BY `Product ID` ORDER BY `Inventory Quantity`) AS row_num,
COUNT(*) OVER (PARTITION BY `Product ID`) AS total_rows
FROM 
Inventory_sales_data)
SELECT 
`Product ID`,
AVG(`Inventory Quantity`) AS median_stock_level
FROM 
RankedData
WHERE row_num IN (FLOOR((total_rows + 1) / 2), CEIL((total_rows + 1) / 2))
GROUP BY `Product ID`;

-- product performance metrics
-- Total Sales per Product
select `product id`,
sum(`inventory quantity` * `product cost`) as total_sales 
from inventory_sales_data
group by `product id`
order by total_sales desc;

--  Total Units Sold per Product
select `product id`,
sum(`inventory quantity`)as total_unit_sold
from inventory_sales_data
group by `product id`
order by total_unit_sold desc;

-- Promotion Impact
select `product id`, 
sum(case when promotions = 'YES' then `inventory quantity` else 0 end) as Prom_quantity_sold,
sum(case when promotions = 'NO' then `inventory quantity` else 0 end) as Non_prom_quantitySold,
sum(case when promotions = 'YES' then `inventory quantity` * `Product cost` else 0 end) as prom_tOTALsales,
sum(case when promotions = 'NO' then `inventory quantity` * `Product cost` else 0 end) as Non_prom_tOTALsales
from inventory_sales_data
group by `product id`;

-- Profitability per Product
SELECT `product id`,
SUM(`inventory quantity` * `product cost`) AS total_revenue,
SUM(`inventory quantity`) * min(`product cost`) AS total_cost,
SUM(`inventory quantity` * `product cost`) - SUM(`inventory quantity`) * MIN(`product cost`) AS Profit
FROM Inventory_sales_data
GROUP BY `product id`;

-- avg sales demand per product and stock frequency for each product
 SELECT 
    avg_sales.`Product ID`,
    avg_sales.avg_sales,
    stock_freq.stock_frequency
FROM 
    (SELECT 
        `Product ID`,
        AVG(`Inventory Quantity`) AS avg_sales
    FROM 
        sales_data
    GROUP BY 
        `Product ID`) avg_sales
JOIN 
    (SELECT 
        `Product ID`,
        COUNT(`sales date`) AS stock_frequency
    FROM 
        sales_data
    GROUP BY 
        `Product ID`) stock_freq
ON 
    avg_sales.`Product ID` = stock_freq.`Product ID`
ORDER BY 
    avg_sales.avg_sales DESC, 
    stock_freq.stock_frequency DESC;
    
-- avg sales per product    

    select `product id`,
avg(`inventory quantity`) as avg_sales
from inventory_sales_data
group by `product id`
order by avg_sales;
 


-- influence of external factors
-- influence of GDP rate on sales

select
CASE 
 when GDP BETWEEN 15047 AND 16986 THEN 'LOW GDP'
when GDP BETWEEN 17004 AND 19000 THEN 'MEDUIM GDP' 
ELSE 'HIGH GDP' END AS GDP_Category,
avg(`inventory quantity`) as avg_sales
from inventory_sales_data
group by GDP_Category
order by avg_sales;

-- influence of inflations rate on sales

select
CASE 
 when `inflation rate` BETWEEN 1 AND 2 THEN 'Low inflation'
when `inflation rate` BETWEEN 2 AND 3 THEN 'Moderate inflation' 
ELSE 'HIGH Inflation' END AS Inflation_Category,
avg(`inventory quantity`) as avg_sales
from inventory_sales_data
group by Inflation_Category
order by avg_sales;

-- overstcking and understocking

with rollingsales as (
select `product id`  , `sales date`,
avg(`inventory quantity` * `product cost` ) over (partition by `product id` order by `sales date` rows between 6 preceding and current row)
as rolling_avg_sales
from inventory_sales_data),

-- calculate the number of days a product was out of  stock
StockoutDays as (
select `product id`,
count(*) as stockout_days
from inventory_sales_data
where `inventory quantity` = 0
group by `product id`)

-- join the above CTEs with the main table to get the results

select f.product id,
avg(f.`invemtory quantity` * f.`product cost`) as avg_inventory_value,
avg(rs.rolling_avg_sales) as avg_rolling_sales,
COALESCE (sd.stockout_days, 0) as stockout_days
from inventory_sales_data f
join rollingSales rs on f.`product id` = sd.`product id` AND f.`sales date` = rs.`sales date`
left join StockoutDays sd on f.`product id` = sd. `product id`

group by f.`product id`, sd.stockout_days;

