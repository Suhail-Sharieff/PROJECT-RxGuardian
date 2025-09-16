import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { addDrugToStock, getAllDrugDetails, getDrugAndManufacturer, topRevenueDrugs, topSellingDrugs } from "../controllers/drug.controller.js";

const drugRouter=Router()


drugRouter.use(verifyJWT)


drugRouter
.route('/getAllDrugDetails')
.get(getAllDrugDetails)


drugRouter
.route('/topSelling')
.get(topSellingDrugs)

drugRouter
.route('/topRevenue')
.get(topRevenueDrugs)

drugRouter
.route('/addDrugToStock')
.put(addDrugToStock)



drugRouter
.route('/getDrugAndManufacturer')
.get(getDrugAndManufacturer)


export {drugRouter}