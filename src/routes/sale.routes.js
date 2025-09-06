import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";



const saleRouter=Router()
saleRouter.use(verifyJWT);

export {saleRouter}