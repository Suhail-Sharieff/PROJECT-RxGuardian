import dotenv from "dotenv";
import { createPool } from "mysql2";
dotenv.config();

const db = createPool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  connectionLimit: 10,
  connectTimeout: 10000,
  multipleStatements: true, // because we execute multiple statements in init_queries
  port: process.env.DB_PORT,
}).promise();

/*
 Retry wrapper for DB connection, because it doent cause problem while testing locally coz for local testing we initilized in workbench and then launched the node server, but when we ty testing using docker without retry logic, then, both mysql and node server container will try running parallely, the node may try to connect to sql before the sql engine is initilized, so its important to add a retry logic so that it retries again to connect unitll docker sql engine is initilized
 */
const connect_To_DB = async () => {
  let retries = 10;
  while (retries) {
    try {
      const connection = await db.getConnection();
      console.log("✅ MySQL DB connected");
      connection.release();
      return;
    } catch (err) {
      console.error(
        `❌ DB connection error (${err.code}): ${
          err.sqlMessage || err.message
        }. Retrying in 5s...`
      );
      retries -= 1;
      if (!retries) throw new Error("❌ Could not connect to DB after retries");
      await new Promise((res) => setTimeout(res, 5000));
    }
  }
};

/**
 * Initialize DB schema safely inside a transaction
 */
const initDB = async (init_query) => {
  const connection = await db.getConnection();
  try {
    await connection.beginTransaction();
    await connection.query(init_query);
    await connection.commit();
    console.log("✅ Database schema initialized successfully");
  } catch (err) {
    console.error(
      "❌ Schema init failed, rolling back:",
      err.code,
      err.sqlMessage || err.message
    );
    await connection.rollback();
  } finally {
    connection.release();
  }
};

export { connect_To_DB, initDB, db };
