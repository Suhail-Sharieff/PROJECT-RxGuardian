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

const getMyShopAnalysis=asyncHandler(
    async(req,res)=>{
        const {pharmacist_id}=req.pharmacist;
        const getMyShop=`select s.shop_id as myShopId,s.name as myShopName from employee as e
                inner join pharmacist as p on e.pharmacist_id=p.pharmacist_id
                inner join shop as s on e.shop_id=s.shop_id
                where p.pharmacist_id= ?`
        const [temp]=await db.execute(getMyShop,[pharmacist_id])
        if(!temp) throw new ApiError(400,"Failed to fetch your shop!");
        const {myShopId,myShopName}=temp[0];
        console.log(`getting shop anaysis for shop_id ${myShopId} ie ${myShopName}........`);
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
            ON  si.sale_id = s.sale_id and 
            s.shop_id= ?
            GROUP BY m.name, d.type
            ORDER BY d.type, m.name
            limit ${limit} offset ${offset}
        `

        const [rows]=await db.execute(query,[myShopId])
        if(page>=rows.length) throw new ApiError(400,"End of data!")
        if(!rows) throw new ApiError(400,"Failed to fech your shop analysis!")
        if(rows.length===0) throw new ApiError(400,"You are not an employee of any shop!")
        return res.status(200).json(new ApiResponse(200,rows,`Fetched shop details for ${myShopId}::${myShopName}!`))
    }
)

export{getAllShopDetails,getMyShopAnalysis}