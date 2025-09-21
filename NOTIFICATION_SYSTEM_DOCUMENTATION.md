# 🔔 Rx Guardian Notification System

## Overview
A comprehensive notification system using cron jobs and Socket.IO that provides real-time insights and analytics to pharmacists and managers.

## Features Implemented

### 📊 **Daily Notifications (6 PM)**
- **Top Selling Drug Today** - Shows the most sold drug with quantity and revenue
- **Shop Performance Ranking** - Ranks shops based on daily revenue
- **Best Employee Today** - Highlights the top-performing employee
- **Daily Profit Summary** - Shows net profit, revenue, and costs
- **Most Interactive Employee** - Tracks employee interaction scores

### 📅 **Weekly Notifications (Sunday 7 PM)**
- **Top Selling Drugs This Week** - Top 5 performing drugs
- **Weekly Shop Performance** - Shop ranking based on weekly revenue
- **Employee Performance Ranking** - Top 10 employees by sales count
- **Weekly Profit Summary** - Total profit with growth percentage vs last week

### 📆 **Monthly Notifications (1st of month 8 PM)**
- **Top Selling Drugs This Month** - Top 10 performing drugs
- **Monthly Shop Performance** - Shop ranking based on monthly revenue
- **Monthly Awards** - Employee of the month recognition
- **Monthly Profit Summary** - Total profit with growth vs previous month

## Database Schema

### Notifications Table
```sql
CREATE TABLE notifications (
    notification_id INT PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type ENUM('info', 'success', 'warning', 'error') DEFAULT 'info',
    data JSON NULL,
    notification_type ENUM('daily', 'weekly', 'monthly', 'custom', 'system') DEFAULT 'custom',
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);
```

### Notification Reads Table
```sql
CREATE TABLE notification_reads (
    read_id INT PRIMARY KEY AUTO_INCREMENT,
    notification_id INT NOT NULL,
    pharmacist_id INT NOT NULL,
    read_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE KEY unique_notification_read (notification_id, pharmacist_id),
    FOREIGN KEY (notification_id) REFERENCES notifications(notification_id) ON DELETE CASCADE,
    FOREIGN KEY (pharmacist_id) REFERENCES pharmacist(pharmacist_id) ON DELETE CASCADE
);
```

### Notification Preferences Table
```sql
CREATE TABLE notification_preferences (
    preference_id INT PRIMARY KEY AUTO_INCREMENT,
    pharmacist_id INT NOT NULL,
    daily_notifications BOOLEAN DEFAULT TRUE,
    weekly_notifications BOOLEAN DEFAULT TRUE,
    monthly_notifications BOOLEAN DEFAULT TRUE,
    custom_notifications BOOLEAN DEFAULT TRUE,
    system_notifications BOOLEAN DEFAULT TRUE,
    email_notifications BOOLEAN DEFAULT FALSE,
    push_notifications BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY unique_user_preferences (pharmacist_id),
    FOREIGN KEY (pharmacist_id) REFERENCES pharmacist(pharmacist_id) ON DELETE CASCADE
);
```

## API Endpoints

### Send Custom Notification
```http
POST /notifications/send
Content-Type: application/json
Authorization: Bearer <token>

{
  "title": "Custom Notification",
  "message": "This is a custom notification message",
  "type": "info",
  "data": {
    "custom_field": "value"
  }
}
```

### Trigger Daily Notifications (Testing)
```http
POST /notifications/trigger/daily
Authorization: Bearer <token>
```

## Socket.IO Events

### Client → Server Events

#### Mark Notification as Read
```javascript
socket.emit('mark_notification_read', {
  notification_id: 123
});
```

#### Update Notification Preferences
```javascript
socket.emit('update_notification_preferences', {
  preferences: {
    daily_notifications: true,
    weekly_notifications: true,
    monthly_notifications: false,
    custom_notifications: true,
    system_notifications: true,
    email_notifications: false,
    push_notifications: true
  }
});
```

### Server → Client Events

#### Daily Notifications
```javascript
socket.on('daily_notifications', (data) => {
  console.log('Daily notifications:', data);
  // data.type = 'daily_summary'
  // data.data = array of notifications
  // data.timestamp = ISO timestamp
});
```

#### Custom Notifications
```javascript
socket.on('custom_notification', (notification) => {
  console.log('Custom notification:', notification);
  // notification.id, title, message, type, data, timestamp
});
```

#### Notification Preferences Updated
```javascript
socket.on('notification_preferences_updated', (data) => {
  console.log('Preferences updated:', data.success);
});
```

## Notification Types

### Daily Notifications
1. **🔥 Top Selling Drug Today**
   - Shows drug name, quantity sold, and revenue
   - Type: `success`

2. **🏆 Shop Performance Today**
   - Shows shop ranking and revenue
   - Type: `info`

3. **⭐ Top Performer Today**
   - Shows best employee name and sales count
   - Type: `success`

4. **💰 Daily Profit Summary**
   - Shows net profit, revenue, and costs
   - Type: `success` (if profit > 0) or `warning`

5. **💬 Most Interactive Today**
   - Shows most interactive employee and score
   - Type: `info`

### Weekly Notifications
1. **🔥 Top Selling Drugs This Week**
   - Top 5 drugs with quantities and revenue
   - Type: `success`

2. **🏆 Weekly Shop Performance**
   - Shop ranking and revenue
   - Type: `info`

3. **⭐ Employee Performance This Week**
   - Top 10 employees with sales count and rank
   - Type: `success`

4. **💰 Weekly Profit Summary**
   - Total profit with growth percentage
   - Type: `success` (if growth > 0) or `warning`

### Monthly Notifications
1. **🔥 Top Selling Drugs This Month**
   - Top 10 drugs with quantities and revenue
   - Type: `success`

2. **🏆 Monthly Shop Performance**
   - Shop ranking and revenue
   - Type: `info`

3. **🏅 Monthly Awards**
   - Employee of the month
   - Type: `success`

4. **💰 Monthly Profit Summary**
   - Total profit with growth percentage
   - Type: `success` (if growth > 0) or `warning`

## Cron Job Schedule

```javascript
// Daily at 6 PM
cron.schedule('0 18 * * *', () => {
  notificationService.sendDailyNotifications();
});

// Weekly on Sunday at 7 PM
cron.schedule('0 19 * * 0', () => {
  notificationService.sendWeeklyNotifications();
});

// Monthly on 1st at 8 PM
cron.schedule('0 20 1 * *', () => {
  notificationService.sendMonthlyNotifications();
});
```

## Frontend Integration

### React/Flutter Example
```javascript
// Connect to Socket.IO
const socket = io('http://localhost:3000', {
  auth: { token: 'your-jwt-token' }
});

// Listen for notifications
socket.on('daily_notifications', (data) => {
  data.data.forEach(notification => {
    showNotification(notification);
  });
});

socket.on('custom_notification', (notification) => {
  showNotification(notification);
});

// Mark notification as read
function markAsRead(notificationId) {
  socket.emit('mark_notification_read', {
    notification_id: notificationId
  });
}

// Update preferences
function updatePreferences(preferences) {
  socket.emit('update_notification_preferences', {
    preferences: preferences
  });
}
```

## Analytics Queries

### Top Selling Drug Today
```sql
SELECT d.name as drug_name, SUM(si.quantity) as total_quantity, 
       SUM(si.quantity * d.selling_price) as total_revenue
FROM sale_item si
JOIN drug d ON si.drug_id = d.drug_id
JOIN sale s ON si.sale_id = s.sale_id
WHERE DATE(s.date) = ?
GROUP BY d.drug_id, d.name
ORDER BY total_quantity DESC
LIMIT 1
```

### Shop Revenue Ranking
```sql
SELECT s.shop_id, s.name as shop_name, 
       COALESCE(SUM(sale.total_amount), 0) as revenue,
       ROW_NUMBER() OVER (ORDER BY COALESCE(SUM(sale.total_amount), 0) DESC) as rank
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
```

### Employee Performance
```sql
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
```

## Configuration

### Environment Variables
```env
# Notification settings
NOTIFICATION_DAILY_TIME=18:00
NOTIFICATION_WEEKLY_TIME=19:00
NOTIFICATION_MONTHLY_TIME=20:00
```

### Customization
You can easily customize the notification system by:
1. Modifying the cron schedule times
2. Adding new notification types
3. Customizing the analytics queries
4. Adding new notification channels (email, SMS, etc.)

## Testing

### Manual Triggers
```bash
# Trigger daily notifications
curl -X POST "http://localhost:3000/notifications/trigger/daily" \
  -H "Authorization: Bearer your-jwt-token"

# Send custom notification
curl -X POST "http://localhost:3000/notifications/send" \
  -H "Authorization: Bearer your-jwt-token" \
  -H "Content-Type: application/json" \
  -d '{
    "title": "Test Notification",
    "message": "This is a test notification",
    "type": "info"
  }'
```

## Benefits

1. **Real-time Insights** - Immediate feedback on performance
2. **Automated Analytics** - No manual reporting needed
3. **Employee Motivation** - Recognition and rankings
4. **Business Intelligence** - Data-driven decisions
5. **Customizable** - Flexible notification preferences
6. **Scalable** - Works with multiple shops and employees

The notification system provides comprehensive analytics and insights to help pharmacists and managers make informed decisions and stay motivated! 🚀
