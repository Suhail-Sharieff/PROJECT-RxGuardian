import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { db } from "../Utils/sql_connection.utils.js";



const getAllDrugDetails=asyncHandler(
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

            return res.status(200).json(
                new ApiResponse(200,rows)
            )

        }catch(err){
            throw new ApiError(400,err.message);
        }
    }
)
//get analysus:
/**SELECT 
    m.name AS manufacturer_name,
    d.type AS drug_type,
    ROUND(AVG(d.selling_price), 2) AS avg_selling_price,
    ROUND(AVG(((d.selling_price - d.cost_price) / d.cost_price) * 100), 2) AS avg_profit_percent,

    ifnull(ROUND(SUM(si.quantity) / COUNT(DISTINCT DATE_FORMAT(s.date, '%Y-%m')), 2),0) AS avg_sold_per_month,
    ifnull(ROUND(SUM(si.quantity) / COUNT(DISTINCT YEAR(s.date)), 2),0) AS avg_sold_per_year

FROM drug AS d
LEFT JOIN manufacturer AS m
    ON d.manufacturer_id = m.manufacturer_id
LEFT JOIN sale_item AS si
    ON d.drug_id = si.drug_id
LEFT JOIN sale AS s
    ON si.sale_id = s.sale_id

GROUP BY m.name, d.type
ORDER BY d.type, m.name;
 */
export {getAllDrugDetails}