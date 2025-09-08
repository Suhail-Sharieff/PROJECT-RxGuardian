import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { createCustomer, getCutomerByPhone } from "../controllers/customer.controller.js";


const customerRouter=Router()

customerRouter.use(verifyJWT)


customerRouter
.route('/getCutomerByPhone')
.get(getCutomerByPhone)


customerRouter
.route('/createCustomer')
.post(createCustomer);

export {customerRouter}