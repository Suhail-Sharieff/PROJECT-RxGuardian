import { Server } from "socket.io";
import jwt from "jsonwebtoken";
import { db } from "./sql_connection.utils.js";

class SocketManager {
    constructor() {
        this.io = null;
    }

    initialize(server) {
        this.io = new Server(server, {
            cors: {
                origin: process.env.CORS_ORIGIN,
                methods: ["GET", "POST"],
                credentials: true
            }
        });

        this.setupMiddleware();
        this.setupEventHandlers();

        console.log("✅ Socket.IO initialized");
    }

    setupMiddleware() {
        this.io.use(async (socket, next) => {
            try {
                const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');
                if (!token) {
                    return next(new Error('Authentication error: No token provided'));
                }

                const decoded = jwt.verify(token, process.env.ACCESS_TOKEN_SECRET);
                const [rows] = await db.execute(
                    "SELECT pharmacist_id, name, email FROM pharmacist WHERE pharmacist_id = ?",
                    [decoded.pharmacist_id]
                );

                if (rows.length === 0) {
                    return next(new Error('Authentication error: User not found'));
                }

                socket.pharmacist = rows[0];
                next();
            } catch (err) {
                next(new Error('Authentication error: Invalid token'));
            }
        });
    }

    setupEventHandlers() {
        this.io.on('connection', (socket) => {
            console.log(`🔌 User connected: ${socket.pharmacist.name} SOCK_ID=(${socket.id})`);
            this.handleConnection(socket);
            this.setupSocketEvents(socket);
        });
    }

    async handleConnection(socket) {
        const { pharmacist_id } = socket.pharmacist;
        //whenver some connection is established means he is online ie viewing chat app
        await this.updateOnlineStatus(pharmacist_id, socket.id, 'online');
        await this.joinUserRooms(socket, pharmacist_id);
        this.broadcastUserStatus(pharmacist_id, 'online');
    }

    async joinUserRooms(socket, pharmacist_id) {
        try {
            const [rooms] = await db.execute(
                "SELECT room_id FROM chat_room_members WHERE pharmacist_id = ? AND is_active = TRUE",
                [pharmacist_id]
            );
            rooms.forEach(room => socket.join(`room_${room.room_id}`));
        } catch (error) {
            console.error('Error joining user rooms:', error);
        }
    }

    async updateOnlineStatus(pharmacist_id, socket_id, status, current_room_id = null) {
        try {
            await db.execute(
                `INSERT INTO online_users (pharmacist_id, socket_id, status, current_room_id) 
                 VALUES (?, ?, ?, ?) 
                 ON DUPLICATE KEY UPDATE 
                 socket_id = VALUES(socket_id), 
                 status = VALUES(status), 
                 current_room_id = VALUES(current_room_id),
                 last_seen = CURRENT_TIMESTAMP`,
                [pharmacist_id, socket_id, status, current_room_id]
            );
        } catch (error) {
            console.error('Error updating online status:', error);
        }
    }

    broadcastUserStatus(pharmacist_id, status) {
        // This can be enhanced to get user details if needed
        this.io.emit('user_status_changed', {
            pharmacist_id,
            status
        });
    }

    // Broadcast method for notifications
    broadcast(event, data) {
        if (this.io) {
            this.io.emit(event, data);
        } else {
            console.warn('Socket.IO not initialized. Cannot broadcast:', event);
        }
    }

    setupSocketEvents(socket) {
        const { pharmacist_id, name } = socket.pharmacist;

        // --- ROOM MANAGEMENT ---
        socket.on('join_room', async ({ room_id }) => {
            // FIX: Room names must be prefixed for consistency
            socket.join(`room_${room_id}`);
            await this.updateOnlineStatus(pharmacist_id, socket.id, 'online', room_id);
            socket.to(`room_${room_id}`).emit('user_joined_room', { pharmacist_id, name, room_id });
        });

        socket.on('leave_room', async ({ room_id }) => {
            // FIX: Room names must be prefixed
            socket.leave(`room_${room_id}`);
            await this.updateOnlineStatus(pharmacist_id, socket.id, 'online', null);
            socket.to(`room_${room_id}`).emit('user_left_room', { pharmacist_id, name, room_id });
        });

        // --- MESSAGING ---
        // --- MESSAGING ---
        socket.on('send_message', async (data) => {
            const { room_id, message_text, message_type = 'text', reply_to_message_id = null } = data;
            try {
                // ===================================================================
                // NEW: Check if the user is muted before processing the message
                // ===================================================================
                const [memberRows] = await db.execute(
                    `SELECT is_muted FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ?`,
                    [room_id, pharmacist_id]
                );

                // First, ensure the user is actually a member of the room.
                if (memberRows.length === 0) {
                    // Silently fail or inform the user they are not in the room.
                    return socket.emit('error', { message: 'You are not a member of this room.' });
                }

                const member = memberRows[0];
                // Now, check the mute status. The value from the DB will be 1 for true or 0 for false.
                if (member.is_muted) {
                    // If the user is muted, send a specific error back to them and stop.
                    return socket.emit('error', { message: 'You are muted and cannot send messages.' });
                }
                // ===================================================================
                // End of new logic. If the code reaches here, the user is not muted.
                // ===================================================================

                // Original logic: If not muted, proceed to insert and broadcast the message.
                const [result] = await db.execute(
                    `INSERT INTO chat_messages (room_id, sender_id, message_text, message_type, reply_to_message_id) 
                    VALUES (?, ?, ?, ?, ?)`,
                    [room_id, pharmacist_id, message_text, message_type, reply_to_message_id]
                );
                const message_id = result.insertId;

                // Fetch the full message to broadcast, ensuring consistency with GET /messages
                const [messageRows] = await db.execute(
                    `SELECT cm.*, p.name as sender_name 
                    FROM chat_messages cm JOIN pharmacist p ON cm.sender_id = p.pharmacist_id 
                    WHERE cm.message_id = ?`,
                    [message_id]
                );

                // Broadcast to the correctly prefixed room
                this.io.to(`room_${room_id}`).emit('new_message', messageRows[0]);
            } catch (error) {
                console.error("Error in send_message:", error);
                socket.emit('error', { message: 'Could not send message.' });
            }
        });
        // In your main socket connection file
        socket.on('mark_room_as_read', async (data) => {
            const { room_id } = data;
            // Get the authenticated user's ID from the socket object
            const pharmacist_id = socket.pharmacist.pharmacist_id;

            if (!room_id || !pharmacist_id) {
                console.error("mark_room_as_read failed: missing room_id or pharmacist_id");
                return;
            }

            try {
                // Update the timestamp to the current time
                await db.execute(
                    `UPDATE chat_room_members 
             SET last_read_timestamp = CURRENT_TIMESTAMP 
             WHERE room_id = ? AND pharmacist_id = ?`,
                    [room_id, pharmacist_id]
                );
                console.log(`User ${pharmacist_id} marked room ${room_id} as read.`);
            } catch (error) {
                console.error("Failed to mark room as read:", error);
            }
        });
        // --- TYPING INDICATORS ---
        // FIX: Consolidated duplicated handlers into one clean implementation.
        socket.on('start_typing', ({ room_id }) => {
            socket.broadcast.to(`room_${room_id}`).emit('user_typing', {
                name,
                is_typing: true,
                room_id
            });
        });

        socket.on('stop_typing', ({ room_id }) => {
            socket.broadcast.to(`room_${room_id}`).emit('user_typing', {
                name,
                is_typing: false,
                room_id
            });
        });

        // --- REACTIONS ---
        // NEW: Fully implemented reaction events.
        socket.on('add_reaction', async ({ message_id, emoji, room_id }) => {
            try {
                await db.execute("DELETE FROM message_reactions WHERE message_id = ? AND pharmacist_id = ?", [message_id, pharmacist_id]);
                await db.execute("INSERT INTO message_reactions (message_id, pharmacist_id, emoji) VALUES (?, ?, ?)", [message_id, pharmacist_id, emoji]);

                this.io.to(`room_${room_id}`).emit('reaction_added', { message_id, pharmacist_id, name, emoji });
            } catch (error) {
                socket.emit('error', { message: 'Failed to add reaction' });
            }
        });

        socket.on('remove_reaction', async ({ message_id, room_id }) => {
            try {
                await db.execute("DELETE FROM message_reactions WHERE message_id = ? AND pharmacist_id = ?", [message_id, pharmacist_id]);

                this.io.to(`room_${room_id}`).emit('reaction_removed', { message_id, pharmacist_id, name });
            } catch (error) {
                socket.emit('error', { message: 'Failed to remove reaction' });
            }
        });

        // --- READ STATUS ---
        // NEW: Implemented message read event.
        socket.on('mark_message_read', async ({ message_id, room_id }) => {
            try {
                await db.execute(
                    `INSERT INTO message_read_status (message_id, pharmacist_id) VALUES (?, ?) 
                     ON DUPLICATE KEY UPDATE read_at = CURRENT_TIMESTAMP`,
                    [message_id, pharmacist_id]
                );

                this.io.to(`room_${room_id}`).emit('message_read', { message_id, pharmacist_id, name });
            } catch (error) {
                console.error('Error marking message as read:', error);
            }
        });

        // --- STATUS UPDATES ---
        socket.on('update_status', async ({ status, current_room_id }) => {
            await this.updateOnlineStatus(pharmacist_id, socket.id, status, current_room_id);
            this.broadcastUserStatus(pharmacist_id, status);
        });

        // --- NOTIFICATION EVENTS ---
        socket.on('mark_notification_read', async (data) => {
            const { notification_id } = data;
            
            // Validate notification_id
            if (!notification_id) {
                console.error('❌ No notification_id provided');
                return socket.emit('error', { message: 'Notification ID is required' });
            }

            // Convert to integer and validate
            const notificationIdInt = parseInt(notification_id, 10);
            if (isNaN(notificationIdInt) || notificationIdInt <= 0) {
                console.error('❌ Invalid notification_id:', notification_id);
                return socket.emit('error', { message: 'Invalid notification ID' });
            }

            // Check if notification exists
            try {
                const [notificationRows] = await db.execute(
                    'SELECT notification_id FROM notifications WHERE notification_id = ?',
                    [notificationIdInt]
                );

                if (notificationRows.length === 0) {
                    console.error('❌ Notification not found:', notificationIdInt);
                    return socket.emit('error', { message: 'Notification not found' });
                }

                await db.execute(
                    `INSERT INTO notification_reads (notification_id, pharmacist_id) 
                     VALUES (?, ?) 
                     ON DUPLICATE KEY UPDATE read_at = CURRENT_TIMESTAMP`,
                    [notificationIdInt, pharmacist_id]
                );

                console.log(`📧 Notification ${notificationIdInt} marked as read by ${name}`);
            } catch (error) {
                console.error('Error marking notification as read:', error);
                socket.emit('error', { message: 'Failed to mark notification as read' });
            }
        });

        // Handle notification preferences update
        socket.on('update_notification_preferences', async (data) => {
            const { preferences } = data;
            
            try {
                await db.execute(
                    `INSERT INTO notification_preferences 
                     (pharmacist_id, daily_notifications, weekly_notifications, monthly_notifications, 
                      custom_notifications, system_notifications, email_notifications, push_notifications) 
                     VALUES (?, ?, ?, ?, ?, ?, ?, ?) 
                     ON DUPLICATE KEY UPDATE 
                     daily_notifications = VALUES(daily_notifications),
                     weekly_notifications = VALUES(weekly_notifications),
                     monthly_notifications = VALUES(monthly_notifications),
                     custom_notifications = VALUES(custom_notifications),
                     system_notifications = VALUES(system_notifications),
                     email_notifications = VALUES(email_notifications),
                     push_notifications = VALUES(push_notifications),
                     updated_at = CURRENT_TIMESTAMP`,
                    [
                        pharmacist_id,
                        preferences.daily_notifications ?? true,
                        preferences.weekly_notifications ?? true,
                        preferences.monthly_notifications ?? true,
                        preferences.custom_notifications ?? true,
                        preferences.system_notifications ?? true,
                        preferences.email_notifications ?? false,
                        preferences.push_notifications ?? true
                    ]
                );

                socket.emit('notification_preferences_updated', { success: true });
                console.log(`⚙️ Notification preferences updated for ${name}`);
            } catch (error) {
                console.error('Error updating notification preferences:', error);
                socket.emit('error', { message: 'Failed to update notification preferences' });
            }
        });

        // --- DISCONNECTION ---
        socket.on('disconnect', async () => {
            console.log(`🔌 User disconnected: ${name} (${socket.id})`);
            await this.updateOnlineStatus(pharmacist_id, socket.id, 'offline');
            this.broadcastUserStatus(pharmacist_id, 'offline');
        });
    }
}

const socketManager = new SocketManager();
export { socketManager };