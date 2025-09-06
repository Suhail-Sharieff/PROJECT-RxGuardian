import { ApiError } from "../Utils/Api_Error.utils.js";
import { db } from "../Utils/sql_connection.utils.js";



const verifyManagerAccess=
    async(req,res,next)=>{
      try{
            const {pharmacist_id}=req.pharmacist;
            const query=
            `
            select shop_id from shop
            left join pharmacist
            on pharmacist_id=manager_id
            where pharmacist_id= ?`
            const [rows]=await db.execute(query,[pharmacist_id]);
            if(rows.length===0) throw new ApiError(400,"You must be manager to access this!");
            console.log('curr pharmacist is also a manager..');
            req.shop_id=rows[0].shop_id
            next()
      }catch(err){
            throw new ApiError(400,err.message);
      }
    }
export {verifyManagerAccess}