import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { verifyManagerAccess } from "../middleware/manager_chk.middleware.js";
import { addEmployee, getAllEmployables, getEmployeeDetails, getEmployeesOfMyShop, hirePharmacist, isManager,  removeEmployee, updateEmployeeSalary } from "../controllers/manager.controller.js";


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

managerRouter
.route('/getAllEmployables')
.get(getAllEmployables)

managerRouter
.route('/hirePharmacist')
.patch(hirePharmacist);


managerRouter
.route('/getEmployeesOfMyShop')
.get(getEmployeesOfMyShop)



export {managerRouter}