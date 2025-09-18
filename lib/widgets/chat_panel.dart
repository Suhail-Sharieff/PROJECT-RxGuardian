import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

import '../controllers/auth_controller.dart';
import '../network/network_constants.dart';

// ======================================================================
// 1. DATA MODELS
// ======================================================================

class ChatMessage {
  final int messageId;
  final int roomId;
  final int senderId;
  final String senderName;
  final String messageText;
  final DateTime createdAt;
  final bool isOwnMessage;

  ChatMessage({
    required this.messageId,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.messageText,
    required this.createdAt,
    this.isOwnMessage = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, int currentUserId) {
    return ChatMessage(
      messageId: json['message_id'],
      roomId: json['room_id'],
      senderId: json['sender_id'],
      senderName: json['sender_name'] ?? 'Unknown User',
      messageText: json['message_text'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      isOwnMessage: json['sender_id'] == currentUserId,
    );
  }
}

class ChatRoom {
  final int roomId;
  final String roomName;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderName;

  ChatRoom({
    required this.roomId,
    required this.roomName,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderName,
  });

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      roomId: json['room_id'],
      roomName: json['room_name'],
      lastMessage: json['last_message'],
      lastMessageTime: json['last_message_time'] != null
          ? DateTime.parse(json['last_message_time'])
          : null,
      lastMessageSenderName: json['last_message_sender_name'],
    );
  }
}


// NEW: Data model for a room member
class RoomMember {
  final int pharmacistId;
  final String name;
  final String onlineStatus;
  final bool isAdmin;
  final RxBool isMuted; // Use RxBool to make it reactive for the UI

  RoomMember({
    required this.pharmacistId,
    required this.name,
    required this.onlineStatus,
    required this.isAdmin,
    required bool isMuted,
  }) : isMuted = isMuted.obs;

  factory RoomMember.fromJson(Map<String, dynamic> json) {
    return RoomMember(
      pharmacistId: json['pharmacist_id'],
      name: json['name'] ?? 'Unknown Member',
      onlineStatus: json['online_status'] ?? 'offline',
      isAdmin: json['is_admin'] == 1,
      isMuted: json['is_muted'] == 1,
    );
  }
}

// NEW: Data model for an employee (potential member)
class Employee {
  final int pharmacistId;
  final String name;

  Employee({required this.pharmacistId, required this.name});

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      pharmacistId: json['pharmacist_id'],
      name: json['name'],
    );
  }
}


// ======================================================================
// 2. GETX CONTROLLERS
// ======================================================================

class ChatController extends GetxController {
  late IO.Socket socket;
  final AuthController authController = Get.find();

  var rooms = <ChatRoom>[].obs;
  var isLoadingRooms = true.obs;
  var selectedRoom = Rx<ChatRoom?>(null);

  @override
  void onInit() {
    super.onInit();
    _connectToSocket();
    fetchRooms();
  }

  void _connectToSocket() {
    final token = authController.accessToken;
    socket = IO.io('http://$main_uri', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token},
    });

    socket.onConnect((_) => print('Chat socket connected'));
    socket.onDisconnect((_) => print('Chat socket disconnected'));
  }

  Future<void> createRoom(String roomName) async {
    Get.dialog(const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final url = Uri.http(main_uri, '/chat/rooms');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${authController.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'room_name': roomName,
          'room_type': 'general',
        }),
      );

      Get.back();

      if (response.statusCode == 201) {
        Get.snackbar('Success', 'Room "$roomName" created successfully!');
        fetchRooms();
      } else {
        final error = jsonDecode(response.body)['message'];
        Get.snackbar('Error', 'Failed to create room: $error');
      }
    } catch (e) {
      Get.back();
      Get.snackbar('Error', 'An error occurred: $e');
    }
  }

  Future<void> fetchRooms() async {
    try {
      isLoadingRooms.value = true;
      final url = Uri.http(main_uri, '/chat/rooms');
      final res = await http.get(url, headers: {'Authorization': 'Bearer ${authController.accessToken}'});

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body)['data'];
        rooms.value = data.map((json) => ChatRoom.fromJson(json)).toList();
      } else {
        Get.snackbar('Error', 'Failed to load chat rooms.');
      }
    } catch (e) {
      Get.snackbar('Error', 'An error occurred while fetching rooms: $e');
    } finally {
      isLoadingRooms.value = false;
    }
  }

  void selectRoom(ChatRoom room) {
    selectedRoom.value = room;
    Get.put(ChatRoomController(room: room), tag: room.roomId.toString());
  }

  void deselectRoom() {
    final currentRoom = selectedRoom.value;
    if (currentRoom != null) {
      Get.delete<ChatRoomController>(tag: currentRoom.roomId.toString());
    }
    selectedRoom.value = null;
  }

  @override
  void onClose() {
    socket.dispose();
    super.onClose();
  }
}


class ChatRoomController extends GetxController {
  final ChatRoom room;
  ChatRoomController({required this.room});

  final ChatController _chatController = Get.find();
  final AuthController _authController = Get.find();

  var messages = <ChatMessage>[].obs;
  var isLoadingMessages = true.obs;
  var typingUsers = <String>[].obs;

  // State for member management
  var members = <RoomMember>[].obs;
  var isLoadingMembers = true.obs;

  final messageTextController = TextEditingController();
  final scrollController = ScrollController();
  Timer? _typingTimer;

  @override
  void onInit() {
    super.onInit();
    _joinRoomAndFetchMessages();
    fetchRoomMembers(); // Fetch members when entering the room
    _setupSocketListeners();
  }

  Future<void> _joinRoomAndFetchMessages() async {
    try {
      isLoadingMessages.value = true;
      _chatController.socket.emit('join_room', {'room_id': room.roomId});

      final url = Uri.http(main_uri, '/chat/rooms/${room.roomId}/messages', {'limit': '50'});
      final res = await http.get(url, headers: {'Authorization': 'Bearer ${_authController.accessToken}'});

      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body)['data'];
        final currentUserId = _authController.user.value?.id;
        if (currentUserId == null) return;
        messages.value = data.map((msg) => ChatMessage.fromJson(msg, currentUserId)).toList();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load messages: $e');
    } finally {
      isLoadingMessages.value = false;
      _scrollToBottom();
    }
  }

  void _setupSocketListeners() {
    // Listener for new incoming messages
    _chatController.socket.on('new_message', (data) {
      final currentUserId = _authController.user.value?.id;
      if (currentUserId == null) return;

      final newMessage = ChatMessage.fromJson(data, currentUserId);
      if (newMessage.roomId == room.roomId) {
        messages.insert(0, newMessage);
        _scrollToBottom();
      }
    });

    // Listener for typing indicators
    _chatController.socket.on('user_typing', (data) {
      if (data['room_id'] == room.roomId) {
        final name = data['name'];
        if (data['is_typing'] && !typingUsers.contains(name)) {
          typingUsers.add(name);
        } else {
          typingUsers.remove(name);
        }
      }
    });

    // Listener for error messages from the server (e.g., "You are muted")
    _chatController.socket.on('error', (data) {
      if (data is Map<String, dynamic> && data.containsKey('message')) {
        Get.snackbar(
          "Message Not Sent",
          data['message'],
          backgroundColor: Colors.redAccent,
          colorText: Colors.white,
          snackPosition: SnackPosition.BOTTOM,
        );
      }
    });
  }

  void sendMessage() {
    final text = messageTextController.text.trim();
    if (text.isNotEmpty) {
      _chatController.socket.emit('send_message', {
        'room_id': room.roomId,
        'message_text': text,
        'message_type': 'text',
      });
      messageTextController.clear();
      _chatController.socket.emit('stop_typing', {'room_id': room.roomId});
      _typingTimer?.cancel();
      _scrollToBottom();
    }
  }

  Future<void> fetchRoomMembers() async {
    try {
      isLoadingMembers.value = true;
      final url = Uri.http(main_uri, '/chat/rooms/${room.roomId}/members');
      final response = await http.get(url, headers: {'Authorization': 'Bearer ${_authController.accessToken}'});

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['data'];
        members.value = data.map((json) => RoomMember.fromJson(json)).toList();
      } else {
        Get.snackbar('Error', 'Could not fetch room members.');
      }
    } catch (e) {
      Get.snackbar('Error', 'An error occurred: $e');
    } finally {
      isLoadingMembers.value = false;
    }
  }

  Future<void> addMember(int pharmacistId) async {
    try {
      final url = Uri.http(main_uri, '/chat/rooms/${room.roomId}/addMemberToRoom');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer ${_authController.accessToken}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'pharmacist_id': pharmacistId}),
      );

      if (response.statusCode == 200) {
        Get.snackbar('Success', 'Member added successfully.');
        fetchRoomMembers(); // Refresh the list
      } else {
        final error = jsonDecode(response.body)['message'];
        Get.snackbar('Error', 'Failed to add member: $error');
      }
    } catch (e) {
      Get.snackbar('Error', 'An error occurred: $e');
    }
  }

  Future<void> removeMember(int pharmacistId) async {
    try {
      final url = Uri.http(main_uri, '/chat/rooms/${room.roomId}/members/$pharmacistId/removeMemberFromRoom');
      final response = await http.delete(url, headers: {'Authorization': 'Bearer ${_authController.accessToken}'});

      if (response.statusCode == 200) {
        Get.snackbar('Success', 'Member removed successfully.');
        members.removeWhere((m) => m.pharmacistId == pharmacistId); // Optimistic UI update
      } else {
        final error = jsonDecode(response.body)['message'];
        Get.snackbar('Error', 'Failed to remove member: $error');
      }
    } catch (e) {
      Get.snackbar('Error', 'An error occurred: $e');
    }
  }

  Future<void> toggleMuteStatus(RoomMember member) async {
    final bool shouldMute = !member.isMuted.value;
    final String action = shouldMute ? 'mute' : 'unmute';

    try {
      final url = Uri.http(main_uri, '/chat/rooms/${room.roomId}/members/${member.pharmacistId}/$action');
      final response = await http.patch(url, headers: {'Authorization': 'Bearer ${_authController.accessToken}'});

      if (response.statusCode == 200) {
        member.isMuted.value = shouldMute; // Update the UI reactively
        Get.snackbar('Success', 'Member status updated.');
      } else {
        final error = jsonDecode(response.body)['message'];
        Get.snackbar('Error', 'Failed to update status: $error');
      }
    } catch (e) {
      Get.snackbar('Error', 'An error occurred: $e');
    }
  }

  void startTyping() {
    _chatController.socket.emit('start_typing', {'room_id': room.roomId});
    _debounceStopTyping();
  }

  void _debounceStopTyping() {
    _typingTimer?.cancel();
    _typingTimer = Timer(const Duration(seconds: 2), () {
      _chatController.socket.emit('stop_typing', {'room_id': room.roomId});
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (scrollController.hasClients) {
        scrollController.animateTo(
          0.0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void onClose() {
    // Clean up all socket listeners to prevent memory leaks
    _chatController.socket.emit('leave_room', {'room_id': room.roomId});
    _chatController.socket.off('new_message');
    _chatController.socket.off('user_typing');
    _chatController.socket.off('error'); // Ensure the error listener is removed

    // Dispose controllers
    messageTextController.dispose();
    scrollController.dispose();
    _typingTimer?.cancel();
    super.onClose();
  }
}
// ======================================================================
// 3. UI WIDGETS
// ======================================================================

class ChatSidebar extends StatelessWidget {
  const ChatSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatController controller = Get.put(ChatController());
    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(left: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Obx(() {
        if (controller.selectedRoom.value == null) {
          return const RoomListView();
        } else {
          return const ChatRoomView();
        }
      }),
    );
  }
}
class RoomListView extends StatelessWidget {
  const RoomListView({super.key});

  void _showCreateRoomDialog(BuildContext context) {
    final ChatController controller = Get.find();
    final TextEditingController nameController = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('Create New Chat Room'),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Room Name',
            hintText: 'e.g., General Discussion',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final roomName = nameController.text.trim();
              if (roomName.isNotEmpty) {
                Get.back();
                controller.createRoom(roomName);
              } else {
                Get.snackbar('Invalid Name', 'Room name cannot be empty.');
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChatController controller = Get.find();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Chat Rooms", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: () => _showCreateRoomDialog(context),
                tooltip: 'Create a new room',
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: Obx(() {
            if (controller.isLoadingRooms.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.rooms.isEmpty) {
              return const Center(child: Text("No rooms available. Create one!"));
            }
            return ListView.builder(
              itemCount: controller.rooms.length,
              itemBuilder: (context, index) {
                final room = controller.rooms[index];
                final lastMessage = room.lastMessage ?? 'No messages yet.';
                final senderName = room.lastMessageSenderName != null ? '${room.lastMessageSenderName}: ' : '';

                return ListTile(
                  leading: const Icon(Icons.chat_bubble_outline),
                  title: Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    '$senderName$lastMessage',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: room.lastMessageTime != null
                      ? Text(
                    DateFormat('h:mm a').format(room.lastMessageTime!.toLocal()),
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  )
                      : null,
                  onTap: () => controller.selectRoom(room),
                );
              },
            );
          }),
        ),
      ],
    );
  }
}
class ChatRoomView extends StatelessWidget {
  const ChatRoomView({super.key});

  // MODIFIED: Added method to show the member management bottom sheet
  void _showMemberManagement(BuildContext context) {
    Get.bottomSheet(
      const MemberManagementSheet(),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChatController mainController = Get.find();
    final ChatRoomController roomController = Get.find(tag: mainController.selectedRoom.value!.roomId.toString());

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          color: Theme.of(context).appBarTheme.backgroundColor,
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => mainController.deselectRoom()),
              Expanded(
                child: Text(
                  roomController.room.roomName,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              // MODIFIED: Added button to open member management
              IconButton(
                icon: const Icon(Icons.group_outlined),
                onPressed: () => _showMemberManagement(context),
                tooltip: 'Manage Members',
              ),
            ],
          ),
        ),
        Expanded(
          child: Obx(() {
            if (roomController.isLoadingMessages.value) {
              return const Center(child: CircularProgressIndicator());
            }
            return ListView.builder(
              controller: roomController.scrollController,
              reverse: true,
              padding: const EdgeInsets.all(8.0),
              itemCount: roomController.messages.length,
              itemBuilder: (context, index) {
                final message = roomController.messages[index];
                return MessageBubble(message: message);
              },
            );
          }),
        ),
        Obx(() {
          if (roomController.typingUsers.isEmpty) return const SizedBox.shrink();
          final names = roomController.typingUsers.join(', ');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text("$names is typing...", style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.grey)),
          );
        }),
        const MessageInput(),
      ],
    );
  }
}
// ... (MessageBubble and MessageInput remain the same)
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final isOwn = message.isOwnMessage;
    return Align(
      alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isOwn ? Theme.of(context).primaryColor : Colors.grey.shade200,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: isOwn ? const Radius.circular(16) : Radius.zero,
            bottomRight: isOwn ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isOwn)
              Text(
                message.senderName,
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.deepPurple, fontSize: 13),
              ),
            Text(
              message.messageText,
              style: TextStyle(color: isOwn ? Colors.white : Colors.black87),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.bottomRight,
              child: Text(
                DateFormat('h:mm a').format(message.createdAt.toLocal()),
                style: TextStyle(fontSize: 10, color: isOwn ? Colors.white70 : Colors.black54),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class MessageInput extends StatelessWidget {
  const MessageInput({super.key});

  @override
  Widget build(BuildContext context) {
    final ChatController mainController = Get.find();
    final ChatRoomController roomController = Get.find(tag: mainController.selectedRoom.value!.roomId.toString());

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: roomController.messageTextController,
              decoration: const InputDecoration(
                hintText: "Type a message...",
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(horizontal: 16),
              ),
              onChanged: (_) => roomController.startTyping(),
              onSubmitted: (_) => roomController.sendMessage(),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.send),
            onPressed: roomController.sendMessage,
            color: Theme.of(context).primaryColor,
          ),
        ],
      ),
    );
  }
}

// NEW: Member Management Sheet Widget
class MemberManagementSheet extends StatelessWidget {
  const MemberManagementSheet({super.key});

  // Helper to show the add member dialog
  Future<void> _showAddMemberDialog(BuildContext context) async {
    final AuthController authController = Get.find();
    final ChatController mainController = Get.find();
    final ChatRoomController roomController = Get.find(tag: mainController.selectedRoom.value!.roomId.toString());

    // 1. Fetch all employees
    List<Employee> allEmployees = [];
    try {
      final url = Uri.http(main_uri, '/manager/getEmployeesOfMyShop');
      final res = await http.get(url, headers: {'Authorization': 'Bearer ${authController.accessToken}'});
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body)['data'];
        allEmployees = data.map((json) => Employee.fromJson(json)).toList();
      } else {
        Get.snackbar('Error', 'Could not fetch employee list.');
        return;
      }
    } catch (e) {
      Get.snackbar('Error', 'An error occurred fetching employees.');
      return;
    }

    // 2. Filter out employees who are already members
    final currentMemberIds = roomController.members.map((m) => m.pharmacistId).toSet();
    final availableEmployees = allEmployees.where((emp) => !currentMemberIds.contains(emp.pharmacistId)).toList();

    if (availableEmployees.isEmpty) {
      Get.snackbar('Info', 'All employees are already in this room.');
      return;
    }

    // 3. Show the dialog
    Get.dialog(
      AlertDialog(
        title: const Text('Add Member'),
        content: SizedBox(
          width: 300,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableEmployees.length,
            itemBuilder: (context, index) {
              final employee = availableEmployees[index];
              return ListTile(
                title: Text(employee.name),
                onTap: () {
                  Get.back(); // Close dialog
                  roomController.addMember(employee.pharmacistId);
                },
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: () => Get.back(), child: const Text('Cancel'))],
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    final ChatController mainController = Get.find();
    final ChatRoomController roomController = Get.find(tag: mainController.selectedRoom.value!.roomId.toString());
    final AuthController authController = Get.find();
    final int? currentUserId = authController.user.value?.id;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Room Members (${roomController.members.length})",
                      style: Theme.of(context).textTheme.titleLarge),
                  FilledButton.tonalIcon(
                    onPressed: () => _showAddMemberDialog(context),
                    icon: const Icon(Icons.person_add_alt_1),
                    label: const Text('Add'),
                  )
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                if (roomController.isLoadingMembers.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  controller: scrollController,
                  itemCount: roomController.members.length,
                  itemBuilder: (context, index) {
                    final member = roomController.members[index];
                    final isSelf = member.pharmacistId == currentUserId;

                    return ListTile(
                      leading: CircleAvatar(
                        child: Text(member.name.substring(0, 1)),
                      ),
                      title: Text(member.name + (isSelf ? ' (You)' : '')),
                      subtitle: Text(member.onlineStatus,
                          style: TextStyle(
                              color: member.onlineStatus == 'online'
                                  ? Colors.green
                                  : Colors.grey)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Obx(() => Icon(
                            member.isMuted.value ? Icons.volume_off : Icons.volume_up,
                            color: member.isMuted.value ? Colors.red : Colors.grey,
                          )),
                          if (!isSelf)
                            PopupMenuButton<String>(
                              onSelected: (value) {
                                if (value == 'mute') {
                                  roomController.toggleMuteStatus(member);
                                } else if (value == 'remove') {
                                  roomController.removeMember(member.pharmacistId);
                                }
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                PopupMenuItem<String>(
                                  value: 'mute',
                                  child: Obx(() => Text(member.isMuted.value ? 'Unmute Member' : 'Mute Member')),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'remove',
                                  child: Text('Remove Member', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                        ],
                      ),
                    );
                  },
                );
              }),
            ),
          ],
        );
      },
    );
  }
}