import { Router } from "express"
import { registerPharmacist,loginPharmacist, logoutPharmacist, updatePassword, updateName} from "../controllers/pharmacist.controller.js"
import { verifyJWT } from "../middleware/auth.middleware.js";

const pharmacistRouter=Router()


pharmacistRouter
.route( '/register')
.post(
    registerPharmacist
);



pharmacistRouter
.route('/login')
.post(
    loginPharmacist,
)

pharmacistRouter
.route('/logout')
.post(
    verifyJWT,
    logoutPharmacist
)



pharmacistRouter
.route('/updatePassword')
.post(
    verifyJWT,
    updatePassword
)
pharmacistRouter
.route('/updateName')
.post(
    verifyJWT,
    updateName
)






export {pharmacistRouter}