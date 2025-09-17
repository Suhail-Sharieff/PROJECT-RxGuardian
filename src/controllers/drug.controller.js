import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { buildPaginatedFilters } from "../Utils/paginated_query_builder.js";
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

//--imp: used transaction here coz whenver we buy some stocks of drug from manufacturer ie addDrugToStaock, then step1:increase the quantity of that drug in our shop, step2:deduct by thatmuch amount from our shopBalance only after checking if that much money is available with us, if any one of these steps fails, we need to cancel whole step, so we use transaction
const addDrugToStock = asyncHandler(async (req, res) => {
  const connection = await db.getConnection(); // start with a connection
  try {
    await connection.beginTransaction(); // 🚀 start transaction

    const { drug_id, quantity } = req.body;
    const numQuantity = parseInt(quantity, 10);

    if (!drug_id || !Number.isFinite(numQuantity) || numQuantity <= 0) {
      throw new ApiError(400, `Invalid input: drug_id=${drug_id}, quantity=${quantity}`);
    }

    const shop_id = await getShopImWorkingIn(req, res);

    // 1. Fetch drug prices
    const [[drug]] = await connection.execute(
      `SELECT cost_price, selling_price FROM drug WHERE drug_id = ?`,
      [drug_id]
    );
    if (!drug) throw new ApiError(404, `Drug with id=${drug_id} not found`);

    const { cost_price } = drug;
    const totalCost = cost_price * numQuantity;

    // 2. Fetch shop balance
    const [[shopBalance]] = await connection.execute(
      `SELECT balance FROM balance WHERE shop_id = ? FOR UPDATE`, // 🔒 row lock
      [shop_id]
    );
    if (!shopBalance) throw new ApiError(404, `Balance for shop_id=${shop_id} not found`);

    if (shopBalance.balance < totalCost) {
      throw new ApiError(
        400,
        `Insufficient balance: needed ${totalCost}, available ${shopBalance.balance}`
      );
    }

    // 3. Deduct balance
    await connection.execute(
      `UPDATE balance SET balance = balance - ? WHERE shop_id = ?`,
      [totalCost, shop_id]
    );

    // 4. Update or insert stock
    const [result] = await connection.execute(
      `UPDATE quantity SET quantity = quantity + ? WHERE shop_id = ? AND drug_id = ?`,
      [numQuantity, shop_id, drug_id]
    );

    if (result.affectedRows === 0) {
      await connection.execute(
        `INSERT INTO quantity (drug_id, shop_id, quantity) VALUES (?, ?, ?)`,
        [drug_id, shop_id, numQuantity]
      );
    }

    await connection.commit(); // ✅ commit transaction

    return res.status(200).json(
      new ApiResponse(
        200,
        { updated: result.affectedRows },
        `Successfully added ${numQuantity} units of drug_id=${drug_id}`
      )
    );
  } catch (err) {
    await connection.rollback(); // ❌ rollback on error
    throw new ApiError(400, err.message);
  } finally {
    connection.release(); // always release back to pool
  }
});


const getDrugAndManufacturer=asyncHandler(
  async(req,res)=>{
     try{
      const shop_id=await getShopImWorkingIn(req,res);
      const { limit, offset, whereClause, params } = buildPaginatedFilters({
                   req,
                   baseParams: [shop_id],
                   allowedFilters: [
                     { key: "searchManufacturer", column: "m.name", type: "string" },
                     { key: "searchDrug", column: "d.name", type: "string" },
                     { key: "searchDrugType", column: "d.type", type: "string" },
                     { key: "searchBarcode", column: "d.barcode", type: "string" },
                   ]
           }); 
     const query=
     `
     select d.drug_id,d.type,d.barcode,d.code,
    d.cost_price,d.selling_price,
    (d.selling_price-d.cost_price) as delta,
    d.name as drug_name,ifnull(q.quantity,0) as curr_stock,m.name as manufacturer_name
    from drug as d join manufacturer as m on m.manufacturer_id=d.manufacturer_id
    left join quantity as q on q.drug_id=d.drug_id and q.shop_id=?
    where 1=1 ${whereClause}
    order by  type,delta desc
    limit ${limit} offset ${offset}
     `
    
     const key=`getDrugAndManufacturer:${whereClause}:${params}:${limit}:${offset}`
     const cache=await redis.get(key)
     if(cache) return res.status(200).json(new ApiResponse(200,JSON.parse(cache),"Fetched drug and manufacturers from redis!"))

      const [rows]=await db.execute(query,params)




      await redis.set(key,JSON.stringify(rows))
      await redis.expire(key,60)

      return res.status(200).json(new ApiResponse(200,rows,`Fetched drug and thier manufacturers!`))
      
     }catch(err){
        throw new ApiError(400,`Failed to fetch drug and thier manufacturer ${err.message}`)
     }



  }
)


export {getAllDrugDetails,topSellingDrugs,topRevenueDrugs,addDrugToStock,getDrugAndManufacturer}