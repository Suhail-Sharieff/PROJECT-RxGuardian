import { Server } from "socket.io";
import jwt from "jsonwebtoken";
import { db } from "./sql_connection.utils.js";
import { redis } from "./redis.connection.js";

class SocketManager {
    constructor() {
        this.io = null;
        this.connectedUsers = new Map(); // Map<socketId, {pharmacist_id, name, email}>
        this.userSockets = new Map(); // Map<pharmacist_id, Set<socketId>>
        this.typingUsers = new Map(); // Map<roomId, Set<pharmacist_id>>
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
        // Authentication middleware
        this.io.use(async (socket, next) => {
            try {
                const token = socket.handshake.auth.token || socket.handshake.headers.authorization?.replace('Bearer ', '');

                if (!token) {
                    return next(new Error('Authentication error: No token provided'));
                }

                const decoded = jwt.verify(token, process.env.ACCESS_TOKEN_SECRET);

                // Get pharmacist details
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
            console.log(`🔌 User connected: ${socket.pharmacist.name} (${socket.id})`);

            this.handleConnection(socket);
            this.setupSocketEvents(socket);
        });
    }

    handleConnection(socket) {
        const { pharmacist_id, name, email } = socket.pharmacist;

        // Store user connection
        this.connectedUsers.set(socket.id, { pharmacist_id, name, email });

        // Track user sockets
        if (!this.userSockets.has(pharmacist_id)) {
            this.userSockets.set(pharmacist_id, new Set());
        }
        this.userSockets.get(pharmacist_id).add(socket.id);

        // Update online status in database
        this.updateOnlineStatus(pharmacist_id, socket.id, 'online');

        // Join user to their rooms
        this.joinUserRooms(socket, pharmacist_id);

        // Notify others about user coming online
        this.broadcastUserStatus(pharmacist_id, 'online');
    }

    async joinUserRooms(socket, pharmacist_id) {
        try {
            // Get all rooms the user is a member of
            const [rooms] = await db.execute(
                "SELECT room_id FROM chat_room_members WHERE pharmacist_id = ? AND is_active = TRUE",
                [pharmacist_id]
            );

            if (rooms.length > 0) {
                rooms.forEach(room => {
                    socket.join(`room_${room.room_id}`);
                });
                console.log(`📱 User joined ${rooms.length} rooms`);
            } else {
                // If user is not a member of any rooms, add them to the general room
                try {
                    await db.execute(
                        "INSERT INTO chat_room_members (room_id, pharmacist_id) VALUES (1, ?)",
                        [pharmacist_id]
                    );
                    socket.join('room_1');
                    console.log(`📱 User added to general room (room 1)`);
                } catch (insertError) {
                    // User might already be in general room, just join it
                    socket.join('room_1');
                    console.log(`📱 User joined general room (room 1)`);
                }
            }
        } catch (error) {
            console.error('Error joining user rooms:', error);
            // Fallback: join general room
            socket.join('room_1');
            console.log(`📱 User joined general room (fallback)`);
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

    setupSocketEvents(socket) {
        const { pharmacist_id, name } = socket.pharmacist;

        // Handle joining a room
        socket.on('join_room', async (data) => {
            const { room_id } = data;

            try {
                // Check if user is a member of the room
                const [memberCheck] = await db.execute(
                    "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_active = TRUE",
                    [room_id, pharmacist_id]
                );

                if (memberCheck.length === 0) {
                    socket.emit('error', { message: 'You are not a member of this room' });
                    return;
                }

                socket.join(`room_${room_id}`);

                // Update current room in database
                await this.updateOnlineStatus(pharmacist_id, socket.id, 'online', room_id);

                // Notify room members
                socket.to(`room_${room_id}`).emit('user_joined_room', {
                    pharmacist_id,
                    name,
                    room_id
                });

                console.log(`📱 ${name} joined room ${room_id}`);
            } catch (error) {
                console.error('Error joining room:', error);
                socket.emit('error', { message: 'Failed to join room' });
            }
        });

        // Handle leaving a room
        socket.on('leave_room', async (data) => {
            const { room_id } = data;

            socket.leave(`room_${room_id}`);

            // Update current room in database
            await this.updateOnlineStatus(pharmacist_id, socket.id, 'online', null);

            // Notify room members
            socket.to(`room_${room_id}`).emit('user_left_room', {
                pharmacist_id,
                name,
                room_id
            });

            console.log(`📱 ${name} left room ${room_id}`);
        });

        // Handle sending messages
        // On your Node.js server, inside your Socket.IO connection logic

        socket.on('send_message', async (data) => {
            try {
                // 1. Get the sender's info from the authenticated socket
                const senderId = socket.pharmacist.pharmacist_id;
                const senderName = socket.pharmacist.name;

                // 2. Save the message to the database (your existing logic)
                const savedMessage = await saveMessageToDatabase(
                    data.room_id,
                    senderId,
                    data.message_text
                );

                // 3. Create the payload to broadcast WITH the sender's name
                const payload = {
                    message_id: savedMessage.insertId,
                    room_id: data.room_id,
                    sender_id: senderId,
                    sender_name: senderName, // The crucial addition!
                    message_text: data.message_text,
                    created_at: new Date().toISOString()
                };

                // 4. Broadcast the ENRICHED payload to everyone in the room
                io.to(data.room_id).emit('new_message', payload);

            } catch (error) {
                console.error("Error in send_message:", error);
                // Optionally emit an error back to the sender
                socket.emit('send_message_error', { message: 'Could not send message.' });
            }
        });

        // Handle typing indicators
        // On your Node.js server

        socket.on('start_typing', (data) => {
            // Get the sender's name from the authenticated socket
            const senderName = socket.pharmacist.name;

            // Broadcast the name along with the typing status
            // socket.broadcast sends to everyone in the room EXCEPT the sender
            socket.broadcast.to(data.room_id).emit('user_typing', {
                name: senderName,
                is_typing: true,
                room_id: data.room_id
            });
        });

        socket.on('stop_typing', (data) => {
            const senderName = socket.pharmacist.name;

            socket.broadcast.to(data.room_id).emit('user_typing', {
                name: senderName,
                is_typing: false,
                room_id: data.room_id
            });
        });

        socket.on('stop_typing', (data) => {
            const { room_id } = data;

            // Remove from typing users
            if (this.typingUsers.has(room_id)) {
                this.typingUsers.get(room_id).delete(pharmacist_id);
            }

            // Broadcast to room (excluding sender)
            socket.to(`room_${room_id}`).emit('user_typing', {
                pharmacist_id,
                name,
                room_id,
                is_typing: false
            });

            // Update database
            this.updateTypingStatus(room_id, pharmacist_id, false);
        });

        // Handle message reactions
        socket.on('add_reaction', async (data) => {
            const { message_id, emoji, room_id } = data;

            try {
                // Remove existing reaction if any
                await db.execute(
                    "DELETE FROM message_reactions WHERE message_id = ? AND pharmacist_id = ?",
                    [message_id, pharmacist_id]
                );

                // Add new reaction
                await db.execute(
                    "INSERT INTO message_reactions (message_id, pharmacist_id, emoji) VALUES (?, ?, ?)",
                    [message_id, pharmacist_id, emoji]
                );

                // Broadcast reaction to room
                this.io.to(`room_${room_id}`).emit('reaction_added', {
                    message_id,
                    pharmacist_id,
                    name,
                    emoji
                });

                console.log(`😀 Reaction added by ${name}`);
            } catch (error) {
                console.error('Error adding reaction:', error);
                socket.emit('error', { message: 'Failed to add reaction' });
            }
        });

        socket.on('remove_reaction', async (data) => {
            const { message_id, room_id } = data;

            try {
                await db.execute(
                    "DELETE FROM message_reactions WHERE message_id = ? AND pharmacist_id = ?",
                    [message_id, pharmacist_id]
                );

                // Broadcast reaction removal to room
                this.io.to(`room_${room_id}`).emit('reaction_removed', {
                    message_id,
                    pharmacist_id,
                    name
                });

                console.log(`😀 Reaction removed by ${name}`);
            } catch (error) {
                console.error('Error removing reaction:', error);
                socket.emit('error', { message: 'Failed to remove reaction' });
            }
        });

        // Handle message read status
        socket.on('mark_message_read', async (data) => {
            const { message_id, room_id } = data;

            try {
                await db.execute(
                    `INSERT INTO message_read_status (message_id, pharmacist_id) 
                     VALUES (?, ?) 
                     ON DUPLICATE KEY UPDATE read_at = CURRENT_TIMESTAMP`,
                    [message_id, pharmacist_id]
                );

                // Broadcast read status to room
                this.io.to(`room_${room_id}`).emit('message_read', {
                    message_id,
                    pharmacist_id,
                    name
                });

                console.log(`👁️ Message marked as read by ${name}`);
            } catch (error) {
                console.error('Error marking message as read:', error);
            }
        });

        // Handle status updates
        socket.on('update_status', async (data) => {
            const { status, current_room_id } = data;

            try {
                await this.updateOnlineStatus(pharmacist_id, socket.id, status, current_room_id);

                // Broadcast status update
                this.broadcastUserStatus(pharmacist_id, status);

                console.log(`📊 Status updated for ${name}: ${status}`);
            } catch (error) {
                console.error('Error updating status:', error);
                socket.emit('error', { message: 'Failed to update status' });
            }
        });

        // Handle disconnection
        socket.on('disconnect', () => {
            console.log(`🔌 User disconnected: ${name} (${socket.id})`);

            this.handleDisconnection(socket);
        });
    }

    async updateTypingStatus(room_id, pharmacist_id, is_typing) {
        try {
            if (is_typing) {
                await db.execute(
                    `INSERT INTO typing_indicators (room_id, pharmacist_id, is_typing) 
                     VALUES (?, ?, TRUE) 
                     ON DUPLICATE KEY UPDATE 
                     is_typing = TRUE, 
                     started_typing_at = CURRENT_TIMESTAMP`,
                    [room_id, pharmacist_id]
                );
            } else {
                await db.execute(
                    "UPDATE typing_indicators SET is_typing = FALSE WHERE room_id = ? AND pharmacist_id = ?",
                    [room_id, pharmacist_id]
                );
            }
        } catch (error) {
            console.error('Error updating typing status:', error);
        }
    }

    broadcastUserStatus(pharmacist_id, status) {
        const userInfo = this.connectedUsers.get(Array.from(this.connectedUsers.keys())[0]);
        if (!userInfo) return;

        this.io.emit('user_status_changed', {
            pharmacist_id,
            name: userInfo.name,
            status
        });
    }

    handleDisconnection(socket) {
        const { pharmacist_id, name } = socket.pharmacist;

        // Remove from connected users
        this.connectedUsers.delete(socket.id);

        // Remove from user sockets
        if (this.userSockets.has(pharmacist_id)) {
            this.userSockets.get(pharmacist_id).delete(socket.id);

            // If no more sockets for this user, mark as offline
            if (this.userSockets.get(pharmacist_id).size === 0) {
                this.userSockets.delete(pharmacist_id);
                this.updateOnlineStatus(pharmacist_id, socket.id, 'offline');
                this.broadcastUserStatus(pharmacist_id, 'offline');
            }
        }

        // Clean up typing indicators
        this.typingUsers.forEach((users, roomId) => {
            if (users.has(pharmacist_id)) {
                users.delete(pharmacist_id);
                this.io.to(`room_${roomId}`).emit('user_typing', {
                    pharmacist_id,
                    name,
                    room_id: roomId,
                    is_typing: false
                });
            }
        });
    }

    // Utility methods for external use
    getOnlineUsers() {
        return Array.from(this.connectedUsers.values());
    }

    getUserSockets(pharmacist_id) {
        return this.userSockets.get(pharmacist_id) || new Set();
    }

    isUserOnline(pharmacist_id) {
        return this.userSockets.has(pharmacist_id) && this.userSockets.get(pharmacist_id).size > 0;
    }

    // Send message to specific user
    sendToUser(pharmacist_id, event, data) {
        const userSockets = this.getUserSockets(pharmacist_id);
        userSockets.forEach(socketId => {
            this.io.to(socketId).emit(event, data);
        });
    }

    // Send message to room
    sendToRoom(room_id, event, data) {
        this.io.to(`room_${room_id}`).emit(event, data);
    }

    // Broadcast to all users
    broadcast(event, data) {
        this.io.emit(event, data);
    }
}

// Create singleton instance
const socketManager = new SocketManager();

export { socketManager };
