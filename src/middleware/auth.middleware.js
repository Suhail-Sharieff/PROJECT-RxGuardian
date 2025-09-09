import jwt from "jsonwebtoken";
import { ApiError } from "../Utils/Api_Error.utils.js";

export const verifyJWT = (req, res, next) => {
  try {
    // Get token from cookie or header
    const token =
      req.cookies?.accessToken||
        req.header("authorization")?.replace(/Bearer\s*/i, "").trim();

    if (!token) {
      throw new ApiError(401, "Unauthorized, token missing!");
    }

    // Verify token
    const decoded = jwt.verify(token, process.env.ACCESS_TOKEN_SECRET);

    // Attach decoded pharmacist details to req
    req.pharmacist = {
      pharmacist_id: decoded.pharmacist_id,
      email: decoded.email,
      name: decoded.name,
    };

    // console.log("✅ JWT verified, pharmacist attached:", req.pharmacist);
    console.log(`😁 JWT verified 'pharmacist' can be now accesed using req.pharmacist `);
    next();
  } catch (err) {
    console.error("❌ JWT verification failed:", err.message);
    next(new ApiError(401, "Unauthorized, invalid or expired token!"));
  }
};
