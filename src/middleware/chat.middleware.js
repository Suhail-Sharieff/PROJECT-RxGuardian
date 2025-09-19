import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { ApiError } from "../Utils/Api_Error.utils.js";
import { db } from "../Utils/sql_connection.utils.js";

// Middleware to check if user is a member of a chat room
export const checkRoomMembership = asyncHandler(async (req, res, next) => {
    const { room_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    if (!room_id) {
        throw new ApiError(400, "Room ID is required");
    }

    const [memberCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_active = TRUE",
        [room_id, pharmacist_id]
    );

    if (memberCheck.length === 0) {
        throw new ApiError(403, "You are not a member of this room");
    }

    req.roomMembership = memberCheck[0];
    next();
});

// Middleware to check if user is an admin of a chat room
export const checkRoomAdmin = asyncHandler(async (req, res, next) => {
    const { room_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    if (!room_id) {
        throw new ApiError(400, "Room ID is required");
    }

    const [adminCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_admin = TRUE AND is_active = TRUE",
        [room_id, pharmacist_id]
    );

    if (adminCheck.length === 0) {
        throw new ApiError(403, "You don't have admin privileges in this room");
    }

    req.roomAdmin = adminCheck[0];
    next();
});

// Middleware to check if user is not muted in a room
export const checkNotMuted = asyncHandler(async (req, res, next) => {
    const { room_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    if (!room_id) {
        throw new ApiError(400, "Room ID is required");
    }

    const [muteCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_muted = TRUE AND is_active = TRUE",
        [room_id, pharmacist_id]
    );

    if (muteCheck.length > 0) {
        throw new ApiError(403, "You are muted in this room");
    }

    next();
});

// Middleware to validate message ownership
export const checkMessageOwnership = asyncHandler(async (req, res, next) => {
    const { message_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    if (!message_id) {
        throw new ApiError(400, "Message ID is required");
    }

    const [messageCheck] = await db.execute(
        "SELECT * FROM chat_messages WHERE message_id = ? AND sender_id = ? AND is_deleted = FALSE",
        [message_id, pharmacist_id]
    );

    if (messageCheck.length === 0) {
        throw new ApiError(404, "Message not found or you don't have permission to modify it");
    }

    req.message = messageCheck[0];
    next();
});

// Middleware to check if room exists and is active
export const checkRoomExists = asyncHandler(async (req, res, next) => {
    const { room_id } = req.params;

    if (!room_id) {
        throw new ApiError(400, "Room ID is required");
    }

    const [roomCheck] = await db.execute(
        "SELECT * FROM chat_rooms WHERE room_id = ? AND is_active = TRUE",
        [room_id]
    );

    if (roomCheck.length === 0) {
        throw new ApiError(404, "Chat room not found or inactive");
    }

    req.room = roomCheck[0];
    next();
});

// Middleware to validate room type permissions
export const checkRoomTypePermission = (allowedTypes) => {
    return asyncHandler(async (req, res, next) => {
        const { room_type } = req.body;
        const pharmacist_id = req.pharmacist.pharmacist_id;

        if (!allowedTypes.includes(room_type)) {
            throw new ApiError(403, `Room type '${room_type}' is not allowed`);
        }

        // Additional checks for shop rooms
        if (room_type === 'shop') {
            const { shop_id } = req.body;
            
            if (!shop_id) {
                throw new ApiError(400, "Shop ID is required for shop rooms");
            }

            // Check if user has access to the shop
            const [shopCheck] = await db.execute(
                "SELECT * FROM employee WHERE pharmacist_id = ? AND shop_id = ?",
                [pharmacist_id, shop_id]
            );

            if (shopCheck.length === 0) {
                throw new ApiError(403, "You don't have access to this shop");
            }
        }

        next();
    });
};

// Middleware to rate limit message sending
export const rateLimitMessages = (maxMessages = 10, windowMs = 60000) => {
    const userMessageCounts = new Map();

    return asyncHandler(async (req, res, next) => {
        const pharmacist_id = req.pharmacist.pharmacist_id;
        const now = Date.now();
        const windowStart = now - windowMs;

        // Clean old entries
        for (const [userId, timestamps] of userMessageCounts.entries()) {
            const recentTimestamps = timestamps.filter(timestamp => timestamp > windowStart);
            if (recentTimestamps.length === 0) {
                userMessageCounts.delete(userId);
            } else {
                userMessageCounts.set(userId, recentTimestamps);
            }
        }

        // Check current user's message count
        const userTimestamps = userMessageCounts.get(pharmacist_id) || [];
        
        if (userTimestamps.length >= maxMessages) {
            throw new ApiError(429, `Rate limit exceeded. Maximum ${maxMessages} messages per minute allowed.`);
        }

        // Add current timestamp
        userTimestamps.push(now);
        userMessageCounts.set(pharmacist_id, userTimestamps);

        next();
    });
};

// Middleware to validate message content
export const validateMessageContent = asyncHandler(async (req, res, next) => {
    const { message_text, message_type } = req.body;

    if (!message_text || message_text.trim().length === 0) {
        throw new ApiError(400, "Message text cannot be empty");
    }

    if (message_text.length > 2000) {
        throw new ApiError(400, "Message text is too long (maximum 2000 characters)");
    }

    if (message_type && !['text', 'image', 'file', 'system'].includes(message_type)) {
        throw new ApiError(400, "Invalid message type");
    }

    // Basic profanity filter (you can enhance this)
    const profanityWords = ['spam', 'scam', 'hate']; // Add more as needed
    const lowerMessage = message_text.toLowerCase();
    
    for (const word of profanityWords) {
        if (lowerMessage.includes(word)) {
            throw new ApiError(400, "Message contains inappropriate content");
        }
    }

    next();
});

// Middleware to check if user can edit message (within time limit)
export const checkMessageEditPermission = asyncHandler(async (req, res, next) => {
    const { message_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    const [messageCheck] = await db.execute(
        "SELECT * FROM chat_messages WHERE message_id = ? AND sender_id = ? AND is_deleted = FALSE",
        [message_id, pharmacist_id]
    );

    if (messageCheck.length === 0) {
        throw new ApiError(404, "Message not found or you don't have permission to edit it");
    }

    // Check if message is too old to edit (24 hours)
    const messageAge = Date.now() - new Date(messageCheck[0].created_at).getTime();
    const maxEditAge = 24 * 60 * 60 * 1000; // 24 hours in milliseconds

    if (messageAge > maxEditAge) {
        throw new ApiError(400, "Message is too old to edit (24 hour limit)");
    }

    req.message = messageCheck[0];
    next();
});

// Middleware to check if user can delete message
export const checkMessageDeletePermission = asyncHandler(async (req, res, next) => {
    const { message_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    const [messageCheck] = await db.execute(
        "SELECT * FROM chat_messages WHERE message_id = ? AND sender_id = ? AND is_deleted = FALSE",
        [message_id, pharmacist_id]
    );

    if (messageCheck.length === 0) {
        throw new ApiError(404, "Message not found or you don't have permission to delete it");
    }

    req.message = messageCheck[0];
    next();
});

// Middleware to validate emoji reactions
export const validateEmojiReaction = asyncHandler(async (req, res, next) => {
    const { emoji } = req.body;

    if (!emoji) {
        throw new ApiError(400, "Emoji is required");
    }

    // Basic emoji validation (you can enhance this)
    const emojiRegex = /^[\u{1F600}-\u{1F64F}]|[\u{1F300}-\u{1F5FF}]|[\u{1F680}-\u{1F6FF}]|[\u{1F1E0}-\u{1F1FF}]|[\u{2600}-\u{26FF}]|[\u{2700}-\u{27BF}]$/u;
    
    if (!emojiRegex.test(emoji) && emoji.length > 10) {
        throw new ApiError(400, "Invalid emoji format");
    }

    next();
});

// Middleware to check if user can access shop-specific features
export const checkShopAccess = asyncHandler(async (req, res, next) => {
    const pharmacist_id = req.pharmacist.pharmacist_id;
    const { shop_id } = req.params;

    if (!shop_id) {
        throw new ApiError(400, "Shop ID is required");
    }

    const [shopCheck] = await db.execute(
        "SELECT * FROM employee WHERE pharmacist_id = ? AND shop_id = ?",
        [pharmacist_id, shop_id]
    );

    if (shopCheck.length === 0) {
        throw new ApiError(403, "You don't have access to this shop");
    }

    req.shopAccess = shopCheck[0];
    next();
});

