import { db } from "../Utils/sql_connection.utils.js";
import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import bcrypt from "bcryptjs";
import { redis } from "../Utils/redis.connection.js";

const getAllManufacturers = asyncHandler(async (req, res) => {
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
    const query = `SELECT * FROM manufacturer ORDER BY manufacturer_id LIMIT ${limit} OFFSET ${offset}`;


    const key=`getAllManufacturers:${limit}:${offset}:${page}`
    const cache=await redis.get(key)
    if(cache) return res.status(200).json(new ApiResponse(200,JSON.parse(cache),"Fetch manufactuers from redis!"))


    const [rows] = await db.execute(query);
    if (rows.length === 0) {
        return res.status(200).json(
            new ApiResponse(
                200,
                [],
                "No manufacturers found for this page."
            )
        );
    }
    const manufacturers = rows;

    await redis.set(key,JSON.stringify(manufacturers))
    await redis.expire(key,40)


    return res.status(200).json(
        new ApiResponse(
            200,
            manufacturers,
            "Fetched manufacturers successfully!"
        )
    );
});


const addManufacturer=asyncHandler(
    async(req,res)=>{

        const {name,address,phone,email,license,password}=req.body;
        if ([email, password, name, license, address, phone].some((e) => e === undefined || e?.trim?.() === "")) {
            throw new ApiError(400, "Some fields are empty or missing!");
        }
        

        const saltRounds = 10;
        const hashedPassword = await bcrypt.hash(password, saltRounds);
        const query='insert into manufacturer (name,address,phone,email,license,password) values (?,?,?,?,?,?)'

        const [rows]=await db.execute(query,[name,address,phone,email,license,hashedPassword]);
        if(rows.affectedRows==0) throw new ApiError(400,"Failed to register manufacturer!")


       return res.status(200).json(new ApiResponse(200, { manufacturer_id: rows.insertId }, "Manufacturer registered successfully.")
            );
    }
)

export { getAllManufacturers,addManufacturer };