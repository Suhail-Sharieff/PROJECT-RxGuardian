import express, { urlencoded } from "express"
import cookieParser from "cookie-parser"
import cors from "cors"



const app = express()

//CORS Middle ware

app.use(
    cors(//allow access for all
        {
            origin: process.env.CORS_ORIGIN,
            credentials: true, // THIS IS CRITICAL for cookies to work
            methods: ["GET", "POST", "PUT", "DELETE", "PATCH"],
            allowedHeaders: ["Content-Type", "Authorization"]
        }
    )
)


//Allow json data transfer within app

app.use(
    express.json(
        
    )
)

//to make constant routs like some take %20, some take +, we ensure constant
app.use(
    express.urlencoded(
        {
            extended:true,
        }
    )
)


//direct fetchable files
app.use(
    express.static(
        "public"
    )
)

app.use(
    cookieParser(

    )
)

//configuring routes
import { pharmacistRouter } from "./routes/pharmacist.routes.js"
app.use('/auth',pharmacistRouter)


import { manufacturerRoute } from "./routes/manufacturer.routes.js"
app.use('/manufacturer',manufacturerRoute)

import { shopRouter } from "./routes/shop.routes.js"
app.use('/shop',shopRouter)

import { drugRouter } from "./routes/drug.router.js"
app.use('/drug',drugRouter)


import { saleRouter } from "./routes/sale.routes.js"
app.use('/sale',saleRouter)


import { managerRouter } from "./routes/manager.routes.js"
app.use('/manager',managerRouter)

import { ApiError } from "./Utils/Api_Error.utils.js"
app.use((err, req, res, next) => {
    console.log(`ERROR: ${err.message}`);
    if (err instanceof ApiError) {
        return res.status(err.statusCode).json({
            success: err.success,
            message: err.message,
            errors: err.errors,
            stack: process.env.NODE_ENV === "development" ? err.stack : undefined
        });
    }

    // Default handler for unhandled errors
    console.log(`ERROR: ${err}`);
    res.status(500).json({
        status:500,
        success: false,
        message: err.message || "Internal Server Error"
    });
    throw err;
});

export {app}