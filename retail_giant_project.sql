/* Q1:	Provide a list of products with a base price greater than 500
		and that are featured in promo type of 'BOGOF' (Buy One Get One Free). */
            
            SELECT p.product_name, e.base_price,e.promo_type
            from dim_products p join fact_events e 
            on p.product_code=e.product_code and e.promo_type = 'BOGOF'
            where e.base_price >500
            group by 1,2,3;
            
/*Q2.	Generate a report that provides an overview of the number of stores in each city. */

select city,count(*) as store_count
from dim_stores
group by city 
order by store_count desc;

/*Q3.Generate a report that displays each campaign along with the total revenue 
	generated before and after the campaign? The report includes three key fields:
    campaign_name, totaI_revenue(before_promotion), totaI_revenue(after_promotion).*/
    
    select c.campaign_name,
     concat(round(sum(e.base_price*e.quantity_sold_before_promo)/1000000,2) ,' ','mln')
    as total_revenue_before_promotion,
    concat(round(sum(CASE when e.promo_type  = '50% OFF' 
					 THEN 0.5*e.base_price*e.quantity_sold_after_promo
                     WHEN e.promo_type = '25% OFF' 
                     THEN 0.75*e.base_price*e.quantity_sold_after_promo
                     WHEN e.promo_type = '33% OFF'
                     THEN 0.67*e.base_price*e.quantity_sold_after_promo
                     WHEN e.promo_type = '500 Cashback'
                     THEN (e.base_price*e.quantity_sold_after_promo-500)
                     WHEN e.promo_type = 'BOGOF'
                     THEN e.base_price*e.quantity_sold_after_promo
                     end)/1000000,2) ,' ','mln') 
    as total_revenue_after_promotion
    from dim_campaigns c join fact_events e 
    on c.campaign_id = e.campaign_id
    group by 1;
    
/* Q4.	Produce a report that calculates the Incremental Sold Quantity (ISU%) 
for each category during the Diwali campaign. Additionally, provide rankings 
for the categories based on their ISU%. 
The report will include three key fields: category, isu%, and rank order.*/

with ISU as(select p.category,
round(sum(case 
                     WHEN e.promo_type = 'BOGOF'
                     THEN 2*e.quantity_sold_after_promo
                     else e.quantity_sold_after_promo
                     end
- e.quantity_sold_before_promo)*100.0/
sum(e.quantity_sold_before_promo),2)
as ISU_PCT 
from dim_products p join fact_events e 
using(product_code)
join dim_campaigns c 
using(campaign_Id)
where c.campaign_name = 'Diwali'
group by 1)
select category,concat(ISU_PCT,'%')as isu_percentage,
dense_rank() over(order by isu_pct desc) AS rnk
from ISU;

/*Q5.Create a report featuring the Top 5 products, ranked by Incremental Revenue Percentage (IR%),
 across all campaigns. The report will provide essential information including product name,
 category, and ir%. This analysis helps identify the most successful products in terms
 of incremental revenue across our campaigns, assisting in product optimization.
incremental revenue = (revenue after promo revenue before promo)/revenue before promo*/

with incremental_revenue as
(select p.product_name,p.category,
round(((sum(case when e.promo_type = 'BOGOF' 
               THEN e.base_price*0.5*quantity_sold_after_promo*2
               when e.promo_type = '500 Cashback'
               THEN (e.base_price*e.quantity_sold_after_promo-500)
               when e.promo_type = '50% OFF'
               THEN 0.5*e.base_price*e.quantity_sold_after_promo
               when e.promo_type = '33% OFF'
               THEN 0.67*e.base_price*e.quantity_sold_after_promo
               when e.promo_type = '25% OFF'
               THEN 0.75*e.base_price*e.quantity_sold_after_promo
               else 0 end)-sum(e.base_price*e.quantity_sold_before_promo)
               )/sum(e.base_price*e.quantity_sold_before_promo))*100.0,2)
               as ir_pct
from fact_events e join dim_products p 
using(product_code)
group by 1,2)
select product_name,category,concat(ir_pct,'%') as ir_percentage
from incremental_revenue
group by 1,2
order by ir_pct desc
;
               
/* Q6: TOP 10 Stores in terms of incremental revenue% */

select e.store_id,
round(((sum(case when e.promo_type = 'BOGOF' 
               THEN e.base_price*0.5*quantity_sold_after_promo*2
               when e.promo_type = '500 Cashback'
               THEN (e.base_price*e.quantity_sold_after_promo-500)
               when e.promo_type = '50% OFF'
               THEN 0.5*e.base_price*e.quantity_sold_after_promo
               when e.promo_type = '33% OFF'
               THEN 0.67*e.base_price*e.quantity_sold_after_promo
               when e.promo_type = '25% OFF'
               THEN 0.75*e.base_price*e.quantity_sold_after_promo
               else 0 end)-sum(e.base_price*e.quantity_sold_before_promo)
               )/sum(e.base_price*e.quantity_sold_before_promo))*100.0,2)
as ir_pct
from fact_events e 
group by 1
order by ir_pct desc
limit 10;

/* Q7: Bottom 10 stores in terms Incremental sold units during campaigns*/

with ISU as(select e.store_id,
round(sum(case 
                     WHEN e.promo_type = 'BOGOF'
                     THEN 2*e.quantity_sold_after_promo
                     else e.quantity_sold_after_promo
                     end
- e.quantity_sold_before_promo)*100.0/
sum(e.quantity_sold_before_promo),2)
as ISU_PCT 
from fact_events e 
group by 1)
select store_Id,concat(ISU_PCT,'%')as isu_percentage
from ISU order by isu_pct asc
limit 10;

/* Q8: TOP 3 stores in each city in terms of revenue.*/

select store_id,city,ir_pct,rnk from
(select store_id,city,ir_pct,
dense_rank() over(partition by city order by ir_pct desc) as rnk
from
(select e.store_id,s.city,
round(((sum(case when e.promo_type = 'BOGOF' 
               THEN e.base_price*0.5*quantity_sold_after_promo*2
               when e.promo_type = '500 Cashback'
               THEN (e.base_price*e.quantity_sold_after_promo-500)
               when e.promo_type = '50% OFF'
               THEN 0.5*e.base_price*e.quantity_sold_after_promo
               when e.promo_type = '33% OFF'
               THEN 0.67*e.base_price*e.quantity_sold_after_promo
               when e.promo_type = '25% OFF'
               THEN 0.75*e.base_price*e.quantity_sold_after_promo
               else 0 end)-sum(e.base_price*e.quantity_sold_before_promo)
               )/sum(e.base_price*e.quantity_sold_before_promo))*100.0,2)
as ir_pct
from fact_events e join dim_stores s 
using(store_id)
group by 1,2) as a)as b
where rnk<=3
group by 1,2
order by 2,3 desc;
               
/* Q9: TOP 2 promotional offers in terms of incremental_revenue%. */

select e.promo_type,
round(((sum(case when e.promo_type = 'BOGOF' 
               THEN e.base_price*0.5*quantity_sold_after_promo*2
               when e.promo_type = '500 Cashback'
               THEN (e.base_price*e.quantity_sold_after_promo-500)
               when e.promo_type = '50% OFF'
               THEN 0.5*e.base_price*e.quantity_sold_after_promo
               when e.promo_type = '33% OFF'
               THEN 0.67*e.base_price*e.quantity_sold_after_promo
               when e.promo_type = '25% OFF'
               THEN 0.75*e.base_price*e.quantity_sold_after_promo
               else 0 end)-sum(e.base_price*e.quantity_sold_before_promo)
               )/sum(e.base_price*e.quantity_sold_before_promo))*100.0,2)
as ir_pct
from fact_events e 
group by 1
order by ir_pct desc
limit 2;
               
/* Q10: BOTTOM 2 promotional offers in terms of incremental_sold_units. */

with ISU as(select e.promo_type,
round(sum(case 
                     WHEN e.promo_type = 'BOGOF'
                     THEN 2*e.quantity_sold_after_promo
                     else e.quantity_sold_after_promo
                     end
- e.quantity_sold_before_promo)*100.0/
sum(e.quantity_sold_before_promo),2)
as ISU_PCT 
from fact_events e 
group by 1)
select promo_type,concat(ISU_PCT,'%')as isu_percentage
from ISU
order by isu_pct asc
limit 2;

/* Q11: CORRELATION between product_category and promo_type.*/

with promo_per_category as 
(select p.category,e.promo_type,
round(((sum(case when e.promo_type = 'BOGOF' 
               THEN e.base_price*0.5*quantity_sold_after_promo*2
               when e.promo_type = '500 Cashback'
               THEN (e.base_price*e.quantity_sold_after_promo-500)
               when e.promo_type = '50% OFF'
               THEN 0.5*e.base_price*e.quantity_sold_after_promo
               when e.promo_type = '33% OFF'
               THEN 0.67*e.base_price*e.quantity_sold_after_promo
               when e.promo_type = '25% OFF'
               THEN 0.75*e.base_price*e.quantity_sold_after_promo
               else 0 end)-sum(e.base_price*e.quantity_sold_before_promo)
               )/sum(e.base_price*e.quantity_sold_before_promo))*100.0,2)
as ir_pct
from fact_events e join dim_products p 
using(product_code)
group by 1,2
order by ir_pct desc)
select category,promo_type,ir_pct,
dense_rank() over(partition by category order by ir_pct desc) as rnk
from promo_per_category
group by 1,2;
              
 