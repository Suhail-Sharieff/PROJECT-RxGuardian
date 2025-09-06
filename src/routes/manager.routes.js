import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { verifyManagerAccess } from "../middleware/manager_chk.middleware.js";
import { getEmployeeDetails, isManager } from "../controllers/manager.controller.js";


const managerRouter=Router()


managerRouter
.use(verifyJWT,verifyManagerAccess)

managerRouter.route('/').get(isManager)

managerRouter
.route('/getEmployeeDetails')
.get(getEmployeeDetails)

export {managerRouter}