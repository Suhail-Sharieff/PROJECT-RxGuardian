import { asyncHandler } from "../Utils/asyncHandler.utils.js";
import { ApiError } from "../Utils/Api_Error.utils.js";
import { ApiResponse } from "../Utils/Api_Response.utils.js";
import { db } from "../Utils/sql_connection.utils.js";
import { redis } from "../Utils/redis.connection.js";
import { getShopImWorkingIn } from "./shop.controller.js";

// ===============================
// Chat Room Management
// ===============================
/**sample response for below api: 
{
    "statusCode": 201,
    "data": {
        "room_id": 3,
        "room_name": "New Room",
        "room_type": "shop"
    },
    "message": "Chat room created successfully",
    "success": true
}
*/
const createChatRoom = asyncHandler(async (req, res) => {
    const { room_name, room_type = 'general'} = req.body;
    const shop_id=await getShopImWorkingIn(req,res);
    const pharmacist_id = req.pharmacist.pharmacist_id;

    if (!room_name) {
        throw new ApiError(400, "Room name is required");
    }

    // Validate room type
    if (!['general', 'shop', 'private'].includes(room_type)) {
        throw new ApiError(400, "Invalid room type");
    }

    // If it's a shop room, validate shop_id
    if (room_type === 'shop' && !shop_id) {
        throw new ApiError(400, "Shop ID is required for shop rooms");
    }

    // Check if user has access to the shop (if it's a shop room)
    if (room_type === 'shop') {
        const [shopCheck] = await db.execute(
            "SELECT * FROM employee WHERE pharmacist_id = ? AND shop_id = ?",
            [pharmacist_id, shop_id]
        );
        if (shopCheck.length === 0) {
            throw new ApiError(403, "You don't have access to this shop");
        }
    }

    const [result] = await db.execute(
        `INSERT INTO chat_rooms (room_name, room_type, shop_id, created_by) 
         VALUES (?, ?, ?, ?)`,
        [room_name, room_type, shop_id, pharmacist_id]
    );

    const room_id = result.insertId;

    // Add creator as admin member
    await db.execute(
        `INSERT INTO chat_room_members (room_id, pharmacist_id, is_admin) 
         VALUES (?, ?, TRUE)`,
        [room_id, pharmacist_id]
    );

    return res.status(201).json(
        new ApiResponse(201, { room_id, room_name, room_type }, "Chat room created successfully")
    );
});


const getChatRooms = asyncHandler(async (req, res) => {
    const pharmacist_id = req.pharmacist.pharmacist_id;
    const { room_type } = req.query;
    const shop_id = await getShopImWorkingIn(req, res);

    // This single, optimized query now includes the unread_count
    let query = `
        WITH 
        LatestMessages AS (
            SELECT
                cm.room_id,
                cm.message_text,
                cm.created_at,
                cm.sender_id,
                p.name AS sender_name,
                ROW_NUMBER() OVER(PARTITION BY cm.room_id ORDER BY cm.created_at DESC) as rn
            FROM chat_messages cm
            JOIN pharmacist p ON cm.sender_id = p.pharmacist_id
            WHERE cm.is_deleted = FALSE
        ),
        RoomMemberCounts AS (
            SELECT
                room_id,
                COUNT(*) as member_count
            FROM chat_room_members
            WHERE is_active = TRUE
            GROUP BY room_id
        )
        SELECT 
            cr.*,
            rmc.member_count,
            lm.message_text as last_message,
            lm.created_at as last_message_time,
            lm.sender_id as last_message_sender_id,
            lm.sender_name as last_message_sender_name,
            
            -- THIS IS THE NEW PART: Calculate unread_count --
            (SELECT COUNT(*) 
             FROM chat_messages cm 
             WHERE cm.room_id = cr.room_id 
               AND (cm.created_at > crm.last_read_timestamp OR crm.last_read_timestamp IS NULL)
               AND cm.sender_id != ? -- Don't count your own messages as unread
            ) as unread_count

        FROM 
            chat_rooms cr
        JOIN 
            chat_room_members crm ON cr.room_id = crm.room_id
        LEFT JOIN 
            RoomMemberCounts rmc ON cr.room_id = rmc.room_id
        LEFT JOIN 
            LatestMessages lm ON cr.room_id = lm.room_id AND lm.rn = 1
        WHERE 
            cr.is_active = TRUE
            AND crm.pharmacist_id = ? 
            AND crm.is_active = TRUE
    `;
    
    // Note: pharmacist_id is used twice now
    const params = [pharmacist_id, pharmacist_id]; 

    if (room_type) {
        query += " AND cr.room_type = ?";
        params.push(room_type);
    }
    if (shop_id) {
        query += " AND cr.shop_id = ?";
        params.push(shop_id);
    }

    query += ` ORDER BY COALESCE(last_message_time, cr.created_at) DESC `;

    const [rooms] = await db.execute(query, params);

    return res.status(200).json(
        new ApiResponse(200, rooms, "Chat rooms retrieved successfully")
    );
});
const joinChatRoom = asyncHandler(async (req, res) => {
    const { room_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;
    console.log(`pharmacist_id=${pharmacist_id} is trying to join room_id=${room_id}`);
    
    // Check if room exists and is active
    const [roomCheck] = await db.execute(
        "SELECT * FROM chat_rooms WHERE room_id = ? AND is_active = TRUE",
        [room_id]
    );

    if (roomCheck.length === 0) {
        throw new ApiError(404, "Chat room not found");
    }

    // Check if user is already a member
    const [memberCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ?",
        [room_id, pharmacist_id]
    );

    if (memberCheck.length > 0) {
        console.log(`pharmacist_id=${pharmacist_id} is a memeber of this room_id=${room_id}`);
        
        // Reactivate if inactive
        if (!memberCheck[0].is_active) {
            console.log(`activating pharmacist_id=${pharmacist_id}`);
            
            await db.execute(
                "UPDATE chat_room_members SET is_active = TRUE, joined_at = CURRENT_TIMESTAMP WHERE room_id = ? AND pharmacist_id = ?",
                [room_id, pharmacist_id]
            );
        }
        return res.status(200).json(
            new ApiResponse(200, {}, "Already a member of this room")
        );
    }

    // Add user to room
    const [rows]=await db.execute(
        "INSERT INTO chat_room_members (room_id, pharmacist_id) VALUES (?, ?)",
        [room_id, pharmacist_id]
    );

    return res.status(200).json(
        new ApiResponse(200, rows, `pharmacist_id=${pharmacist_id}  Successfully joined chat room`)
    );
});

const leaveChatRoom = asyncHandler(async (req, res) => {
    const { room_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;
    console.log(`pharmacist_id=${pharmacist_id} is trying to LEAVE room_id=${room_id}`);
    // Check if user is a member
    const [memberCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_active = TRUE",
        [room_id, pharmacist_id]
    );

    if (memberCheck.length === 0) {
        throw new ApiError(404, "You are not a member of this room");
    }

    // Deactivate membership
    await db.execute(
        "UPDATE chat_room_members SET is_active = FALSE WHERE room_id = ? AND pharmacist_id = ?",
        [room_id, pharmacist_id]
    );

    return res.status(200).json(
        new ApiResponse(200, {}, `pharmacist_id=${pharmacist_id}  Successfully left chat room`)
    );
});

// ===============================
// Message Management
// ===============================
/**{
    "statusCode": 201,
    "data": {
        "message_id": 4,
        "room_id": 3,
        "sender_id": 17,
        "message_text": "Hello im Suhail",
        "message_type": "text",
        "file_url": null,
        "file_name": null,
        "file_size": null,
        "reply_to_message_id": null,
        "is_edited": 0,
        "edited_at": null,
        "is_deleted": 0,
        "deleted_at": null,
        "created_at": "2025-09-18T07:13:27.000Z",
        "updated_at": "2025-09-18T07:13:27.000Z",
        "sender_name": "Suhail Sharieff",
        "sender_email": "suhailsharieffsharieff@gmail.com"
    },
    "message": "Message sent successfully",
    "success": true
} */
const sendMessage = asyncHandler(async (req, res) => {
    const { room_id, message_text, message_type = 'text', reply_to_message_id = null, file_url = null, file_name = null, file_size = null } = req.body;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    if (!room_id || !message_text) {
        throw new ApiError(400, "Room ID and message text are required");
    }

    // Check if user is a member of the room
    const [memberCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_active = TRUE",
        [room_id, pharmacist_id]
    );

    if (memberCheck.length === 0) {
        throw new ApiError(403, "You are not a member of this room");
    }

    // Check if user is muted
    if (memberCheck[0].is_muted) {
        throw new ApiError(403, "You are muted in this room");
    }

    // Validate reply_to_message_id if provided
    if (reply_to_message_id) {
        const [replyCheck] = await db.execute(
            "SELECT * FROM chat_messages WHERE message_id = ? AND room_id = ? AND is_deleted = FALSE",
            [reply_to_message_id, room_id]
        );
        if (replyCheck.length === 0) {
            throw new ApiError(404, "Reply message not found");
        }
    }

    const [result] = await db.execute(
        `INSERT INTO chat_messages 
         (room_id, sender_id, message_text, message_type, reply_to_message_id, file_url, file_name, file_size) 
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)`,
        [room_id, pharmacist_id, message_text, message_type, reply_to_message_id, file_url, file_name, file_size]
    );

    const message_id = result.insertId;

    // Get the complete message with sender details
    const [message] = await db.execute(
        `SELECT cm.*, p.name as sender_name, p.email as sender_email
         FROM chat_messages cm
         JOIN pharmacist p ON cm.sender_id = p.pharmacist_id
         WHERE cm.message_id = ?`,
        [message_id]
    );

    // Clear cache for this room
    await redis.del(`chat_messages_${room_id}`);

    return res.status(200).json(
        new ApiResponse(200, message[0], `Message sent successfully from pharmacist_id=${pharmacist_id} into room_id=${room_id}`)
    );
});

const getMessages = asyncHandler(async (req, res) => {
    const { room_id } = req.params;
    const { page = 1, limit = 50, before_message_id = null } = req.query;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    // Check if user is a member of the room
    const [memberCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ?",
        [room_id, pharmacist_id]
    );

    if (memberCheck.length === 0) {
        throw new ApiError(403, "You are not a member of this room");
    }
    console.log(`pharmacist_id=${pharmacist_id} trying to fetch messgaes....`);
    
    const offset = (page - 1) * limit;
    let query = `
        SELECT cm.*, 
        p.name as sender_name, 
        p.email as sender_email,
        reply_msg.message_text as reply_to_message_text,
        reply_sender.name as reply_to_sender_name
        FROM chat_messages cm
        JOIN pharmacist p ON cm.sender_id = p.pharmacist_id
        LEFT JOIN chat_messages reply_msg ON cm.reply_to_message_id = reply_msg.message_id
        LEFT JOIN pharmacist reply_sender ON reply_msg.sender_id = reply_sender.pharmacist_id
        WHERE cm.room_id = ? AND cm.is_deleted = FALSE
    `;
    
    const params = [room_id];

    // if (before_message_id) {
    //     query += " AND cm.message_id < ?";
    //     params.push(before_message_id);
    // }

    query += ` ORDER BY cm.created_at DESC `;

    const [messages] = await db.execute(query, params);

    // Get message reactions
    for (let message of messages) {
        const [reactions] = await db.execute(
            `SELECT mr.*, p.name as pharmacist_name 
             FROM message_reactions mr
             JOIN pharmacist p ON mr.pharmacist_id = p.pharmacist_id
             WHERE mr.message_id = ?`,
            [message.message_id]
        );
        message.reactions = reactions;
    }

    return res.status(200).json(
        new ApiResponse(200, messages.reverse(), "Messages retrieved successfully")
    );
});

const editMessage = asyncHandler(async (req, res) => {
    const { message_id } = req.params;
    const { message_text } = req.body;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    if (!message_text) {
        throw new ApiError(400, "Message text is required");
    }

    // Check if message exists and user is the sender
    const [messageCheck] = await db.execute(
        "SELECT * FROM chat_messages WHERE message_id = ? AND sender_id = ? AND is_deleted = FALSE",
        [message_id, pharmacist_id]
    );

    if (messageCheck.length === 0) {
        throw new ApiError(404, "Message not found or you don't have permission to edit it");
    }

    // Check if message is too old to edit (24 hours)
    const messageAge = Date.now() - new Date(messageCheck[0].created_at).getTime();
    if (messageAge > 24 * 60 * 60 * 1000) {
        throw new ApiError(400, "Message is too old to edit");
    }

    await db.execute(
        "UPDATE chat_messages SET message_text = ?, is_edited = TRUE, edited_at = CURRENT_TIMESTAMP WHERE message_id = ?",
        [message_text, message_id]
    );

    return res.status(200).json(
        new ApiResponse(200, {}, "Message edited successfully")
    );
});

const deleteMessage = asyncHandler(async (req, res) => {
    const { message_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    // Check if message exists and user is the sender
    const [messageCheck] = await db.execute(
        "SELECT * FROM chat_messages WHERE message_id = ? AND sender_id = ? AND is_deleted = FALSE",
        [message_id, pharmacist_id]
    );

    if (messageCheck.length === 0) {
        throw new ApiError(404, "Message not found or you don't have permission to delete it");
    }

    // Soft delete the message
    await db.execute(
        "UPDATE chat_messages SET is_deleted = TRUE, deleted_at = CURRENT_TIMESTAMP WHERE message_id = ?",
        [message_id]
    );

    return res.status(200).json(
        new ApiResponse(200, {}, "Message deleted successfully")
    );
});

// ===============================
// Online Status & Presence
// ===============================

const getOnlineUsers = asyncHandler(async (req, res) => {
    const { room_id = null } = req.query;

    let query = `
        SELECT ou.*, p.name, p.email, cr.room_name as current_room_name
        FROM online_users ou
        JOIN pharmacist p ON ou.pharmacist_id = p.pharmacist_id
        LEFT JOIN chat_rooms cr ON ou.current_room_id = cr.room_id
        WHERE ou.status != 'invisible'
    `;
    
    const params = [];

    if (room_id) {
        query += " AND ou.current_room_id = ?";
        params.push(room_id);
    }

    query += " ORDER BY ou.last_seen DESC";

    const [onlineUsers] = await db.execute(query, params);

    return res.status(200).json(
        new ApiResponse(200, onlineUsers, "Online users retrieved successfully")
    );
});

const updateUserStatus = asyncHandler(async (req, res) => {
    const { status, current_room_id  } = req.body;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    if (!['online', 'away', 'busy', 'invisible'].includes(status)) {
        throw new ApiError(400, "Invalid status");
    }

    // Check if user is online
    const [onlineCheck] = await db.execute(
        "SELECT * FROM online_users WHERE pharmacist_id = ?",
        [pharmacist_id]
    );

    if (onlineCheck.length === 0) {
        throw new ApiError(404, "User is not online");
    }

    await db.execute(
        "UPDATE online_users SET status = ?, current_room_id = ?, last_seen = CURRENT_TIMESTAMP WHERE pharmacist_id = ?",
        [status, current_room_id, pharmacist_id]
    );

    return res.status(200).json(
        new ApiResponse(200, {}, "Status updated successfully")
    );
});

// ===============================
// Message Reactions
// ===============================

const addReaction = asyncHandler(async (req, res) => {
    const { message_id } = req.params;
    const { emoji } = req.body;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    if (!emoji) {
        throw new ApiError(400, "Emoji is required");
    }

    // Check if message exists
    const [messageCheck] = await db.execute(
        "SELECT * FROM chat_messages WHERE message_id = ? AND is_deleted = FALSE",
        [message_id]
    );

    if (messageCheck.length === 0) {
        throw new ApiError(404, "Message not found");
    }

    // Check if user is a member of the room
    const [memberCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_active = TRUE",
        [messageCheck[0].room_id, pharmacist_id]
    );

    if (memberCheck.length === 0) {
        throw new ApiError(403, "You are not a member of this room");
    }

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

    return res.status(200).json(
        new ApiResponse(200, {}, "Reaction added successfully")
    );
});

const removeReaction = asyncHandler(async (req, res) => {
    const { message_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    await db.execute(
        "DELETE FROM message_reactions WHERE message_id = ? AND pharmacist_id = ?",
        [message_id, pharmacist_id]
    );

    return res.status(200).json(
        new ApiResponse(200, {}, "Reaction removed successfully")
    );
});

// ===============================
// Message Read Status
// ===============================

const markMessageAsRead = asyncHandler(async (req, res) => {
    const { message_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    // Check if message exists
    const [messageCheck] = await db.execute(
        "SELECT * FROM chat_messages WHERE message_id = ? AND is_deleted = FALSE",
        [message_id]
    );

    if (messageCheck.length === 0) {
        throw new ApiError(404, "Message not found");
    }

    // Check if user is a member of the room
    const [memberCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_active = TRUE",
        [messageCheck[0].room_id, pharmacist_id]
    );

    if (memberCheck.length === 0) {
        throw new ApiError(403, "You are not a member of this room");
    }

    // Insert or update read status
    await db.execute(
        `INSERT INTO message_read_status (message_id, pharmacist_id) 
         VALUES (?, ?) 
         ON DUPLICATE KEY UPDATE read_at = CURRENT_TIMESTAMP`,
        [message_id, pharmacist_id]
    );

    return res.status(200).json(
        new ApiResponse(200, {}, "Message marked as read")
    );
});

const markRoomAsRead = asyncHandler(async (req, res) => {
    const { room_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    // Check if user is a member of the room
    const [memberCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_active = TRUE",
        [room_id, pharmacist_id]
    );

    if (memberCheck.length === 0) {
        throw new ApiError(403, "You are not a member of this room");
    }

    // Get all unread messages in the room
    const [unreadMessages] = await db.execute(
        `SELECT message_id FROM chat_messages 
         WHERE room_id = ? AND sender_id != ? AND is_deleted = FALSE
         AND message_id NOT IN (
             SELECT message_id FROM message_read_status WHERE pharmacist_id = ?
         )`,
        [room_id, pharmacist_id, pharmacist_id]
    );

    // Mark all as read
    if (unreadMessages.length > 0) {
        const messageIds = unreadMessages.map(msg => msg.message_id);
        const placeholders = messageIds.map(() => '?').join(',');
        
        await db.execute(
            `INSERT INTO message_read_status (message_id, pharmacist_id) 
             VALUES ${messageIds.map(() => '(?, ?)').join(', ')}`,
            messageIds.flatMap(id => [id, pharmacist_id])
        );
    }

    // Update last read timestamp
    await db.execute(
        "UPDATE chat_room_members SET last_read_at = CURRENT_TIMESTAMP WHERE room_id = ? AND pharmacist_id = ?",
        [room_id, pharmacist_id]
    );

    return res.status(200).json(
        new ApiResponse(200, { unread_count: unreadMessages.length }, "Room marked as read")
    );
});

// ===============================
// Room Management (Admin functions)
// ===============================

const addMemberToRoom = asyncHandler(async (req, res) => {
    const { room_id } = req.params;
    const { pharmacist_id } = req.body;
    const admin_id = req.pharmacist.pharmacist_id;

    // Check if admin is actually an admin of the room
    const [adminCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_admin = TRUE AND is_active = TRUE",
        [room_id, admin_id]
    );

    if (adminCheck.length === 0) {
        throw new ApiError(403, "You don't have admin privileges in this room");
    }

    // Check if user is already a member
    const [memberCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ?",
        [room_id, pharmacist_id]
    );

    if (memberCheck.length > 0) {
        if (memberCheck[0].is_active) {
            return res.status(200).json(
                new ApiResponse(200, {}, "User is already a member")
            );
        } else {
            // Reactivate
            await db.execute(
                "UPDATE chat_room_members SET is_active = TRUE, joined_at = CURRENT_TIMESTAMP WHERE room_id = ? AND pharmacist_id = ?",
                [room_id, pharmacist_id]
            );
        }
    } else {
        // Add new member
        await db.execute(
            "INSERT INTO chat_room_members (room_id, pharmacist_id) VALUES (?, ?)",
            [room_id, pharmacist_id]
        );
    }

    return res.status(200).json(
        new ApiResponse(200, {}, "Member added successfully")
    );
});

const removeMemberFromRoom = asyncHandler(async (req, res) => {
    const { room_id, pharmacist_id } = req.params;
    const admin_id = req.pharmacist.pharmacist_id;

    // Check if admin is actually an admin of the room
    const [adminCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_admin = TRUE AND is_active = TRUE",
        [room_id, admin_id]
    );

    if (adminCheck.length === 0) {
        throw new ApiError(403, "You don't have admin privileges in this room");
    }

    // Can't remove yourself
    if (parseInt(pharmacist_id) === admin_id) {
        throw new ApiError(400, "You cannot remove yourself from the room");
    }

    await db.execute(
        "delete from  chat_room_members  WHERE room_id = ? AND pharmacist_id = ?",
        [room_id, pharmacist_id]
    );

    return res.status(200).json(
        new ApiResponse(200, {}, "Member removed successfully")
    );
});

const muteMember = asyncHandler(async (req, res) => {
    const { room_id, pharmacist_id } = req.params;
    const admin_id = req.pharmacist.pharmacist_id;

    // Check if admin is actually an admin of the room
    const [adminCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_admin = TRUE AND is_active = TRUE",
        [room_id, admin_id]
    );

    if (adminCheck.length === 0) {
        throw new ApiError(403, "You don't have admin privileges in this room");
    }

    await db.execute(
        "UPDATE chat_room_members SET is_muted = TRUE WHERE room_id = ? AND pharmacist_id = ?",
        [room_id, pharmacist_id]
    );

    return res.status(200).json(
        new ApiResponse(200, {}, "Member muted successfully")
    );
});

const unmuteMember = asyncHandler(async (req, res) => {
    const { room_id, pharmacist_id } = req.params;
    const admin_id = req.pharmacist.pharmacist_id;

    // Check if admin is actually an admin of the room
    const [adminCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_admin = TRUE AND is_active = TRUE",
        [room_id, admin_id]
    );

    if (adminCheck.length === 0) {
        throw new ApiError(403, "You don't have admin privileges in this room");
    }

    await db.execute(
        "UPDATE chat_room_members SET is_muted = FALSE WHERE room_id = ? AND pharmacist_id = ?",
        [room_id, pharmacist_id]
    );

    return res.status(200).json(
        new ApiResponse(200, {}, "Member unmuted successfully")
    );
});









const getRoomMembers = asyncHandler(async (req, res) => {
    const { room_id } = req.params;
    const pharmacist_id = req.pharmacist.pharmacist_id;

    // Check if user is a member of the room
    const [memberCheck] = await db.execute(
        "SELECT * FROM chat_room_members WHERE room_id = ? AND pharmacist_id = ? AND is_active = TRUE",
        [room_id, pharmacist_id]
    );

    if (memberCheck.length === 0) {
        throw new ApiError(403, "You are not a member of this room");
    }

    const [members] = await db.execute(
        `SELECT crm.*, p.name, p.email, ou.status as online_status, ou.last_seen
         FROM chat_room_members crm
         JOIN pharmacist p ON crm.pharmacist_id = p.pharmacist_id
         LEFT JOIN online_users ou ON crm.pharmacist_id = ou.pharmacist_id
         WHERE crm.room_id = ? AND crm.is_active = TRUE
         ORDER BY crm.is_admin DESC, p.name ASC`,
        [room_id]
    );

    return res.status(200).json(
        new ApiResponse(200, members, "Room members retrieved successfully")
    );
});

export {
    // Room Management
    createChatRoom,
    getChatRooms,
    joinChatRoom,
    leaveChatRoom,
    
    // Message Management
    sendMessage,
    getMessages,
    editMessage,
    deleteMessage,
    
    // Online Status
    getOnlineUsers,
    updateUserStatus,
    
    // Reactions
    addReaction,
    removeReaction,
    
    // Read Status
    markMessageAsRead,
    markRoomAsRead,
    
    // Admin Functions
    addMemberToRoom,
    removeMemberFromRoom,
    muteMember,
    unmuteMember,
    getRoomMembers
};
