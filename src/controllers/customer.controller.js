import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { db } from "../Utils/sql_connection.utils.js";
import { buildPaginatedFilters } from "../Utils/paginated_query_builder.js";
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
      
            const query=`select * from customer where 1=1 ${whereClause} limit ${limit} offset ${offset}`
            
            const [rows]=await db.execute(query,params);
    
            return res.status(200).json(new ApiResponse(200,rows));
        } catch (error) {
            throw new ApiError(400,error.message)
        }
    }
)


export {getCutomerByPhone,createCustomer}