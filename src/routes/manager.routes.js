import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { verifyManagerAccess } from "../middleware/manager_chk.middleware.js";
import { addEmployee, getEmployeeDetails, isManager, removeEmployee, updateEmployeeSalary } from "../controllers/manager.controller.js";


const managerRouter=Router()


managerRouter
.use(verifyJWT,verifyManagerAccess)

managerRouter.route('/').get(isManager)

managerRouter
.route('/getEmployeeDetails')
.get(getEmployeeDetails)


managerRouter
.route('/removeEmployee/:id')
.delete(removeEmployee)

managerRouter
.route("/updateEmployeeSalary")
.patch(updateEmployeeSalary)

managerRouter
.route("/addEmployee")
.put(addEmployee)

export {managerRouter}