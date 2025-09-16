import { createClient } from 'redis';
import dotenv from "dotenv";
dotenv.config();

let redis;

const init_redis = async () => {
  try {
    if (!redis) {
      redis = createClient({
        url: `redis://${process.env.REDIS_HOST}:${process.env.REDIS_PORT}`,
      });

      redis.on("error", (err) => {
        console.error("Redis Client Error", err);
      });

      await redis.connect();
      console.log("✅ Connected to Redis");
    }
  } catch (err) {
    console.error("Redis init error:", err);
    await close_redis()
  }
};

const close_redis = async () => {
  if (redis) {
    await redis.quit();
    console.log("🚪 Redis connection closed");
  }
};

export { init_redis,redis };
