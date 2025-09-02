import dotenv from "dotenv";
import { createPool } from "mysql2";
dotenv.config();

// Create a pool for MySQL
const db = createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    connectionLimit: 10,
    connectTimeout: 10000, 
}).promise();

// Function to get a connection from the pool
const connect_To_DB = async () => {
    try {
        const connection = await db.getConnection();
        console.log("MySQL DB connected");
        connection.release();
    } catch (err) {
        console.error("DB connection error:", err.message);
        throw err;
    }
};


export {connect_To_DB,db};