import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import { getAllDrugDetails } from "../controllers/drug.controller.js";

const drugRouter=Router()


drugRouter.use(verifyJWT)


drugRouter
.route('/getAllDrugDetails')
.get(getAllDrugDetails)




export {drugRouter}