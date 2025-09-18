# 💬 Rx Guardian Chat System API Documentation

## Overview
The Rx Guardian Chat System provides real-time communication features for pharmacists with advanced functionality including typing indicators, online status, message reactions, and more.

## Features
- ✅ Real-time messaging with Socket.IO
- ✅ Online/offline status tracking
- ✅ Typing indicators
- ✅ Message reactions (emojis)
- ✅ Message read receipts
- ✅ Room management (general, shop-specific, private)
- ✅ Admin controls (mute, add/remove members)
- ✅ Message editing and deletion
- ✅ File sharing support
- ✅ Message replies
- ✅ Rate limiting
- ✅ Profanity filtering

## Authentication
All endpoints require JWT authentication via:
- Cookie: `accessToken`
- Header: `Authorization: Bearer <token>`

## Socket.IO Events

### Client → Server Events

#### Connection
```javascript
// Connect with authentication
const socket = io('http://localhost:3000', {
  auth: {
    token: 'your-jwt-token'
  }
});
```

#### Room Management
```javascript
// Join a room
socket.emit('join_room', { room_id: 1 });

// Leave a room
socket.emit('leave_room', { room_id: 1 });
```

#### Messaging
```javascript
// Send a message
socket.emit('send_message', {
  room_id: 1,
  message_text: 'Hello everyone!',
  message_type: 'text', // 'text', 'image', 'file', 'system'
  reply_to_message_id: 123 // optional
});

// Start typing
socket.emit('start_typing', { room_id: 1 });

// Stop typing
socket.emit('stop_typing', { room_id: 1 });
```

#### Reactions
```javascript
// Add reaction
socket.emit('add_reaction', {
  message_id: 123,
  emoji: '👍',
  room_id: 1
});

// Remove reaction
socket.emit('remove_reaction', {
  message_id: 123,
  room_id: 1
});
```

#### Status Updates
```javascript
// Update status
socket.emit('update_status', {
  status: 'online', // 'online', 'away', 'busy', 'invisible'
  current_room_id: 1
});
```

#### Read Status
```javascript
// Mark message as read
socket.emit('mark_message_read', {
  message_id: 123,
  room_id: 1
});
```

### Server → Client Events

#### Connection Events
```javascript
// User connected
socket.on('user_joined_room', (data) => {
  console.log(`${data.name} joined room ${data.room_id}`);
});

// User disconnected
socket.on('user_left_room', (data) => {
  console.log(`${data.name} left room ${data.room_id}`);
});

// User status changed
socket.on('user_status_changed', (data) => {
  console.log(`${data.name} is now ${data.status}`);
});
```

#### Messaging Events
```javascript
// New message received
socket.on('new_message', (message) => {
  console.log('New message:', message);
});

// User typing
socket.on('user_typing', (data) => {
  console.log(`${data.name} is ${data.is_typing ? 'typing' : 'not typing'}`);
});
```

#### Reaction Events
```javascript
// Reaction added
socket.on('reaction_added', (data) => {
  console.log(`${data.name} reacted with ${data.emoji}`);
});

// Reaction removed
socket.on('reaction_removed', (data) => {
  console.log(`${data.name} removed reaction`);
});
```

#### Read Status Events
```javascript
// Message read
socket.on('message_read', (data) => {
  console.log(`${data.name} read message ${data.message_id}`);
});
```

## REST API Endpoints

### Room Management

#### Create Chat Room
```http
POST /chat/rooms
Content-Type: application/json
Authorization: Bearer <token>

{
  "room_name": "General Discussion",
  "room_type": "general", // "general", "shop", "private"
  "shop_id": 1 // required for shop rooms
}
```

#### Get Chat Rooms
```http
GET /chat/rooms?room_type=general&shop_id=1
Authorization: Bearer <token>
```

#### Join Chat Room
```http
POST /chat/rooms/{room_id}/join
Authorization: Bearer <token>
```

#### Leave Chat Room
```http
POST /chat/rooms/{room_id}/leave
Authorization: Bearer <token>
```

#### Get Room Members
```http
GET /chat/rooms/{room_id}/members
Authorization: Bearer <token>
```

### Message Management

#### Send Message
```http
POST /chat/messages
Content-Type: application/json
Authorization: Bearer <token>

{
  "room_id": 1,
  "message_text": "Hello everyone!",
  "message_type": "text",
  "reply_to_message_id": 123,
  "file_url": "https://example.com/file.jpg",
  "file_name": "image.jpg",
  "file_size": 1024
}
```

#### Get Messages
```http
GET /chat/rooms/{room_id}/messages?page=1&limit=50&before_message_id=123
Authorization: Bearer <token>
```

#### Edit Message
```http
PUT /chat/messages/{message_id}
Content-Type: application/json
Authorization: Bearer <token>

{
  "message_text": "Updated message text"
}
```

#### Delete Message
```http
DELETE /chat/messages/{message_id}
Authorization: Bearer <token>
```

### Online Status

#### Get Online Users
```http
GET /chat/online?room_id=1
Authorization: Bearer <token>
```

#### Update User Status
```http
PUT /chat/status
Content-Type: application/json
Authorization: Bearer <token>

{
  "status": "away",
  "current_room_id": 1
}
```

### Message Reactions

#### Add Reaction
```http
POST /chat/messages/{message_id}/reactions
Content-Type: application/json
Authorization: Bearer <token>

{
  "emoji": "👍"
}
```

#### Remove Reaction
```http
DELETE /chat/messages/{message_id}/reactions
Authorization: Bearer <token>
```

### Read Status

#### Mark Message as Read
```http
POST /chat/messages/{message_id}/read
Authorization: Bearer <token>
```

#### Mark Room as Read
```http
POST /chat/rooms/{room_id}/read
Authorization: Bearer <token>
```

### Admin Functions

#### Add Member to Room
```http
POST /chat/rooms/{room_id}/members
Content-Type: application/json
Authorization: Bearer <token>

{
  "pharmacist_id": 123
}
```

#### Remove Member from Room
```http
DELETE /chat/rooms/{room_id}/members/{pharmacist_id}
Authorization: Bearer <token>
```

#### Mute Member
```http
POST /chat/rooms/{room_id}/members/{pharmacist_id}/mute
Authorization: Bearer <token>
```

#### Unmute Member
```http
POST /chat/rooms/{room_id}/members/{pharmacist_id}/unmute
Authorization: Bearer <token>
```

## Response Format

### Success Response
```json
{
  "statusCode": 200,
  "success": true,
  "message": "Operation successful",
  "data": {
    // Response data
  }
}
```

### Error Response
```json
{
  "statusCode": 400,
  "success": false,
  "message": "Error message",
  "errors": [
    // Additional error details
  ]
}
```

## Database Schema

### Chat Rooms
- `room_id` (Primary Key)
- `room_name` (VARCHAR)
- `room_type` (ENUM: 'general', 'shop', 'private')
- `shop_id` (Foreign Key to shop table)
- `created_by` (Foreign Key to pharmacist table)
- `created_at`, `updated_at` (Timestamps)
- `is_active` (Boolean)

### Chat Messages
- `message_id` (Primary Key)
- `room_id` (Foreign Key)
- `sender_id` (Foreign Key to pharmacist table)
- `message_text` (TEXT)
- `message_type` (ENUM: 'text', 'image', 'file', 'system')
- `file_url`, `file_name`, `file_size` (File details)
- `reply_to_message_id` (Foreign Key to chat_messages)
- `is_edited`, `edited_at` (Edit tracking)
- `is_deleted`, `deleted_at` (Soft delete)
- `created_at`, `updated_at` (Timestamps)

### Chat Room Members
- `member_id` (Primary Key)
- `room_id` (Foreign Key)
- `pharmacist_id` (Foreign Key)
- `joined_at` (Timestamp)
- `last_read_at` (Timestamp)
- `is_admin` (Boolean)
- `is_muted` (Boolean)
- `is_active` (Boolean)

### Online Users
- `pharmacist_id` (Primary Key)
- `socket_id` (VARCHAR)
- `last_seen` (Timestamp)
- `status` (ENUM: 'online', 'away', 'busy', 'invisible')
- `current_room_id` (Foreign Key)

### Typing Indicators
- `id` (Primary Key)
- `room_id` (Foreign Key)
- `pharmacist_id` (Foreign Key)
- `is_typing` (Boolean)
- `started_typing_at` (Timestamp)

### Message Reactions
- `reaction_id` (Primary Key)
- `message_id` (Foreign Key)
- `pharmacist_id` (Foreign Key)
- `emoji` (VARCHAR)
- `created_at` (Timestamp)

### Message Read Status
- `read_id` (Primary Key)
- `message_id` (Foreign Key)
- `pharmacist_id` (Foreign Key)
- `read_at` (Timestamp)

## Rate Limiting
- Message sending: 10 messages per minute per user
- Typing indicators: No limit
- Reactions: 50 per minute per user

## Security Features
- JWT authentication for all endpoints
- Room membership validation
- Admin privilege checks
- Message ownership validation
- Rate limiting
- Basic profanity filtering
- Input validation and sanitization

## Error Codes
- `400` - Bad Request
- `401` - Unauthorized
- `403` - Forbidden
- `404` - Not Found
- `429` - Rate Limit Exceeded
- `500` - Internal Server Error

## Usage Examples

### Frontend Integration (JavaScript)
```javascript
// Initialize Socket.IO connection
const socket = io('http://localhost:3000', {
  auth: {
    token: localStorage.getItem('accessToken')
  }
});

// Join a room
socket.emit('join_room', { room_id: 1 });

// Send a message
function sendMessage(roomId, text) {
  socket.emit('send_message', {
    room_id: roomId,
    message_text: text,
    message_type: 'text'
  });
}

// Listen for new messages
socket.on('new_message', (message) => {
  displayMessage(message);
});

// Handle typing indicators
let typingTimer;
function handleTyping(roomId) {
  socket.emit('start_typing', { room_id: roomId });
  
  clearTimeout(typingTimer);
  typingTimer = setTimeout(() => {
    socket.emit('stop_typing', { room_id: roomId });
  }, 1000);
}
```

### React Integration Example
```jsx
import { useEffect, useState } from 'react';
import io from 'socket.io-client';

function ChatRoom({ roomId, token }) {
  const [socket, setSocket] = useState(null);
  const [messages, setMessages] = useState([]);
  const [typingUsers, setTypingUsers] = useState([]);

  useEffect(() => {
    const newSocket = io('http://localhost:3000', {
      auth: { token }
    });
    
    setSocket(newSocket);
    
    newSocket.emit('join_room', { room_id: roomId });
    
    newSocket.on('new_message', (message) => {
      setMessages(prev => [...prev, message]);
    });
    
    newSocket.on('user_typing', (data) => {
      if (data.is_typing) {
        setTypingUsers(prev => [...prev, data.name]);
      } else {
        setTypingUsers(prev => prev.filter(name => name !== data.name));
      }
    });
    
    return () => newSocket.close();
  }, [roomId, token]);

  const sendMessage = (text) => {
    socket.emit('send_message', {
      room_id: roomId,
      message_text: text,
      message_type: 'text'
    });
  };

  return (
    <div>
      {/* Chat UI components */}
    </div>
  );
}
```

This comprehensive chat system provides all the advanced features you requested, including real-time messaging, online status tracking, typing indicators, message reactions, and more!
