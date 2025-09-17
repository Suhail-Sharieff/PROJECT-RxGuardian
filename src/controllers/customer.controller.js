import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { db } from "../Utils/sql_connection.utils.js";
import { buildPaginatedFilters } from "../Utils/paginated_query_builder.js";
import { getShopImWorkingIn } from "./shop.controller.js";
import { redis } from "../Utils/redis.connection.js";
const createCustomer=asyncHandler(
    async(req,res)=>{
        try {
            const {name,phone}=req.body
            const [rows]=await db.execute(
                `insert into customer (name,phone) values (?,?)`,[name,phone]
            )
            return res.status(200).json(
                new ApiResponse(200,rows)
            )
        } catch (error) {
            
        }
    }
)

const getCutomerByPhone=asyncHandler(
    async(req,res)=>{
        try {
            const { limit, offset, whereClause, params } = buildPaginatedFilters({
                  req,
                  baseParams: [],
                  allowedFilters: [
                    { key: "searchByPhone", column: "phone", type: "string" },
                  ]
          });


          const key=`getCutomerByPhone:${whereClause}:${params}:${limit}:${offset}`
          const cache=await redis.get(key)
          if(cache) return res.status(200).json(new ApiResponse(200,JSON.parse(cache),"Get customerByPhone from redis "))
      
            const query=`select * from customer where 1=1 ${whereClause} limit ${limit} offset ${offset}`
            
            const [rows]=await db.execute(query,params);


          await redis.set(key,JSON.stringify(rows))
          await redis.expire(key,30)


            return res.status(200).json(new ApiResponse(200,rows));
        } catch (error) {
            throw new ApiError(400,error.message)
        }
    }
);


const avgNumberOfTimesCustomerVisisted=asyncHandler
(
    async(req,res)=>{
        try{
            const shop_id=await getShopImWorkingIn(req,res);

            const key=`avgNumberOfTimesCustomerVisisted:${shop_id}`
            const cache=await redis.get(key)
            if(cache) return res.status(200).json(new ApiResponse(200,JSON.parse(cache),"Fetch avg times customer visited from redis!"))


            const query=`
           select avg(nTimesVisited) as avgNumberOfCustomerReVisisted,count(*) as total from 
            (select c.customer_id,c.name,
            count(s.sale_id) as nTimesVisited
            from sale as s
            left join customer as c 
            on s.customer_id=c.customer_id
            where s.shop_id=?
            group by c.customer_id) as x`;

        const [rows]=await db.execute(query,[shop_id])

          await redis.set(key,JSON.stringify(rows[0]))
          await redis.expire(key,60)

            return res.status(200).json(new ApiResponse(200,rows[0],"Fetched avg freq vis!"))

        }catch(err){
            throw new ApiError(400,`Failed to fetch average number of times customer visited ${err.message}!`)
        }
    }
);



// Helper to default date range (YYYY-MM-DD)
const defaultDateRange = () => {
  const end = new Date();
  const start = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  return {
    startDate: start.toISOString().slice(0, 10),
    endDate: end.toISOString().slice(0, 10),
  };
};








// (average revenue per sale)
const avgBasketSize = asyncHandler(async (req, res) => {
  try {
    const  shop_id  = await getShopImWorkingIn(req, res);
    const { startDate, endDate } = req.params.startDate
      ? { startDate: req.params.startDate, endDate: req.params.endDate || new Date().toISOString().slice(0, 10) }
      : defaultDateRange();

    const key=`avgBasketSize:${shop_id}:${startDate}:${endDate}`
    const cache=await redis.get(key)
    if(cache) return res.status(200).json(new ApiResponse(200,JSON.parse(cache),"Fetch avg basket sz from redis!"))

    const query = `
      SELECT AVG(sale_total) AS avgOrderValue
      FROM (
        SELECT s.sale_id, COALESCE(SUM(si.quantity * d.selling_price),0) AS sale_total
        FROM sale s
        LEFT JOIN sale_item si ON si.sale_id = s.sale_id
        LEFT JOIN drug d ON d.drug_id = si.drug_id
        WHERE s.shop_id = ? AND date(s.date) BETWEEN ? AND ?
        GROUP BY s.sale_id
      ) t;
    `;

    const [rows] = await db.execute(query, [shop_id, startDate, endDate]);

    await redis.set(key,JSON.stringify(rows[0]))
    await redis.expire(key,30)

    return res.status(200).json(new ApiResponse(200, rows[0], "Average basket size fetched"));
  } catch (err) {
    throw new ApiError(400, `Failed to fetch avg basket size: ${err.message}`);
  }
});

// avgItemsPerSale
const avgItemsPerSale = asyncHandler(async (req, res) => {
  try {
    const  shop_id  = await getShopImWorkingIn(req, res);
    const { startDate, endDate } = req.params.startDate
      ? { startDate: req.params.startDate, endDate: req.params.endDate || new Date().toISOString().slice(0, 10) }
      : defaultDateRange();

    const query = `
      SELECT AVG(item_count) AS avgItemsPerSale
      FROM (
        SELECT s.sale_id, COALESCE(SUM(si.quantity),0) AS item_count
        FROM sale s
        LEFT JOIN sale_item si ON si.sale_id = s.sale_id
        WHERE s.shop_id = ? AND date(s.date) BETWEEN ? AND ?
        GROUP BY s.sale_id
      ) t;
    `;

    const [rows] = await db.execute(query, [shop_id, startDate, endDate]);
    return res.status(200).json(new ApiResponse(200, rows[0], "Average items per sale fetched"));
  } catch (err) {
    throw new ApiError(400, `Failed to fetch avg items per sale: ${err.message}`);
  }
});

// newVsReturning
const newVsReturning = asyncHandler(async (req, res) => {
  try {
    const  shop_id  = await getShopImWorkingIn(req, res);
    const { startDate, endDate } = req.params.startDate
      ? { startDate: req.params.startDate, endDate: req.params.endDate || new Date().toISOString().slice(0, 10) }
      : defaultDateRange();



    const query = `
      SELECT
        SUM(is_new) AS newCustomers,
        SUM(1 - is_new) AS returningCustomers
      FROM (
        SELECT c.customer_id,
               MIN(s.date) AS firstSaleDate,
               CASE WHEN MIN(date(s.date)) BETWEEN ? AND ? THEN 1 ELSE 0 END AS is_new
        FROM sale s
        JOIN customer c ON c.customer_id = s.customer_id
        WHERE s.shop_id = ?
        GROUP BY c.customer_id
      ) t;
    `;

    const [rows] = await db.execute(query, [startDate, endDate, shop_id]);




    return res.status(200).json(new ApiResponse(200, rows[0], "New vs returning customers fetched"));
  } catch (err) {
    throw new ApiError(400, `Failed to fetch new vs returning customers: ${err.message}`);
  }
});

// customerFrequencyDistribution
const customerFrequencyDistribution = asyncHandler(async (req, res) => {
  try {
    const shop_id  = await getShopImWorkingIn(req, res);

     const key=`customerFrequencyDistribution:${shop_id}`
    const cache=await redis.get(key)
    if(cache) return res.status(200).json(new ApiResponse(200,JSON.parse(cache),"customerFrequencyDistribution from redis!"))

    const query = `
      SELECT visit_count, COUNT(*) AS nCustomers
      FROM (
        SELECT s.customer_id, COUNT(s.sale_id) AS visit_count
        FROM sale s
        WHERE s.shop_id = ?
        GROUP BY s.customer_id
      ) t
      GROUP BY visit_count
      ORDER BY visit_count;
    `;

    const [rows] = await db.execute(query, [shop_id]);

    await redis.set(key,JSON.stringify(rows))
    await redis.expire(key)

    return res.status(200).json(new ApiResponse(200, rows, "Customer frequency distribution fetched"));
  } catch (err) {
    throw new ApiError(400, `Failed to fetch customer frequency distribution: ${err.message}`);
  }
});








// avgDaysBetweenCustomerPurchase (uses window functions - MySQL 8+)
const avgDaysBetweenCustomerPurchase = asyncHandler(async (req, res) => {
  try {
    const  shop_id  = await getShopImWorkingIn(req, res);


    const key=`avgDaysBetweenCustomerPurchase:${shop_id}`
    const cache=await redis.get(key)
    if(cache) return res.status(200).json(new ApiResponse(200,JSON.parse(cache),"avgDaysBetweenCustomerPurchase from redis!"))


    const query = `
      select avg(avgDaysBetweenCustomerPurchase) as avg from (SELECT customer_id, AVG(days_between) AS avgDaysBetweenCustomerPurchase
      FROM (
        SELECT s.customer_id,
               DATEDIFF(date(s.date), LAG(date(s.date)) OVER (PARTITION BY s.customer_id ORDER BY s.date)) AS days_between
        FROM sale s
        WHERE s.shop_id = ?
      ) t
      WHERE days_between IS NOT NULL
      GROUP BY customer_id
      ORDER BY avgDaysBetweenCustomerPurchase) x
    `;

    const [rows] = await db.execute(query, [shop_id]);

    await redis.set(key,JSON.stringify(rows))
    await redis.expire(key,30)


    return res.status(200).json(new ApiResponse(200, rows, "Average days between purchases fetched"));
  } catch (err) {
    throw new ApiError(400, `Failed to fetch avg days between purchases: ${err.message}`);
  }
});





export {
  avgBasketSize,
  avgItemsPerSale,
  newVsReturning,
  customerFrequencyDistribution,
  avgDaysBetweenCustomerPurchase,
  getCutomerByPhone,createCustomer,avgNumberOfTimesCustomerVisisted
};

