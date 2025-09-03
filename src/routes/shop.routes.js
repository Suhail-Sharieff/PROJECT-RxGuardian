import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { getAllShopDetails } from "../controllers/shop.controller.js";


const shopRouter=Router()

shopRouter.use(verifyJWT)

shopRouter
.route('/getAllShopDetails')
.get(getAllShopDetails)


export {shopRouter}

