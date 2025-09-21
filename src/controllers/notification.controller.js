import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { db } from "../Utils/sql_connection.utils.js";
import { socketManager } from "../Utils/socket.io.utils.js";
import cron from "node-cron";

class NotificationService {
    constructor() {
        this.setupCronJobs();
    }

    setupCronJobs() {
        // Daily notifications at 6 PM
        cron.schedule('0 18 * * *', () => {
            console.log('🕕 Running daily notifications...');
            this.sendDailyNotifications();
        });

        // Weekly notifications on Sunday at 7 PM
        cron.schedule('0 19 * * 0', () => {
            console.log('📅 Running weekly notifications...');
            this.sendWeeklyNotifications();
        });

        // Monthly notifications on 1st at 8 PM
        cron.schedule('0 20 1 * *', () => {
            console.log('📆 Running monthly notifications...');
            this.sendMonthlyNotifications();
        });

        console.log('✅ Notification cron jobs scheduled');
    }

    // ===============================
    // Daily Notifications
    // ===============================
   
    async sendDailyNotifications() {
        try {
            const notifications = await this.generateDailyNotifications();

            // Send to all online users
            socketManager.broadcast('daily_notifications', {
                type: 'daily_summary',
                data: notifications,
                timestamp: new Date().toISOString()
            });

            // Store in database for offline users
            await this.storeNotifications(notifications, 'daily');

            console.log('📊 Daily notifications sent successfully');
        } catch (error) {
            console.error('❌ Error sending daily notifications:', error);
        }
    }

    async generateDailyNotifications() {
        const today = new Date().toISOString().split('T')[0];
        const notifications = [];

        // 1. Top sold drug today
        const topDrugToday = await this.getTopSoldDrugToday(today);
        if (topDrugToday) {
            notifications.push({
                id: 'top_drug_today',
                title: '🔥 Top Selling Drug Today',
                message: `${topDrugToday.drug_name} sold ${topDrugToday.total_quantity} units`,
                type: 'success',
                data: topDrugToday
            });
        }

        // 2. Shop revenue ranking today
        const shopRankingToday = await this.getShopRevenueRankingToday(today);
        notifications.push({
            id: 'shop_ranking_today',
            title: '🏆 Shop Performance Today',
            message: `Your shop ranked #${shopRankingToday.rank} with ₹${shopRankingToday.revenue} revenue`,
            type: 'info',
            data: shopRankingToday
        });

        // 3. Best employee today
        const bestEmployeeToday = await this.getBestEmployeeToday(today);
        if (bestEmployeeToday) {
            notifications.push({
                id: 'best_employee_today',
                title: '⭐ Top Performer Today',
                message: `${bestEmployeeToday.employee_name} made ${bestEmployeeToday.sales_count} sales`,
                type: 'success',
                data: bestEmployeeToday
            });
        }

        // 4. Net profit today
        const netProfitToday = await this.getNetProfitToday(today);
        notifications.push({
            id: 'net_profit_today',
            title: '💰 Daily Profit Summary',
            message: `Net profit today: ₹${netProfitToday.profit} (Revenue: ₹${netProfitToday.revenue}, Cost: ₹${netProfitToday.cost})`,
            type: netProfitToday.profit > 0 ? 'success' : 'warning',
            data: netProfitToday
        });

        // 5. Most interactive employee today
        const mostInteractiveToday = await this.getMostInteractiveEmployeeToday(today);
        if (mostInteractiveToday) {
            notifications.push({
                id: 'most_interactive_today',
                title: '💬 Most Interactive Today',
                message: `${mostInteractiveToday.employee_name} had ${mostInteractiveToday.interaction_score} interactions`,
                type: 'info',
                data: mostInteractiveToday
            });
        }

        return notifications;
    }

    // ===============================
    // Weekly Notifications
    // ===============================
    async sendWeeklyNotifications() {
        try {
            const notifications = await this.generateWeeklyNotifications();

            socketManager.broadcast('weekly_notifications', {
                type: 'weekly_summary',
                data: notifications,
                timestamp: new Date().toISOString()
            });

            await this.storeNotifications(notifications, 'weekly');

            console.log('📊 Weekly notifications sent successfully');
        } catch (error) {
            console.error('❌ Error sending weekly notifications:', error);
        }
    }

    async generateWeeklyNotifications() {
        const weekStart = this.getWeekStart();
        const notifications = [];

        // 1. Top selling drugs this week
        const topDrugsWeek = await this.getTopSellingDrugsWeek(weekStart);
        if (topDrugsWeek.length > 0) {
            notifications.push({
                id: 'top_drugs_week',
                title: '🔥 Top Selling Drugs This Week',
                message: `Top 3: ${topDrugsWeek.slice(0, 3).map(d => d.drug_name).join(', ')}`,
                type: 'success',
                data: topDrugsWeek
            });
        }

        // 2. Shop performance ranking this week
        const shopRankingWeek = await this.getShopRevenueRankingWeek(weekStart);
        notifications.push({
            id: 'shop_ranking_week',
            title: '🏆 Weekly Shop Performance',
            message: `Your shop ranked #${shopRankingWeek.rank} with ₹${shopRankingWeek.revenue} revenue`,
            type: 'info',
            data: shopRankingWeek
        });

        // 3. Employee performance ranking this week
        const employeeRankingWeek = await this.getEmployeePerformanceRankingWeek(weekStart);
        if (employeeRankingWeek.length > 0) {
            notifications.push({
                id: 'employee_ranking_week',
                title: '⭐ Employee Performance This Week',
                message: `Top performer: ${employeeRankingWeek[0]?.employee_name} with ${employeeRankingWeek[0]?.sales_count} sales`,
                type: 'success',
                data: employeeRankingWeek
            });
        }

        // 4. Weekly profit summary
        const weeklyProfit = await this.getWeeklyProfit(weekStart);
        notifications.push({
            id: 'weekly_profit',
            title: '💰 Weekly Profit Summary',
            message: `Total profit this week: ₹${weeklyProfit.profit} (${weeklyProfit.growth > 0 ? '+' : ''}${weeklyProfit.growth}% vs last week)`,
            type: weeklyProfit.growth > 0 ? 'success' : 'warning',
            data: weeklyProfit
        });

        return notifications;
    }

    // ===============================
    // Monthly Notifications
    // ===============================
    async sendMonthlyNotifications() {
        try {
            const notifications = await this.generateMonthlyNotifications();

            socketManager.broadcast('monthly_notifications', {
                type: 'monthly_summary',
                data: notifications,
                timestamp: new Date().toISOString()
            });

            await this.storeNotifications(notifications, 'monthly');

            console.log('📊 Monthly notifications sent successfully');
        } catch (error) {
            console.error('❌ Error sending monthly notifications:', error);
        }
    }

    async generateMonthlyNotifications() {
        const monthStart = this.getMonthStart();
        const notifications = [];

        // 1. Monthly top selling drugs
        const topDrugsMonth = await this.getTopSellingDrugsMonth(monthStart);
        if (topDrugsMonth.length > 0) {
            notifications.push({
                id: 'top_drugs_month',
                title: '🔥 Top Selling Drugs This Month',
                message: `Top 5: ${topDrugsMonth.slice(0, 5).map(d => d.drug_name).join(', ')}`,
                type: 'success',
                data: topDrugsMonth
            });
        }

        // 2. Monthly shop ranking
        const shopRankingMonth = await this.getShopRevenueRankingMonth(monthStart);
        notifications.push({
            id: 'shop_ranking_month',
            title: '🏆 Monthly Shop Performance',
            message: `Your shop ranked #${shopRankingMonth.rank} with ₹${shopRankingMonth.revenue} revenue`,
            type: 'info',
            data: shopRankingMonth
        });

        // 3. Monthly employee awards
        const monthlyAwards = await this.getMonthlyAwards(monthStart);
        if (monthlyAwards.employee_of_month) {
            notifications.push({
                id: 'monthly_awards',
                title: '🏅 Monthly Awards',
                message: `Employee of the Month: ${monthlyAwards.employee_of_month.name}`,
                type: 'success',
                data: monthlyAwards
            });
        }

        // 4. Monthly profit and growth
        const monthlyProfit = await this.getMonthlyProfit(monthStart);
        notifications.push({
            id: 'monthly_profit',
            title: '💰 Monthly Profit Summary',
            message: `Total profit this month: ₹${monthlyProfit.profit} (${monthlyProfit.growth > 0 ? '+' : ''}${monthlyProfit.growth}% vs last month)`,
            type: monthlyProfit.growth > 0 ? 'success' : 'warning',
            data: monthlyProfit
        });

        return notifications;
    }

    // ===============================
    // Database Query Methods
    // ===============================

    async getTopSoldDrugToday(date) {
        const [rows] = await db.execute(`
            SELECT d.name as drug_name, SUM(si.quantity) as total_quantity, SUM(si.quantity * d.selling_price) as total_revenue
            FROM sale_item si
            JOIN drug d ON si.drug_id = d.drug_id
            JOIN sale s ON si.sale_id = s.sale_id
            WHERE DATE(s.date) = ?
            GROUP BY d.drug_id, d.name
            ORDER BY total_quantity DESC
            LIMIT 1
        `, [date]);
        return rows[0] || null;
    }

    async getShopRevenueRankingToday(date) {
        const [rows] = await db.execute(`
            SELECT s.shop_id, s.name as shop_name, 
                   COALESCE(SUM(sale.total_amount), 0) as revenue,
                   ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(sale.total_amount), 0) DESC) as \`rank\`
            FROM shop s
            LEFT JOIN (
                SELECT shop_id, SUM((si.quantity * d.selling_price) - (si.quantity * d.cost_price)) as total_amount
                FROM sale s
                JOIN sale_item si ON s.sale_id = si.sale_id
                JOIN drug d ON si.drug_id = d.drug_id
                WHERE DATE(s.date) = ?
                GROUP BY shop_id
            ) sale ON s.shop_id = sale.shop_id
            GROUP BY s.shop_id, s.name
            ORDER BY revenue DESC
        `, [date]);
        return rows[0] || { rank: 1, revenue: 0 };
    }

    async getBestEmployeeToday(date) {
        const [rows] = await db.execute(`
            SELECT p.name as employee_name, COUNT(s.sale_id) as sales_count,
                   SUM((si.quantity * d.selling_price) - (si.quantity * d.cost_price)) as total_profit
            FROM sale s
            JOIN pharmacist p ON s.pharmacist_id = p.pharmacist_id
            JOIN sale_item si ON s.sale_id = si.sale_id
            JOIN drug d ON si.drug_id = d.drug_id
            WHERE DATE(s.date) = ?
            GROUP BY p.pharmacist_id, p.name
            ORDER BY sales_count DESC
            LIMIT 1
        `, [date]);
        return rows[0] || null;
    }

    async getNetProfitToday(date) {
        const [rows] = await db.execute(`
            SELECT 
                COALESCE(SUM(si.quantity * d.selling_price), 0) as revenue,
                COALESCE(SUM(si.quantity * d.cost_price), 0) as cost,
                COALESCE(SUM(si.quantity * d.selling_price) - SUM(si.quantity * d.cost_price), 0) as profit
            FROM sale s
            JOIN sale_item si ON s.sale_id = si.sale_id
            JOIN drug d ON si.drug_id = d.drug_id
            WHERE DATE(s.date) = ?
        `, [date]);
        return rows[0] || { revenue: 0, cost: 0, profit: 0 };
    }

    async getMostInteractiveEmployeeToday(date) {
        const [rows] = await db.execute(`
            SELECT p.name as employee_name, 
                   COUNT(s.sale_id) * 2 + COUNT(DISTINCT s.customer_id) as interaction_score
            FROM sale s
            JOIN pharmacist p ON s.pharmacist_id = p.pharmacist_id
            WHERE DATE(s.date) = ?
            GROUP BY p.pharmacist_id, p.name
            ORDER BY interaction_score DESC
            LIMIT 1
        `, [date]);
        return rows[0] || null;
    }

    // ===============================
    // Weekly Query Methods
    // ===============================

    async getTopSellingDrugsWeek(weekStart) {
        const [rows] = await db.execute(`
            SELECT d.name as drug_name, SUM(si.quantity) as total_quantity,
                   SUM(si.quantity * d.selling_price) as total_revenue
            FROM sale_item si
            JOIN drug d ON si.drug_id = d.drug_id
            JOIN sale s ON si.sale_id = s.sale_id
            WHERE DATE(s.date) >= ?
            GROUP BY d.drug_id, d.name
            ORDER BY total_quantity DESC
            LIMIT 5
        `, [weekStart]);
        return rows;
    }

    async getShopRevenueRankingWeek(weekStart) {
        const [rows] = await db.execute(`
            SELECT s.shop_id, s.name as shop_name,
                   COALESCE(SUM(sale.total_amount), 0) as revenue,
                   ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(sale.total_amount), 0) DESC) as rank
            FROM shop s
            LEFT JOIN (
                SELECT shop_id, SUM((si.quantity * d.selling_price) - (si.quantity * d.cost_price)) as total_amount
                FROM sale s
                JOIN sale_item si ON s.sale_id = si.sale_id
                JOIN drug d ON si.drug_id = d.drug_id
                WHERE DATE(s.date) >= ?
                GROUP BY shop_id
            ) sale ON s.shop_id = sale.shop_id
            GROUP BY s.shop_id, s.name
            ORDER BY revenue DESC
        `, [weekStart]);
        return rows[0] || { rank: 1, revenue: 0 };
    }

    async getEmployeePerformanceRankingWeek(weekStart) {
        const [rows] = await db.execute(`
            SELECT p.name as employee_name, COUNT(s.sale_id) as sales_count,
                   SUM((si.quantity * d.selling_price) - (si.quantity * d.cost_price)) as total_profit,
                   ROW_NUMBER() OVER (ORDER BY COUNT(s.sale_id) DESC) as rank
            FROM sale s
            JOIN pharmacist p ON s.pharmacist_id = p.pharmacist_id
            JOIN sale_item si ON s.sale_id = si.sale_id
            JOIN drug d ON si.drug_id = d.drug_id
            WHERE DATE(s.date) >= ?
            GROUP BY p.pharmacist_id, p.name
            ORDER BY sales_count DESC
            LIMIT 10
        `, [weekStart]);
        return rows;
    }

    async getWeeklyProfit(weekStart) {
        const [rows] = await db.execute(`
            SELECT 
                COALESCE(SUM(si.quantity * d.selling_price), 0) as revenue,
                COALESCE(SUM(si.quantity * d.cost_price), 0) as cost,
                COALESCE(SUM(si.quantity * d.selling_price) - SUM(si.quantity * d.cost_price), 0) as profit
            FROM sale s
            JOIN sale_item si ON s.sale_id = si.sale_id
            JOIN drug d ON si.drug_id = d.drug_id
            WHERE DATE(s.date) >= ?
        `, [weekStart]);

        // Get previous week for comparison
        const prevWeekStart = new Date(weekStart);
        prevWeekStart.setDate(prevWeekStart.getDate() - 7);

        const [prevRows] = await db.execute(`
            SELECT 
                COALESCE(SUM(si.quantity * d.selling_price) - SUM(si.quantity * d.cost_price), 0) as profit
            FROM sale s
            JOIN sale_item si ON s.sale_id = si.sale_id
            JOIN drug d ON si.drug_id = d.drug_id
            WHERE DATE(s.date) >= ? AND DATE(s.date) < ?
        `, [prevWeekStart.toISOString().split('T')[0], weekStart]);

        const currentProfit = rows[0]?.profit || 0;
        const previousProfit = prevRows[0]?.profit || 0;
        const growth = previousProfit > 0 ? ((currentProfit - previousProfit) / previousProfit) * 100 : 0;

        return {
            ...rows[0],
            growth: Math.round(growth * 100) / 100
        };
    }

    // ===============================
    // Monthly Query Methods
    // ===============================

    async getTopSellingDrugsMonth(monthStart) {
        const [rows] = await db.execute(`
            SELECT d.name as drug_name, SUM(si.quantity) as total_quantity,
                   SUM(si.quantity * d.selling_price) as total_revenue
            FROM sale_item si
            JOIN drug d ON si.drug_id = d.drug_id
            JOIN sale s ON si.sale_id = s.sale_id
            WHERE DATE(s.date) >= ?
            GROUP BY d.drug_id, d.name
            ORDER BY total_quantity DESC
            LIMIT 10
        `, [monthStart]);
        return rows;
    }

    async getShopRevenueRankingMonth(monthStart) {
        const [rows] = await db.execute(`
            SELECT s.shop_id, s.name as shop_name,
                   COALESCE(SUM(sale.total_amount), 0) as revenue,
                   ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(sale.total_amount), 0) DESC) as rank
            FROM shop s
            LEFT JOIN (
                SELECT shop_id, SUM((si.quantity * d.selling_price) - (si.quantity * d.cost_price)) as total_amount
                FROM sale s
                JOIN sale_item si ON s.sale_id = si.sale_id
                JOIN drug d ON si.drug_id = d.drug_id
                WHERE DATE(s.date) >= ?
                GROUP BY shop_id
            ) sale ON s.shop_id = sale.shop_id
            GROUP BY s.shop_id, s.name
            ORDER BY revenue DESC
        `, [monthStart]);
        return rows[0] || { rank: 1, revenue: 0 };
    }

    async getMonthlyAwards(monthStart) {
        const [employeeAward] = await db.execute(`
            SELECT p.name, COUNT(s.sale_id) as sales_count,
                   SUM((si.quantity * d.selling_price) - (si.quantity * d.cost_price)) as total_profit
            FROM sale s
            JOIN pharmacist p ON s.pharmacist_id = p.pharmacist_id
            JOIN sale_item si ON s.sale_id = si.sale_id
            JOIN drug d ON si.drug_id = d.drug_id
            WHERE DATE(s.date) >= ?
            GROUP BY p.pharmacist_id, p.name
            ORDER BY sales_count DESC
            LIMIT 1
        `, [monthStart]);

        return {
            employee_of_month: employeeAward[0] || null
        };
    }

    async getMonthlyProfit(monthStart) {
        const [rows] = await db.execute(`
            SELECT 
                COALESCE(SUM(si.quantity * d.selling_price), 0) as revenue,
                COALESCE(SUM(si.quantity * d.cost_price), 0) as cost,
                COALESCE(SUM(si.quantity * d.selling_price) - SUM(si.quantity * d.cost_price), 0) as profit
            FROM sale s
            JOIN sale_item si ON s.sale_id = si.sale_id
            JOIN drug d ON si.drug_id = d.drug_id
            WHERE DATE(s.date) >= ?
        `, [monthStart]);

        // Get previous month for comparison
        const prevMonthStart = new Date(monthStart);
        prevMonthStart.setMonth(prevMonthStart.getMonth() - 1);

        const [prevRows] = await db.execute(`
            SELECT 
                COALESCE(SUM(si.quantity * d.selling_price) - SUM(si.quantity * d.cost_price), 0) as profit
            FROM sale s
            JOIN sale_item si ON s.sale_id = si.sale_id
            JOIN drug d ON si.drug_id = d.drug_id
            WHERE DATE(s.date) >= ? AND DATE(s.date) < ?
        `, [prevMonthStart.toISOString().split('T')[0], monthStart]);

        const currentProfit = rows[0]?.profit || 0;
        const previousProfit = prevRows[0]?.profit || 0;
        const growth = previousProfit > 0 ? ((currentProfit - previousProfit) / previousProfit) * 100 : 0;

        return {
            ...rows[0],
            growth: Math.round(growth * 100) / 100
        };
    }

    // ===============================
    // Utility Methods
    // ===============================

    getWeekStart() {
        const now = new Date();
        const dayOfWeek = now.getDay();
        const diff = now.getDate() - dayOfWeek;
        const weekStart = new Date(now.setDate(diff));
        return weekStart.toISOString().split('T')[0];
    }

    getMonthStart() {
        const now = new Date();
        return new Date(now.getFullYear(), now.getMonth(), 1).toISOString().split('T')[0];
    }

    async storeNotifications(notifications, type) {
        try {
            for (const notification of notifications) {
                await db.execute(`
                    INSERT INTO notifications (title, message, type, data, notification_type, created_at)
                    VALUES (?, ?, ?, ?, ?, NOW())
                `, [
                    notification.title,
                    notification.message,
                    notification.type,
                    JSON.stringify(notification.data),
                    type
                ]);
            }
        } catch (error) {
            console.error('Error storing notifications:', error);
        }
    }

    // ===============================
    // Manual Notification Triggers
    // ===============================

    async sendCustomNotification(title, message, type = 'info', data = null) {
        const notification = {
            id: `custom_${Date.now()}`,
            title,
            message,
            type,
            data,
            timestamp: new Date().toISOString()
        };

        socketManager.broadcast('custom_notification', notification);

        // Store in database
        await db.execute(`
            INSERT INTO notifications (title, message, type, data, notification_type, created_at)
            VALUES (?, ?, ?, ?, 'custom', NOW())
        `, [title, message, type, JSON.stringify(data)]);

        return notification;
    }
}

// Create singleton instance
const notificationService = new NotificationService();

// ===============================
// API Endpoints
// ===============================

const sendCustomNotification = asyncHandler(async (req, res) => {
    const { title, message, type = 'info', data = null } = req.body;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    if (!title || !message) {
        throw new ApiError(400, "Title and message are required");
    }

    const notification = await notificationService.sendCustomNotification(title, message, type, data);

    return res.status(200).json(
        new ApiResponse(200, notification, "Custom notification sent successfully")
    );
});

const triggerDailyNotifications = asyncHandler(async (req, res) => {
    // Manual trigger for testing
    await notificationService.sendDailyNotifications();

    return res.status(200).json(
        new ApiResponse(200, {}, "Daily notifications triggered successfully")
    );
});

const triggerWeeklyNotifications = asyncHandler(async (req, res) => {
    // Manual trigger for testing
    await notificationService.sendWeeklyNotifications();

    return res.status(200).json(
        new ApiResponse(200, {}, "Weekly notifications triggered successfully")
    );
});

const triggerMonthlyNotifications = asyncHandler(async (req, res) => {
    // Manual trigger for testing
    await notificationService.sendMonthlyNotifications();

    return res.status(200).json(
        new ApiResponse(200, {}, "Monthly notifications triggered successfully")
    );
});
const  getNotifications = asyncHandler(async (req, res) => {
        const pharmacist_id = req.pharmacist.pharmacist_id;

        // This query fetches all notifications and joins with the reads table
        // to determine if the current user has read it.
        const [notifications] = await db.execute(`
        SELECT 
            n.notification_id,
            n.title,
            n.message,
            n.type,
            n.data,
            n.notification_type,
            n.created_at,
            CASE WHEN nr.pharmacist_id IS NOT NULL THEN TRUE ELSE FALSE END as is_read
        FROM notifications n
        LEFT JOIN notification_reads nr ON n.notification_id = nr.notification_id AND nr.pharmacist_id = ?
        ORDER BY n.created_at DESC
        LIMIT 50 
    `, [pharmacist_id]);

        return res.status(200).json(
            new ApiResponse(200, notifications, "Notifications retrieved successfully")
        );
    });
export {
    notificationService,
    sendCustomNotification,
    triggerDailyNotifications,
    triggerWeeklyNotifications,
    triggerMonthlyNotifications,
    getNotifications
};