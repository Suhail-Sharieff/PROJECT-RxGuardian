import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { getAllShopDetails, getMyShopAnalysis, getMyShopDrugStock } from "../controllers/shop.controller.js";


const shopRouter=Router()

shopRouter.use(verifyJWT)

shopRouter
.route('/getAllShopDetails')
.get(getAllShopDetails)


shopRouter
.route('/getMyShopAnalysis')
.get(getMyShopAnalysis)

shopRouter
.route('/getMyShopDrugStock')
.get(getMyShopDrugStock)


export {shopRouter}

