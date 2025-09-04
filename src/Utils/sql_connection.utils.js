import dotenv from "dotenv";
import { createPool } from "mysql2";
dotenv.config();

const db = createPool({
    host: process.env.DB_HOST,
    user: process.env.DB_USER,
    password: process.env.DB_PASSWORD,
    database: process.env.DB_NAME,
    connectionLimit: 10,
    connectTimeout: 10000,
    multipleStatements:true,//becoz we r executing multiple statements in init_queries
}).promise();

const connect_To_DB = async () => {
    try {
        const connection = await db.getConnection();
        console.log("✅ MySQL DB connected");
        connection.release();
    } catch (err) {
        console.error("❌ DB connection error:", err.code, err.sqlMessage || err.message);
        throw err;
    }
};

const initDB = async (init_query) => {
    const connection = await db.getConnection();
    try {
        await connection.beginTransaction();
        await connection.query(init_query);
        await connection.commit();
        console.log("✅ Database schema initialized successfully");
    } catch (err) {
        console.error("❌ Schema init failed, rolling back:", err.code, err.sqlMessage || err.message);
        await connection.rollback();
    } finally {
        connection.release();
    }
};

export { connect_To_DB, initDB, db };
