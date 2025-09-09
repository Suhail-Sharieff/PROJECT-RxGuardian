import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { getDateVsRevenue, getDateVsSale, getDetailsOfSale, getOverallSales, initSale } from "../controllers/sale.controller.js";



const saleRouter=Router()
saleRouter.use(verifyJWT);


saleRouter.route('/initSale')
.post(initSale)


saleRouter
.route('/getOverallSales')
.get(getOverallSales)


saleRouter
.route('/getDetailsOfSale/:sale_id')
.get(getDetailsOfSale)


saleRouter
.route('/getDateVsRevenue')
.get(getDateVsRevenue)


saleRouter
.route('/getDateVsSale')
.get(getDateVsSale)

export {saleRouter}