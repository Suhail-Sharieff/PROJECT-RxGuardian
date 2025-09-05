import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { db } from "../Utils/sql_connection.utils.js";

const getAllShopDetails=asyncHandler(
    async(req,res)=>{
        try{
            let { pgNo = 1 } = req.query;
            if (!pgNo && req.body.pgNo) {
                pgNo = req.body.pgNo;
            }
            const page = parseInt(pgNo, 10);
            if (isNaN(page) || page < 1) {
                throw new ApiError(400, "Page number must be a positive integer.");
            }
            const limit = 10;
            const offset = (page - 1) * limit;
            const query=`
            select s.shop_id,s.name as shop_name,s.address,s.phone,p.name as manager_name from shop as s
            left join pharmacist as p
            on pharmacist_id=manager_id
            limit ${limit} offset ${offset}
            `
            const [rows]=await db.execute(query)
            if(page>=rows.length) throw new ApiError(400,"End of data!")
            return res.status(200)
            .json(
                new ApiResponse(200,rows,"Fetched all shop details!")
            )
        }catch(err){
            throw new ApiError(400,err.message)
        }
    }
)

const getMyShopAnalysis = asyncHandler(
    async (req, res) => {
      const { pharmacist_id } = req.pharmacist;
  
      const getMyShop = `
        SELECT s.shop_id AS myShopId, s.name AS myShopName
        FROM employee AS e
        INNER JOIN pharmacist AS p ON e.pharmacist_id = p.pharmacist_id
        INNER JOIN shop AS s ON e.shop_id = s.shop_id
        WHERE p.pharmacist_id = ?
      `;
      const [temp] = await db.execute(getMyShop, [pharmacist_id]);
  
      if (!temp) throw new ApiError(400, "Failed to fetch your shop!");
      if (temp.length === 0)
        throw new ApiError("You are not a part of any pharmacy shop yet!");
  
      const { myShopId, myShopName } = temp[0];
      console.log(
        `getting shop analysis for shop_id ${myShopId} ie ${myShopName}........`
      );
  
      // pagination
      let { pgNo = 1, searchManufacturer = "", searchDrugType = "" } = req.query;
      if (!pgNo && req.body.pgNo) pgNo = req.body.pgNo;
      const page = parseInt(pgNo, 10);
      if (isNaN(page) || page < 1) {
        throw new ApiError(400, "Page number must be a positive integer.");
      }
      const limit = 10;
      const offset = (page - 1) * limit;
  
      // filters
      const filters = [];
      const params = [myShopId]; // always first param
  
      if (searchManufacturer && searchManufacturer.trim() !== "") {
        filters.push("LOWER(m.name) LIKE ?");
        params.push(searchManufacturer.trim().toLowerCase() + "%");
      }
      if (searchDrugType && searchDrugType.trim() !== "") {
        filters.push("LOWER(d.type) LIKE ?");
        params.push(searchDrugType.trim().toLowerCase() + "%");
      }
  
      const whereClause = filters.length ? `AND ${filters.join(" AND ")}` : "";
  
      const query = `
        SELECT 
          m.name AS manufacturer_name,
          d.type AS drug_type,
          ROUND(AVG(d.selling_price), 2) AS avg_selling_price,
          ROUND(AVG(((d.selling_price - d.cost_price) / d.cost_price) * 100), 2) AS avg_profit_percent,
          IFNULL(ROUND(SUM(si.quantity) / NULLIF(COUNT(DISTINCT DATE_FORMAT(s.date, '%Y-%m')),0), 2), 0) AS avg_sold_per_month,
          IFNULL(ROUND(SUM(si.quantity) / NULLIF(COUNT(DISTINCT YEAR(s.date)),0), 2), 0) AS avg_sold_per_year
        FROM drug AS d
        LEFT JOIN manufacturer AS m
          ON d.manufacturer_id = m.manufacturer_id
        LEFT JOIN sale_item AS si
          ON d.drug_id = si.drug_id
        LEFT JOIN sale AS s
          ON si.sale_id = s.sale_id AND s.shop_id = ?
        WHERE 1=1 ${whereClause}
        GROUP BY m.name, d.type
        ORDER BY d.type, m.name
        LIMIT ${limit} OFFSET ${offset};
      `;
  
  
      const [rows] = await db.execute(query, params);
  
      if (!rows) throw new ApiError(400, "Failed to fetch your shop analysis!");
      if (rows.length === 0)
        return res
          .status(200)
          .json(
            new ApiResponse(200, [], `No results for your search in ${myShopName}`)
          );
  
      return res
        .status(200)
        .json(
          new ApiResponse(
            200,
            rows,
            `Fetched shop details for ${myShopId}::${myShopName}!`
          )
        );
    }
  );
  

export{getAllShopDetails,getMyShopAnalysis}