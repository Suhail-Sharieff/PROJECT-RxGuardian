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
            return res.status(200)
            .json(
                new ApiResponse(200,rows,"Fetched all shop details!")
            )
        }catch(err){
            throw new ApiError(400,err.message)
        }
    }
)

export{getAllShopDetails}