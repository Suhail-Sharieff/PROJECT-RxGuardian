import { Router } from "express"
import { registerPharmacist,loginPharmacist, logoutUser, refreshAccessToken, updatePassword, updateFullName} from "../controllers/pharmacist.controller.js"
import { verifyJWT } from "../middleware/auth.middleware.js";

const pharmacistRouter=Router()


pharmacistRouter
.route( '/register')
.post(
    registerPharmacist
);

//to apply jswt verify on all routs just say router.use(verifyjwt), then can use normal post without jwt middle ware

pharmacistRouter
.route('/login')
.post(
    loginPharmacist,
)

pharmacistRouter
.route('/logout')
.post(
    verifyJWT,//middleware to append user field to req after matching actuall  accessToken and accessToken passed to req with cookie
    logoutUser
)

pharmacistRouter
.route("/refreshAccessToken")
.post(
    refreshAccessToken
)


pharmacistRouter
.route('/updatePassword')
.post(
    verifyJWT,updatePassword
)






export {pharmacistRouter}