import { app } from "./src/app.js";
import {connect_To_DB,initDB} from "./src/Utils/sql_connection.utils.js";
import { init_query } from "./src/queries/__init__.js";
const PORT = process.env.PORT;

const startServer = async () => {
  try {
    await connect_To_DB();

    await initDB(init_query);

    app.listen(PORT, "0.0.0.0", () => {
      console.log(`✅ SERVER RUNNING: http://localhost:${PORT}`);
    });
  } catch (err) {
    console.error("❌ SERVER ERROR:", err.message);
    process.exit(1);
  }
};

startServer();