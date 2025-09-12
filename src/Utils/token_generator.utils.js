import { getPharmacistById } from "../controllers/pharmacist.controller.js";
import { ApiError } from "./Api_Error.utils.js";
import { db } from "./sql_connection.utils.js";
import jwt from "jsonwebtoken"
import bcrypt from "bcryptjs"

const generateAccessToken = (pharmacist)=>{
    return jwt.sign(
        {
            pharmacist_id: pharmacist.pharmacist_id,
            email: pharmacist.email,
            name: pharmacist.name,
        },
        process.env.ACCESS_TOKEN_SECRET,
        {
            expiresIn: process.env.ACCESS_TOKEN_EXPIRY
        }
    )
}
const generateRefreshToken = (pharmacist)=>{
    return jwt.sign(
        {
            pharmacist_id: pharmacist.pharmacist_id,
            email: pharmacist.email,
            name: pharmacist.name,
            
        },
        process.env.REFRESH_TOKEN_SECRET,
        {
            expiresIn: process.env.REFRESH_TOKEN_EXPIRY
        }
    )
}
/**Access Token: This is a short-lived token that allows a pharmacist or application to access protected resources (like an API). Once it expires, the pharmacist needs a new one.

Refresh Token: This is a longer-lived token used to obtain a new access token without requiring the pharmacist to log in again. It's more secure because it's not sent with every request. */
const get_refresh_access_token=async(pharmacist_id)=>{
    try {
        console.log("Generating toekns for pharmacist.......");
        const curr_pharmacist=await getPharmacistById(pharmacist_id)
        const refreshToken=generateRefreshToken(curr_pharmacist);
        const accessToken=generateAccessToken(curr_pharmacist);
        console.log(`Refresh and accss tokens are generated.....`);

        console.log("Saving refresh token into DB.....");
        await db.execute(
      `UPDATE pharmacist SET refreshToken = ? WHERE pharmacist_id = ?`,
      [refreshToken, pharmacist_id]
    );

    console.log("Updated refresh token of pharmacist successfully.");
    return {accessToken,refreshToken};
        
    } catch (error) {
        throw new ApiError(400,"Error while generating refresh token!")
    }
}


export {get_refresh_access_token}