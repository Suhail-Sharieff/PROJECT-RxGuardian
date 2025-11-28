import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import {
    sendCustomNotification,
    triggerDailyNotifications,
    triggerWeeklyNotifications,
    triggerMonthlyNotifications,
    getNotifications
} from "../controllers/notification.controller.js";

const router = Router();

// Apply JWT authentication to all routes
router.use(verifyJWT);

// ===============================
// Notification Routes
// ===============================
// Get all notifications for the authenticated user
router.get("/", getNotifications); 
// Send custom notification
router.post("/send", sendCustomNotification);

// Trigger notifications (for testing)
router.post("/trigger/daily", triggerDailyNotifications);
router.post("/trigger/weekly", triggerWeeklyNotifications);
router.post("/trigger/monthly", triggerMonthlyNotifications);

export { router as notificationRouter };
