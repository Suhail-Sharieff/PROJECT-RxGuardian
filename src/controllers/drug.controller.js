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

export {getAllDrugDetails}