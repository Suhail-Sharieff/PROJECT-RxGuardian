import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { addBalance, deductBalance, getAllShopDetails, getMyShopAnalysis, getMyShopDrugStock, getShopBalance, getShopImWorkingIn, getShopNameImWorkingIn, registerShopAndBecomeManager } from "../controllers/shop.controller.js";


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

shopRouter
.route('/getShopName')
.get(getShopNameImWorkingIn)

shopRouter
.route('/registerShop')
.put(registerShopAndBecomeManager)


shopRouter
.route('/getShopBalance')
.get(getShopBalance)


shopRouter
.route('/addBalance')
.patch(addBalance)

shopRouter
.route('/deductBalance')
.patch(deductBalance)

export {shopRouter}

