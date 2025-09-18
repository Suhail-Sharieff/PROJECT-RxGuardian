import { Router } from "express";
import { verifyJWT } from "../middleware/auth.middleware.js";
import {
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
} from "../controllers/chat.controller.js";

const router = Router();

// Apply JWT authentication to all routes
router.use(verifyJWT);

// ===============================
// Room Management Routes
// ===============================

// Create a new chat room
router.post("/rooms", createChatRoom);

// Get all chat rooms for the authenticated user
router.get("/rooms", getChatRooms);

// Join a chat room
router.post("/rooms/:room_id/join", joinChatRoom);

// Leave a chat room
router.post("/rooms/:room_id/leave", leaveChatRoom);

// Get room members
router.get("/rooms/:room_id/members", getRoomMembers);
/*
{
    "statusCode": 200,
    "data": [
        {
            "member_id": 12,
            "room_id": 3,
            "pharmacist_id": 17,
            "joined_at": "2025-09-18T07:01:52.000Z",
            "last_read_at": "2025-09-18T06:43:42.000Z",
            "is_admin": 1,
            "is_muted": 0,
            "is_active": 1,
            "name": "Suhail Sharieff",
            "email": "suhailsharieffsharieff@gmail.com",
            "online_status": "online",
            "last_seen": "2025-09-18T06:11:52.000Z"
        }
    ],
    "message": "Room members retrieved successfully",
    "success": true
}
 */

// ===============================
// Message Routes
// ===============================

// Send a message to a room
router.post("/messages", sendMessage);
/*{
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
}
     */

// Get messages from a room
//ex:{{server}}/chat/rooms/3/messages?page=1&limit =40
router.get("/rooms/:room_id/messages", getMessages);
/* {
    "statusCode": 200,
    "data": [
        {
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
            "sender_email": "suhailsharieffsharieff@gmail.com",
            "reply_to_message_text": null,
            "reply_to_sender_name": null,
            "reactions": []
        }
    ],
    "message": "Messages retrieved successfully",
    "success": true
}*/

// Edit a message
router.patch("/messages/:message_id", editMessage);

// Delete a message
router.delete("/messages/:message_id", deleteMessage);

// ===============================
// Online Status Routes
// ===============================

// Get online users (optionally filter by room)
router.get("/online", getOnlineUsers);
/**{
    "statusCode": 200,
    "data": [
        {
            "pharmacist_id": 17,
            "socket_id": "9og4sFUw3JSCz5Z3AAAB",
            "last_seen": "2025-09-18T06:11:52.000Z",
            "status": "online",
            "current_room_id": null,
            "name": "Suhail Sharieff",
            "email": "suhailsharieffsharieff@gmail.com",
            "current_room_name": null
        }
    ],
    "message": "Online users retrieved successfully",
    "success": true
}
    
*/

// Update user status
router.patch("/status", updateUserStatus);
/*body needed:{
    "status":"busy",
    "current_room_id":3
}*/
// ===============================
// Message Reactions Routes
// ===============================

// Add reaction to a message
router.post("/messages/:message_id/addReaction", addReaction);
/**req body:{
    "emoji":"💓"
} */

// Remove reaction from a message
router.delete("/messages/:message_id/removeReaction", removeReaction);

// ===============================
// Read Status Routes
// ===============================

// Mark a specific message as read
router.post("/messages/:message_id/read", markMessageAsRead);

// Mark all messages in a room as read
router.post("/rooms/:room_id/read", markRoomAsRead);
/**response:{
    "statusCode": 200,
    "data": {
        "unread_count": 0
    },
    "message": "Room marked as read",
    "success": true
} */


// ===============================
// Admin Routes
// ===============================

// Add member to room (admin only)
router.post("/rooms/:room_id/addMemberToRoom", addMemberToRoom);
/**requreed body:{
    "pharmacist_id":13
} */

// Remove member from room (admin only)
router.delete("/rooms/:room_id/members/:pharmacist_id/removeMemberFromRoom", removeMemberFromRoom);

// Mute member (admin only)
router.patch("/rooms/:room_id/members/:pharmacist_id/mute", muteMember);

// Unmute member (admin only)
router.patch("/rooms/:room_id/members/:pharmacist_id/unmute", unmuteMember);

export { router as chatRouter };
