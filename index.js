import { app } from "./src/app.js";
import {connect_To_DB} from "./src/Utils/sql_connection.utils.js";

connect_To_DB()
.then(
    ()=>{
        app.listen(
            process.env.PORT||8080,
            "0.0.0.0",
            ()=>{
                console.log(`SERVER RUNNING: GO TO http://localhost:${process.env.PORT}/`);
            }
        )
    }
)
.catch(
    (err)=>{
        console.log("SERVER ERROR");
        process.exit()
    }
)