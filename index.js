import { app } from "./src/app.js";
import {connect_To_DB,initDB} from "./src/Utils/sql_connection.utils.js";
import { init_query } from "./src/queries/__init__.js";
import { init_redis} from "./src/Utils/redis.connection.js";
import { socketManager } from "./src/Utils/socket.io.utils.js";
import { createServer } from "http";

const PORT = process.env.PORT;

const startServer = async () => {
  try {
    await connect_To_DB();
    await initDB(init_query);
    await init_redis();
    
    // Create HTTP server
    const server = createServer(app);
    
    // Initialize Socket.IO
    socketManager.initialize(server);
    
    server.listen(PORT, "0.0.0.0", () => {
      console.log(`✅ SERVER RUNNING: http://localhost:${PORT}`);
      console.log(`✅ SOCKET.IO ENABLED AT ${JSON.stringify(server.address())}`);
    });
  } catch (err) {
    console.error("❌ SERVER ERROR:", err.message);
    process.exit(1);
  }
};

startServer();