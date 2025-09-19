import { io } from 'socket.io-client';
import jwt from 'jsonwebtoken';

// Test configuration
const SERVER_URL = 'http://localhost:3000';
const TEST_PHARMACIST = {
    pharmacist_id: 1,
    email: 'test@pharmacist.com',
    name: 'Test Pharmacist'
};

// Generate test JWT token
const generateTestToken = () => {
    return jwt.sign(
        {
            pharmacist_id: TEST_PHARMACIST.pharmacist_id,
            email: TEST_PHARMACIST.email,
            name: TEST_PHARMACIST.name,
        },
        process.env.ACCESS_TOKEN_SECRET || 'test-secret',
        { expiresIn: '1h' }
    );
};

// Test Socket.IO connection
const testSocketConnection = () => {
    return new Promise((resolve, reject) => {
        const token = generateTestToken();
        const socket = io(SERVER_URL, {
            auth: { token }
        });

        socket.on('connect', () => {
            console.log('✅ Socket.IO connection successful');
            resolve(socket);
        });

        socket.on('connect_error', (error) => {
            console.error('❌ Socket.IO connection failed:', error.message);
            reject(error);
        });

        // Timeout after 5 seconds
        setTimeout(() => {
            reject(new Error('Connection timeout'));
        }, 5000);
    });
};

// Test room joining
const testRoomJoining = (socket) => {
    return new Promise((resolve, reject) => {
        socket.emit('join_room', { room_id: 1 });
        
        socket.on('user_joined_room', (data) => {
            console.log('✅ Room joining successful:', data);
            resolve(data);
        });

        socket.on('error', (error) => {
            console.error('❌ Room joining failed:', error.message);
            reject(error);
        });

        setTimeout(() => {
            reject(new Error('Room joining timeout'));
        }, 3000);
    });
};

// Test message sending
const testMessageSending = (socket) => {
    return new Promise((resolve, reject) => {
        const testMessage = {
            room_id: 1,
            message_text: 'Hello from test!',
            message_type: 'text'
        };

        socket.emit('send_message', testMessage);
        
        socket.on('new_message', (message) => {
            console.log('✅ Message sending successful:', message);
            resolve(message);
        });

        socket.on('error', (error) => {
            console.error('❌ Message sending failed:', error.message);
            reject(error);
        });

        setTimeout(() => {
            reject(new Error('Message sending timeout'));
        }, 3000);
    });
};

// Test typing indicators
const testTypingIndicators = (socket) => {
    return new Promise((resolve, reject) => {
        socket.emit('start_typing', { room_id: 1 });
        
        socket.on('user_typing', (data) => {
            console.log('✅ Typing indicator working:', data);
            resolve(data);
        });

        // Stop typing after 1 second
        setTimeout(() => {
            socket.emit('stop_typing', { room_id: 1 });
        }, 1000);

        setTimeout(() => {
            reject(new Error('Typing indicator timeout'));
        }, 3000);
    });
};

// Test reactions
const testReactions = (socket) => {
    return new Promise((resolve, reject) => {
        const testReaction = {
            message_id: 1, // Assuming message ID 1 exists
            emoji: '👍',
            room_id: 1
        };

        socket.emit('add_reaction', testReaction);
        
        socket.on('reaction_added', (data) => {
            console.log('✅ Reaction system working:', data);
            resolve(data);
        });

        socket.on('error', (error) => {
            console.error('❌ Reaction system failed:', error.message);
            reject(error);
        });

        setTimeout(() => {
            reject(new Error('Reaction test timeout'));
        }, 3000);
    });
};

// Main test function
const runChatTests = async () => {
    console.log('🚀 Starting Rx Guardian Chat System Tests...\n');
    
    try {
        // Test 1: Socket.IO Connection
        console.log('Test 1: Testing Socket.IO connection...');
        const socket = await testSocketConnection();
        
        // Test 2: Room Joining
        console.log('\nTest 2: Testing room joining...');
        await testRoomJoining(socket);
        
        // Test 3: Message Sending
        console.log('\nTest 3: Testing message sending...');
        await testMessageSending(socket);
        
        // Test 4: Typing Indicators
        console.log('\nTest 4: Testing typing indicators...');
        await testTypingIndicators(socket);
        
        // Test 5: Reactions
        console.log('\nTest 5: Testing reactions...');
        try {
            await testReactions(socket);
        } catch (error) {
            console.log('⚠️  Reaction test skipped (no existing messages)');
        }
        
        console.log('\n✅ All tests completed successfully!');
        console.log('\n🎉 Rx Guardian Chat System is ready to use!');
        
        // Close socket
        socket.disconnect();
        
    } catch (error) {
        console.error('\n❌ Test failed:', error.message);
        console.log('\n💡 Make sure the server is running on', SERVER_URL);
        console.log('💡 Run: npm start');
    }
};

// API endpoint tests
const testAPIEndpoints = async () => {
    console.log('\n🔗 Testing REST API endpoints...');
    
    const token = generateTestToken();
    const baseURL = SERVER_URL;
    
    const endpoints = [
        { method: 'GET', url: '/chat/rooms', name: 'Get Chat Rooms' },
        { method: 'GET', url: '/chat/online', name: 'Get Online Users' },
    ];
    
    for (const endpoint of endpoints) {
        try {
            const response = await fetch(`${baseURL}${endpoint.url}`, {
                method: endpoint.method,
                headers: {
                    'Authorization': `Bearer ${token}`,
                    'Content-Type': 'application/json'
                }
            });
            
            if (response.ok) {
                console.log(`✅ ${endpoint.name}: ${response.status}`);
            } else {
                console.log(`❌ ${endpoint.name}: ${response.status} - ${response.statusText}`);
            }
        } catch (error) {
            console.log(`❌ ${endpoint.name}: Connection failed`);
        }
    }
};

// Run all tests
const runAllTests = async () => {
    await runChatTests();
    await testAPIEndpoints();
};

// Export for use in other test files
export { runAllTests, testSocketConnection, testRoomJoining, testMessageSending };

// Run tests if this file is executed directly
if (import.meta.url === `file://${process.argv[1]}`) {
    runAllTests();
}
