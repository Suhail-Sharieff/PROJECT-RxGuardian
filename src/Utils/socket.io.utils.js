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
                    console.log('❌ [Middleware] No token provided');
                    return next(new Error('Authentication error: No token provided'));
                }

                const decoded = jwt.verify(token, process.env.ACCESS_TOKEN_SECRET);
                const [rows] = await db.execute(
                    "SELECT pharmacist_id, name, email FROM pharmacist WHERE pharmacist_id = ?",
                    [decoded.pharmacist_id]
                );

                if (rows.length === 0) {
                    console.log('❌ [Middleware] User not found for ID:', decoded.pharmacist_id);
                    return next(new Error('Authentication error: User not found'));
                }

                socket.pharmacist = rows[0];
                console.log(`🔑 [Middleware] Authenticated: ${socket.pharmacist.name} (ID: ${socket.pharmacist.pharmacist_id})`);
                next();
            } catch (err) {
                console.error('❌ [Middleware] Auth Error:', err.message);
                next(new Error('Authentication error: Invalid token'));
            }
        });
    }

    setupEventHandlers() {
        this.io.on('connection', (socket) => {
            console.log(`🔌 [Connection] User connected: ${socket.pharmacist.name} (${socket.id})`);
            this.handleConnection(socket);
            this.setupSocketEvents(socket);
        });
    }

    async handleConnection(socket) {
        const { pharmacist_id } = socket.pharmacist;
        await this.updateOnlineStatus(pharmacist_id, socket.id, 'online');
        await this.joinUserRooms(socket, pharmacist_id);
        this.broadcastUserStatus(pharmacist_id, 'online');
    }

    async joinUserRooms(socket, pharmacist_id) {
        try {
            console.log(`📂 [JoinRooms] Fetching rooms for User ${pharmacist_id}...`);
            const [rooms] = await db.execute(
                "SELECT room_id FROM chat_room_members WHERE pharmacist_id = ? AND is_active = TRUE",
                [pharmacist_id]
            );
            
            if (rooms.length > 0) {
                console.log(`📂 [JoinRooms] Joining ${rooms.length} rooms:`, rooms.map(r => r.room_id));
                rooms.forEach(room => socket.join(`room_${room.room_id}`));
            } else {
                console.log(`⚠️ [JoinRooms] User ${pharmacist_id} has NO active rooms to join.`);
            }
        } catch (error) {
            console.error('❌ [JoinRooms] Error:', error);
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
            console.error('❌ [Status] Error updating online status:', error);
        }
    }

    broadcastUserStatus(pharmacist_id, status) {
        this.io.emit('user_status_changed', {
            pharmacist_id,
            status
        });
    }

    broadcast(event, data) {
        if (this.io) {
            this.io.emit(event, data);
        } else {
            console.warn('⚠️ [Broadcast] Socket.IO not initialized. Cannot broadcast:', event);
        }
    }

    setupSocketEvents(socket) {
        const { pharmacist_id, name } = socket.pharmacist;

        // --- ROOM MANAGEMENT ---
        socket.on('join_room', async ({ room_id }) => {
            console.log(`📥 [Event: join_room] User ${name} joining room_${room_id}`);
            socket.join(`room_${room_id}`);
            await this.updateOnlineStatus(pharmacist_id, socket.id, 'online', room_id);
            socket.to(`room_${room_id}`).emit('user_joined_room', { pharmacist_id, name, room_id });
        });

        socket.on('leave_room', async ({ room_id }) => {
            console.log(`📥 [Event: leave_room] User ${name} leaving room_${room_id}`);
            socket.leave(`room_${room_id}`);
            await this.updateOnlineStatus(pharmacist_id, socket.id, 'online', null);
            socket.to(`room_${room_id}`).emit('user_left_room', { pharmacist_id, name, room_id });
        });

        // --- MESSAGING ---
        socket.on('send_message', async (data) => {
            console.log(`⬇️ [Event: send_message] Received payload:`, data);
            
            const { room_id, message_text, message_type = 'text', reply_to_message_id = null } = data;
            
            try {
                // 1. Check Membership
                console.log(`🔍 [send_message] Checking membership for User ${pharmacist_id} in Room ${room_id}...`);
                
                const [memberRows] = await db.execute(
                    `SELECT is_muted FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ?`,
                    [room_id, pharmacist_id]
                );

                console.log(`🔍 [send_message] Membership check result:`, memberRows);

                if (memberRows.length === 0) {
                    console.error(`❌ [send_message] FAILED: User ${pharmacist_id} is NOT a member of room ${room_id}`);
                    return socket.emit('error', { message: 'You are not a member of this room.' });
                }

                const member = memberRows[0];
                if (member.is_muted) {
                    console.warn(`⛔ [send_message] BLOCKED: User ${pharmacist_id} is MUTED in room ${room_id}`);
                    return socket.emit('error', { message: 'You are muted and cannot send messages.' });
                }

                // 2. Insert Message
                console.log(`💾 [send_message] Inserting message into DB...`);
                const [result] = await db.execute(
                    `INSERT INTO chat_messages (room_id, sender_id, message_text, message_type, reply_to_message_id) 
                    VALUES (?, ?, ?, ?, ?)`,
                    [room_id, pharmacist_id, message_text, message_type, reply_to_message_id]
                );
                
                const message_id = result.insertId;
                console.log(`✅ [send_message] Message inserted. ID: ${message_id}`);

                // 3. Fetch Full Message
                const [messageRows] = await db.execute(
                    `SELECT cm.*, p.name as sender_name 
                    FROM chat_messages cm JOIN pharmacist p ON cm.sender_id = p.pharmacist_id 
                    WHERE cm.message_id = ?`,
                    [message_id]
                );

                // 4. Broadcast
                console.log(`📢 [send_message] Broadcasting 'new_message' to room_${room_id}`);
                this.io.to(`room_${room_id}`).emit('new_message', messageRows[0]);
                
            } catch (error) {
                console.error("❌ [send_message] EXCEPTION:", error);
                socket.emit('error', { message: 'Could not send message.' });
            }
        });

        socket.on('mark_room_as_read', async (data) => {
            const { room_id } = data;
            console.log(`📥 [Event: mark_room_as_read] User ${pharmacist_id} -> Room ${room_id}`);
            
            if (!room_id) return;

            try {
                await db.execute(
                    `UPDATE chat_room_members 
                     SET last_read_timestamp = CURRENT_TIMESTAMP 
                     WHERE room_id = ? AND pharmacist_id = ?`,
                    [room_id, pharmacist_id]
                );
            } catch (error) {
                console.error("❌ [mark_room_as_read] Error:", error);
            }
        });

        // --- TYPING INDICATORS ---
        socket.on('start_typing', ({ room_id }) => {
            // console.log(`⌨️ [Typing] ${name} started in room_${room_id}`); // Commented out to avoid log spam
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
        socket.on('add_reaction', async ({ message_id, emoji, room_id }) => {
            console.log(`📥 [Event: add_reaction] Msg: ${message_id}, Emoji: ${emoji}`);
            try {
                await db.execute("DELETE FROM message_reactions WHERE message_id = ? AND pharmacist_id = ?", [message_id, pharmacist_id]);
                await db.execute("INSERT INTO message_reactions (message_id, pharmacist_id, emoji) VALUES (?, ?, ?)", [message_id, pharmacist_id, emoji]);

                this.io.to(`room_${room_id}`).emit('reaction_added', { message_id, pharmacist_id, name, emoji });
            } catch (error) {
                console.error("❌ [add_reaction] Error:", error);
                socket.emit('error', { message: 'Failed to add reaction' });
            }
        });

        socket.on('remove_reaction', async ({ message_id, room_id }) => {
            console.log(`📥 [Event: remove_reaction] Msg: ${message_id}`);
            try {
                await db.execute("DELETE FROM message_reactions WHERE message_id = ? AND pharmacist_id = ?", [message_id, pharmacist_id]);
                this.io.to(`room_${room_id}`).emit('reaction_removed', { message_id, pharmacist_id, name });
            } catch (error) {
                console.error("❌ [remove_reaction] Error:", error);
                socket.emit('error', { message: 'Failed to remove reaction' });
            }
        });

        // --- READ STATUS ---
        socket.on('mark_message_read', async ({ message_id, room_id }) => {
            // console.log(`👁️ [Event: mark_message_read] Msg: ${message_id}`);
            try {
                await db.execute(
                    `INSERT INTO message_read_status (message_id, pharmacist_id) VALUES (?, ?) 
                     ON DUPLICATE KEY UPDATE read_at = CURRENT_TIMESTAMP`,
                    [message_id, pharmacist_id]
                );

                this.io.to(`room_${room_id}`).emit('message_read', { message_id, pharmacist_id, name });
            } catch (error) {
                console.error('❌ [mark_message_read] Error:', error);
            }
        });

        // --- STATUS UPDATES ---
        socket.on('update_status', async ({ status, current_room_id }) => {
            // console.log(`🔄 [Event: update_status] ${status}`);
            await this.updateOnlineStatus(pharmacist_id, socket.id, status, current_room_id);
            this.broadcastUserStatus(pharmacist_id, status);
        });

        // --- NOTIFICATIONS ---
        socket.on('mark_notification_read', async (data) => {
            console.log(`📥 [Event: mark_notification_read]`, data);
            const { notification_id } = data;
            
            if (!notification_id) return socket.emit('error', { message: 'Notification ID is required' });

            const notificationIdInt = parseInt(notification_id, 10);
            if (isNaN(notificationIdInt) || notificationIdInt <= 0) return socket.emit('error', { message: 'Invalid notification ID' });

            try {
                const [notificationRows] = await db.execute(
                    'SELECT notification_id FROM notifications WHERE notification_id = ?',
                    [notificationIdInt]
                );

                if (notificationRows.length === 0) return socket.emit('error', { message: 'Notification not found' });

                await db.execute(
                    `INSERT INTO notification_reads (notification_id, pharmacist_id) 
                     VALUES (?, ?) 
                     ON DUPLICATE KEY UPDATE read_at = CURRENT_TIMESTAMP`,
                    [notificationIdInt, pharmacist_id]
                );
                console.log(`📧 [Notification] Marked read: ${notificationIdInt}`);
            } catch (error) {
                console.error('❌ [mark_notification_read] Error:', error);
                socket.emit('error', { message: 'Failed to mark notification as read' });
            }
        });

        socket.on('update_notification_preferences', async (data) => {
            console.log(`📥 [Event: update_notification_preferences]`);
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
            } catch (error) {
                console.error('❌ [update_notification_preferences] Error:', error);
                socket.emit('error', { message: 'Failed to update notification preferences' });
            }
        });

        // --- DISCONNECTION ---
        socket.on('disconnect', async () => {
            console.log(`🔌 [Disconnect] User disconnected: ${name} (${socket.id})`);
            await this.updateOnlineStatus(pharmacist_id, socket.id, 'offline');
            this.broadcastUserStatus(pharmacist_id, 'offline');
        });
    }
}

const socketManager = new SocketManager();
export { socketManager };