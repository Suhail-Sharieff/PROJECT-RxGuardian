import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { addManufacturer, getAllManufacturers } from "../controllers/manufacturer.controller.js";

const manufacturerRoute=Router()


manufacturerRoute.use(verifyJWT)


manufacturerRoute
.route('/getAllManufacturers')
.get(getAllManufacturers)

manufacturerRoute
.route('/addManufacturer')
.post(addManufacturer)


export {manufacturerRoute}