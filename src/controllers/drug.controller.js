import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { redis } from "../Utils/redis.connection.js";
import { db } from "../Utils/sql_connection.utils.js";
import { getShopImWorkingIn } from "./shop.controller.js";



const getAllDrugDetails=asyncHandler(
    async(req,res)=>{
        try{
             let { pgNo = 1 } = req.params;
            if (!pgNo && req.body.pgNo) {
                pgNo = req.body.pgNo;
            }
            const page = parseInt(pgNo, 10);
            if (isNaN(page) || page < 1) {
                throw new ApiError(400, "Page number must be a positive integer.");
            }
            const limit = 10;
            const offset = (page - 1) * limit;

            const key=`getAllDrugDetails:${pgNo}:${limit}:${offset}`
            const cache=await redis.get(key)
            if(cache) return res.status(200).json(new ApiResponse(200,JSON.parse(cache),"Fetched from redis!"))

            const query=`
            SELECT 
            d.drug_id,
            d.name,
            d.type,
            d.barcode,
            d.dose,
            d.cost_price,
            d.selling_price,
            m.name AS manufacturer_company,
            m.address AS manufacturer_address
            FROM drug AS d
            LEFT JOIN manufacturer AS m
                ON d.manufacturer_id = m.manufacturer_id
            order by d.type
            limit ${limit} offset ${offset}
            `
            
            const [rows]=await db.execute(query);


            await redis.set(key,JSON.stringify(rows))
            await redis.expire(key,60)

            return res.status(200).json(
                new ApiResponse(200,rows)
            )

        }catch(err){
            throw new ApiError(400,err.message);
        }
    }
)

// Helper to default date range (YYYY-MM-DD)
const defaultDateRange = () => {
  const end = new Date();
  const start = new Date(Date.now() - 30 * 24 * 60 * 60 * 1000);
  return {
    startDate: start.toISOString().slice(0, 10),
    endDate: end.toISOString().slice(0, 10),
  };
};

const topSellingDrugs = asyncHandler(async (req, res) => {
  try {
    const  shop_id  = await getShopImWorkingIn(req, res);
    const { startDate, endDate } = req.params.startDate
      ? { startDate: req.params.startDate, endDate: req.params.endDate || new Date().toISOString().slice(0, 10) }
      : defaultDateRange();
    const limit = parseInt(req.params.limit || "10", 10);
    // console.log(`${shop_id} ${startDate} ${endDate} ${limit}`);


    const key=`topSellingDrugs:${shop_id}:${startDate}:${endDate}:${limit}`
    const cache=await redis.get(key)
    if(cache) return res.status(200).json(new ApiResponse(200,JSON.parse(cache)),"Fetched top selling drugs from redis!")
    
    const query = `
      SELECT d.drug_id, d.name, SUM(si.quantity) AS totalSold
      FROM sale_item si
      JOIN sale s ON s.sale_id = si.sale_id
      JOIN drug d ON d.drug_id = si.drug_id
      WHERE s.shop_id = ?
        AND s.date BETWEEN ? AND ?
      GROUP BY d.drug_id
      ORDER BY totalSold DESC
      LIMIT ${limit};
    `;

    const [rows] = await db.execute(query, [shop_id, startDate, endDate]);

    await redis.set(key,JSON.stringify(rows))
    await redis.expire(key,30)

    return res.status(200).json(new ApiResponse(200, rows, "Top selling drugs fetched"));
  } catch (err) {
    throw new ApiError(400, `Failed to fetch top selling drugs: ${err.message}`);
  }
});


const topRevenueDrugs = asyncHandler(async (req, res) => {
  try {
    const  shop_id  = await getShopImWorkingIn(req, res);
    const { startDate, endDate } = req.params.startDate
      ? { startDate: req.params.startDate, endDate: req.params.endDate || new Date().toISOString().slice(0, 10) }
      : defaultDateRange();
    const limit = parseInt(req.params.limit || "10", 10);


     const key=`topRevenueDrugs:${shop_id}:${startDate}:${endDate}:${limit}`
    const cache=await redis.get(key)
    if(cache) return res.status(200).json(new ApiResponse(200,JSON.parse(cache)),"Fetched top revenue drugs from redis!")

    const query = `
      SELECT d.drug_id, d.name, SUM(si.quantity * d.selling_price) AS revenue
      FROM sale_item si
      JOIN sale s ON s.sale_id = si.sale_id
      JOIN drug d ON d.drug_id = si.drug_id
      WHERE s.shop_id = ?
        AND s.date BETWEEN ? AND ?
      GROUP BY d.drug_id
      ORDER BY revenue DESC
      LIMIT ${limit};
    `;

    const [rows] = await db.execute(query, [shop_id, startDate, endDate]);

    await redis.set(key,JSON.stringify(rows))
    await redis.expire(key,30)


    return res.status(200).json(new ApiResponse(200, rows, "Top revenue drugs fetched"));
  } catch (err) {
    throw new ApiError(400, `Failed to fetch top revenue drugs: ${err.message}`);
  }
});



export {getAllDrugDetails,topSellingDrugs,topRevenueDrugs}