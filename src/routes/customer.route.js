import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { avgBasketSize, avgDaysBetweenCustomerPurchase, avgItemsPerSale, avgNumberOfTimesCustomerVisisted, createCustomer, customerFrequencyDistribution,  getCutomerByPhone, newVsReturning } from "../controllers/customer.controller.js";


const customerRouter=Router()

customerRouter.use(verifyJWT)


customerRouter
.route('/getCutomerByPhone')
.get(getCutomerByPhone)


customerRouter
.route('/createCustomer')
.post(createCustomer);


customerRouter
.route('/avgNumberOfTimesCustomerVisisted')
.get(avgNumberOfTimesCustomerVisisted)


customerRouter
.route('/avgBasketSize')
.get(avgBasketSize)

customerRouter
.route('/avgItemsPerSale')
.get(avgItemsPerSale)


customerRouter
.route('/newVsReturning')
.get(newVsReturning)

customerRouter
.route('/customerFrequencyDistribution')
.get(customerFrequencyDistribution)

customerRouter
.route('/avgDaysBetweenCustomerPurchase')
.get(avgDaysBetweenCustomerPurchase)



export {customerRouter}