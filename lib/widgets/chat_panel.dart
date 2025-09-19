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
  final RxList<MessageReaction> reactions;
  final String? replyToMessageText;
  final String? replyToSenderName;
  ChatMessage({
    required this.messageId,
    required this.roomId,
    required this.senderId,
    required this.senderName,
    required this.messageText,
    required this.createdAt,
    this.isOwnMessage = false,
    List<MessageReaction>? initialReactions,
    this.replyToMessageText, // Add to constructor
    this.replyToSenderName,  // Add to constructor
  }) : reactions = (initialReactions ?? []).obs;
  factory ChatMessage.fromJson(Map<String, dynamic> json, int currentUserId) {
    // Parse the list of reactions from the API response
    var reactionsList = <MessageReaction>[];
    if (json['reactions'] != null) {
      reactionsList = (json['reactions'] as List)
          .map((r) => MessageReaction.fromJson(r))
          .toList();
    }

    return ChatMessage(
      messageId: json['message_id'],
      roomId: json['room_id'],
      senderId: json['sender_id'],
      senderName: json['sender_name'] ?? 'Unknown User',
      messageText: json['message_text'] ?? '',
      createdAt: DateTime.parse(json['created_at']),
      isOwnMessage: json['sender_id'] == currentUserId,
      initialReactions: reactionsList, // <-- PASS THE PARSED LIST
      replyToMessageText: json['reply_to_message_text'], // <-- ADD THIS
      replyToSenderName: json['reply_to_sender_name'],
    );
  }
}
class ChatRoom {
  final int roomId;
  final String roomName;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final String? lastMessageSenderName;
  final int unreadCount; // <-- ADD THIS LINE

  ChatRoom({
    required this.roomId,
    required this.roomName,
    this.lastMessage,
    this.lastMessageTime,
    this.lastMessageSenderName,
    this.unreadCount = 0, // <-- ADD THIS with a default value
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
      // Parse the new field from the API response
      unreadCount: json['unread_count'] ?? 0, // <-- ADD THIS LINE
    );
  }
}
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

  // In ChatController
  void selectRoom(ChatRoom room) {
    // 1. Tell the server that we are now reading this room
    socket.emit('mark_room_as_read', {'room_id': room.roomId});

    // 2. Update the UI instantly (Optimistic Update)
    // Find the room in the list and set its unread count to 0
    final index = rooms.indexWhere((r) => r.roomId == room.roomId);
    if (index != -1 && rooms[index].unreadCount > 0) {
      // Create a new instance with the updated count
      rooms[index] = ChatRoom(
          roomId: room.roomId,
          roomName: room.roomName,
          lastMessage: room.lastMessage,
          lastMessageTime: room.lastMessageTime,
          lastMessageSenderName: room.lastMessageSenderName,
          unreadCount: 0 // Set to 0
      );
      // Notify GetX that the list has changed
      rooms.refresh();
    }

    // 3. Proceed to open the chat room
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
  var replyingToMessage = Rx<ChatMessage?>(null);

  var messages = <ChatMessage>[].obs;
  var isLoadingMessages = true.obs;
  var typingUsers = <String>[].obs;

  // State for member management
  var members = <RoomMember>[].obs;
  var isLoadingMembers = true.obs;

  final messageTextController = TextEditingController();
  final scrollController = ScrollController();
  Timer? _typingTimer;
  void setReplyingTo(ChatMessage message) {
    replyingToMessage.value = message;
  }

  // NEW: Method to cancel the reply
  void cancelReply() {
    replyingToMessage.value = null;
  }
  @override
  void onInit() {
    super.onInit();
    _joinRoomAndFetchMessages();
    fetchRoomMembers(); // Fetch members when entering the room
    _setupSocketListeners();
  }
  // In ChatRoomController
  void addReaction(int messageId, String emoji) {
    _chatController.socket.emit('add_reaction', {
      'message_id': messageId,
      'emoji': emoji,
      'room_id': room.roomId,
    });
    // Note: We will handle the UI update in the listener to ensure consistency.
  }

  void removeReaction(int messageId) {
    _chatController.socket.emit('remove_reaction', {
      'message_id': messageId,
      'room_id': room.roomId,
    });
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
        messages.value = data.map((msg) => ChatMessage.fromJson(msg, currentUserId)).toList().reversed.toList();
      }
    } catch (e) {
      Get.snackbar('Error', 'Failed to load messages: $e');
    } finally {
      isLoadingMessages.value = false;
      _scrollToBottom();
    }
  }

  void _setupSocketListeners() {
    _chatController.socket.on('new_message', (data) {
      final currentUserId = _authController.user.value?.id;
      if (currentUserId == null) return;

      final newMessage = ChatMessage.fromJson(data, currentUserId);
      if (newMessage.roomId == room.roomId) {
        messages.insert(0, newMessage);
        _scrollToBottom();
      }
    });

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

    // NEW: Listen for added reactions
    _chatController.socket.on('reaction_added', (data) {
      final int messageId = data['message_id'];
      final int reactingUserId = data['pharmacist_id'];
      final newReaction = MessageReaction(
        pharmacistId: reactingUserId,
        pharmacistName: data['name'],
        emoji: data['emoji'],
      );

      // Find the message in the list
      final message = messages.firstWhereOrNull((m) => m.messageId == messageId);
      if (message != null) {
        // Remove any previous reaction from this user, then add the new one
        message.reactions.removeWhere((r) => r.pharmacistId == reactingUserId);
        message.reactions.add(newReaction);
      }
    });

    // NEW: Listen for removed reactions
    _chatController.socket.on('reaction_removed', (data) {
      final int messageId = data['message_id'];
      final int reactingUserId = data['pharmacist_id'];

      // Find the message in the list
      final message = messages.firstWhereOrNull((m) => m.messageId == messageId);
      if (message != null) {
        // Remove the reaction from this user
        message.reactions.removeWhere((r) => r.pharmacistId == reactingUserId);
      }
    });
  }
// In ChatRoomController
  void sendMessage() {
    final text = messageTextController.text.trim();
    if (text.isNotEmpty) {
      // Create the payload
      final payload = {
        'room_id': room.roomId,
        'message_text': text,
        'message_type': 'text',
      };

      // If we are replying, add the ID to the payload
      if (replyingToMessage.value != null) {
        payload['reply_to_message_id'] = replyingToMessage.value!.messageId;
      }

      _chatController.socket.emit('send_message', payload);

      messageTextController.clear();
      // Important: Cancel the reply mode after sending
      cancelReply();
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
        fetchRoomMembers();
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
        members.removeWhere((m) => m.pharmacistId == pharmacistId);
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
        member.isMuted.value = shouldMute;
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
    _typingTimer = Timer(const Duration(seconds: 4), () {
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
    _chatController.socket.emit('leave_room', {'room_id': room.roomId});
    _chatController.socket.off('new_message');
    _chatController.socket.off('user_typing');
    _chatController.socket.off('error');

    messageTextController.dispose();
    scrollController.dispose();
    _typingTimer?.cancel();
    super.onClose();
  }
}


// ======================================================================
// 3. THEME & STYLING
// ======================================================================

class AppColors {
  static const primaryColor = Color(0xFF005cb2);
  static const secondaryColor = Color(0xFF7986CB);
  static const accentColor = Color(0xFF00bcd4);

  static const ownMessageBubble = primaryColor;
  static const otherMessageBubbleLight = Color(0xFFE3F2FD);
  static const otherMessageBubbleDark = Color(0xFF263238);

  static const backgroundLight = Color(0xFFF5F7FA);
  static const backgroundDark = Color(0xFF121212);
  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF1E1E1E);

  static const textLight = Colors.black87;
  static const textDark = Colors.white;
  static const textSecondaryLight = Colors.black54;
  static const textSecondaryDark = Colors.white60;
}

class AppThemes {
  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: AppColors.primaryColor,
    scaffoldBackgroundColor: AppColors.backgroundLight,
    cardColor: AppColors.cardLight,
    dividerColor: Colors.grey.shade200,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primaryColor,
      secondary: AppColors.secondaryColor,
      onPrimary: Colors.white,
      surface: AppColors.cardLight,
      onSurface: AppColors.textLight,
      background: AppColors.backgroundLight,
      onBackground: AppColors.textLight,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.cardLight,
      elevation: 0,
      iconTheme: IconThemeData(color: AppColors.textLight),
      titleTextStyle: TextStyle(
          color: AppColors.textLight,
          fontSize: 20,
          fontWeight: FontWeight.w600),
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: AppColors.textLight),
      bodyMedium: TextStyle(color: AppColors.textSecondaryLight),
      titleLarge: TextStyle(
          color: AppColors.textLight, fontWeight: FontWeight.bold),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.all(AppColors.primaryColor),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      ),
    ),
  );
}

String formatTimestamp(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = DateTime(now.year, now.month, now.day - 1);
  final date = DateTime(dt.year, dt.month, dt.day);

  if (date == today) {
    return DateFormat('h:mm a').format(dt.toLocal());
  } else if (date == yesterday) {
    return 'Yesterday';
  } else {
    return DateFormat('dd/MM/yy').format(dt.toLocal());
  }
}

// ======================================================================
// 4. UI WIDGETS
// ======================================================================

class ChatSidebar extends StatelessWidget {
  const ChatSidebar({super.key});

  @override
  Widget build(BuildContext context) {
    Get.put(ChatController());

    return Container(
      width: 350,
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(right: BorderSide(color: Theme.of(context).dividerColor)),
      ),
      child: Obx(() {
        final controller = Get.find<ChatController>();
        if (controller.selectedRoom.value == null) {
          return const RoomListView();
        } else {
          final roomController = Get.find<ChatRoomController>(tag: controller.selectedRoom.value!.roomId.toString());
          return ChatRoomView(controller: roomController);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: TextField(
          controller: nameController,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'Room Name',
            hintText: 'e.g., Pharmacy Team',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        actions: [
          TextButton(onPressed: Get.back, child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (nameController.text.trim().isNotEmpty) {
                Get.back();
                controller.createRoom(nameController.text.trim());
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
    final theme = Theme.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Conversations", style: theme.textTheme.titleLarge?.copyWith(fontSize: 22)),
              IconButton(
                icon: const Icon(Icons.add_comment_outlined),
                onPressed: () => _showCreateRoomDialog(context),
                tooltip: 'Create a new room',
                style: IconButton.styleFrom(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                    foregroundColor: theme.colorScheme.primary
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1, thickness: 1),
        Expanded(
          child: Obx(() {
            if (controller.isLoadingRooms.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.rooms.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    "No chat rooms found.\nTap the '+' button to start a conversation!",
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: controller.rooms.length,
              // In RoomListView -> ListView.builder
              itemBuilder: (context, index) {
                final room = controller.rooms[index];
                final isSelected = controller.selectedRoom.value?.roomId == room.roomId;

                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? theme.primaryColor.withOpacity(0.1) : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: theme.primaryColor.withOpacity(isSelected ? 0.8 : 0.6),
                      foregroundColor: Colors.white,
                      child: Text(room.roomName.substring(0, 1).toUpperCase()),
                    ),
                    title: Text(room.roomName, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                      '${room.lastMessageSenderName != null ? '${room.lastMessageSenderName}: ' : ''}${room.lastMessage ?? 'No messages yet.'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // --- 👇 UPDATE THE trailing WIDGET LIKE THIS ---
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (room.lastMessageTime != null)
                          Text(
                            formatTimestamp(room.lastMessageTime!),
                            style: TextStyle(fontSize: 12, color: theme.textTheme.bodyMedium?.color),
                          ),
                        const SizedBox(height: 4),
                        // --- THIS IS THE NEW UNREAD BADGE ---
                        if (room.unreadCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: theme.primaryColor,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Container(
                              padding: const EdgeInsets.all(4), // space inside circle
                              decoration: const BoxDecoration(
                                color: Colors.red, // background color of circle
                                shape: BoxShape.circle,
                              ),
                              child: Text(
                                room.unreadCount.toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            )
                            ,
                          )
                        else
                        // Use a placeholder to keep alignment consistent when there's no badge
                          const SizedBox(height: 18),
                      ],
                    ),
                    onTap: () => controller.selectRoom(room),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
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
  final ChatRoomController controller;
  const ChatRoomView({super.key, required this.controller});

  void _showMemberManagement(BuildContext context) {
    Get.bottomSheet(
      MemberManagementSheet(controller: controller),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final ChatController mainController = Get.find();
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 12.0),
          decoration: BoxDecoration(
            color: theme.cardColor,
            border: Border(bottom: BorderSide(color: theme.dividerColor)),
          ),
          child: Row(
            children: [
              IconButton(icon: const Icon(Icons.arrow_back_ios_new), onPressed: mainController.deselectRoom),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  controller.room.roomName,
                  style: theme.textTheme.titleLarge?.copyWith(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
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
            if (controller.isLoadingMessages.value) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.messages.isEmpty){
              return const Center(child: Text("Say hello! ✨"));
            }
            return ListView.builder(
              controller: controller.scrollController,
              reverse: true,
              padding: const EdgeInsets.all(16.0),
              itemCount: controller.messages.length,
              itemBuilder: (context, index) {
                final message = controller.messages[index];
                return MessageBubble(message: message);
              },
            );
          }),
        ),
        Obx(() {
          if (controller.typingUsers.isEmpty) return const SizedBox.shrink();
          final names = controller.typingUsers.join(', ');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
            child: Text(
              "$names is typing...",
              style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
            ),
          );
        }),
        Obx(() {
          final replyingTo = controller.replyingToMessage.value;
          if (replyingTo == null) return const SizedBox.shrink();

          return Container(
            padding: const EdgeInsets.all(8),
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            ),
            child: Row(
              children: [
                Container(width: 4, height: 40, color: theme.primaryColor, margin: const EdgeInsets.only(right: 8)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        replyingTo.senderName,
                        style: TextStyle(fontWeight: FontWeight.bold, color: theme.primaryColor),
                      ),
                      Text(
                        replyingTo.messageText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: controller.cancelReply,
                )
              ],
            ),
          );
        }),
        // --- END OF REPLY PREVIEW BAR ---
        MessageInput(controller: controller),
      ],
    );
  }
}

// Assuming your data models (ChatMessage, etc.) and controllers are imported correctly.
// Also assuming AppColors is defined as in previous examples.
class MessageBubble extends StatelessWidget {
  final ChatMessage message;
  const MessageBubble({super.key, required this.message});

  // Helper method to show the reaction dialog
  void _showReactionDialog(BuildContext context) {
    // HERE IS THE FIX 👇
    final controller = Get.find<ChatRoomController>(tag: message.roomId.toString());

    final List<String> emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];
    final int? currentUserId = Get.find<AuthController>().user.value?.id;
    final hasUserReacted = message.reactions.any((r) => r.pharmacistId == currentUserId);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('React to message'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Wrap(
          spacing: 8.0,
          alignment: WrapAlignment.center,
          children: emojis.map((emoji) => IconButton(
            icon: Text(emoji, style: const TextStyle(fontSize: 24)),
            onPressed: () {
              controller.addReaction(message.messageId, emoji);
              Get.back();
            },
          )).toList(),
        ),
        actions: [
          TextButton(
            child: const Text('Reply'),
            onPressed: () {
              controller.setReplyingTo(message);
              Get.back(); // Close the dialog
            },
          ),
          if (hasUserReacted)
            TextButton(
              child: const Text('Remove Reaction', style: TextStyle(color: Colors.red)),
              onPressed: () {
                controller.removeReaction(message.messageId);
                Get.back();
              },
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isOwn = message.isOwnMessage;
    final isDark = theme.brightness == Brightness.dark;

    return GestureDetector(
      onLongPress: () => _showReactionDialog(context),
      onSecondaryTap: () => _showReactionDialog(context),
      child: Align(
        alignment: isOwn ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.7),
          margin: const EdgeInsets.symmetric(vertical: 5),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: isOwn
                ? AppColors.ownMessageBubble
                : (isDark ? AppColors.otherMessageBubbleDark : AppColors.otherMessageBubbleLight),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(20),
              topRight: const Radius.circular(20),
              bottomLeft: isOwn ? const Radius.circular(20) : const Radius.circular(4),
              bottomRight: isOwn ? const Radius.circular(4) : const Radius.circular(20),
            ),
          ),
          child: Column(
            crossAxisAlignment: isOwn ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              if (message.replyToMessageText != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  margin: const EdgeInsets.only(bottom: 4),
                  decoration: BoxDecoration(
                    color: isOwn ? Colors.white.withOpacity(0.15) : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        message.replyToSenderName ?? 'Original Message',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          color: isOwn ? Colors.white70 : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                      Text(
                        message.replyToMessageText!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: isOwn ? Colors.white70 : theme.textTheme.bodyMedium?.color,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!isOwn)
                Text(
                  message.senderName,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                    fontSize: 13,
                  ),
                ),
              if (!isOwn) const SizedBox(height: 4),
              Text(
                message.messageText,
                style: TextStyle(
                  color: isOwn ? Colors.white : theme.textTheme.bodyLarge?.color,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                DateFormat('h:mm a').format(message.createdAt.toLocal()),
                style: TextStyle(
                  fontSize: 10,
                  color: isOwn ? Colors.white70 : theme.textTheme.bodyMedium?.color,
                ),
              ),
              Obx(() {
                if (message.reactions.isEmpty) {
                  return const SizedBox.shrink();
                }
                final reactionSummary = <String, int>{};
                for (var reaction in message.reactions) {
                  reactionSummary[reaction.emoji] = (reactionSummary[reaction.emoji] ?? 0) + 1;
                }
                return Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Wrap(
                    spacing: 6.0,
                    runSpacing: 4.0,
                    alignment: isOwn ? WrapAlignment.end : WrapAlignment.start,
                    children: reactionSummary.entries.map((entry) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: isOwn ? Colors.white.withOpacity(0.2) : theme.scaffoldBackgroundColor,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: isOwn ? Colors.transparent : theme.dividerColor)
                        ),
                        child: Text(
                          '${entry.key} ${entry.value}',
                          style: TextStyle(
                            fontSize: 12,
                            color: isOwn ? Colors.white : theme.textTheme.bodyMedium?.color,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                );
              }),
            ],
          ),
        ),
      ),
    );
  }
}

class MessageInput extends StatelessWidget {
  final ChatRoomController controller;
  const MessageInput({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textController = controller.messageTextController;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.scaffoldBackgroundColor,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: TextField(
                  controller: textController,
                  decoration: const InputDecoration(
                    hintText: "Type a message...",
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  ),
                  onChanged: (_) => controller.startTyping(),
                  onSubmitted: (_) => controller.sendMessage(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            ValueListenableBuilder<TextEditingValue>(
              valueListenable: textController,
              builder: (context, value, child) {
                return IconButton.filled(
                  icon: const Icon(Icons.send),
                  onPressed: value.text.trim().isNotEmpty ? controller.sendMessage : null,
                  style: IconButton.styleFrom(
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}


class MemberManagementSheet extends StatelessWidget {
  final ChatRoomController controller;
  const MemberManagementSheet({super.key, required this.controller});

  Future<void> _showAddMemberDialog(BuildContext context) async {
    final AuthController authController = Get.find();
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

    final currentMemberIds = controller.members.map((m) => m.pharmacistId).toSet();
    final availableEmployees = allEmployees.where((emp) => !currentMemberIds.contains(emp.pharmacistId)).toList();

    if (availableEmployees.isEmpty) {
      Get.snackbar('Info', 'All employees are already in this room.');
      return;
    }

    Get.dialog(
      AlertDialog(
        title: const Text('Add Member'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: SizedBox(
          width: 350,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: availableEmployees.length,
            itemBuilder: (context, index) {
              final employee = availableEmployees[index];
              return ListTile(
                leading: CircleAvatar(child: Text(employee.name.substring(0,1))),
                title: Text(employee.name),
                onTap: () {
                  Get.back();
                  controller.addMember(employee.pharmacistId);
                },
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              );
            },
          ),
        ),
        actions: [TextButton(onPressed: Get.back, child: const Text('Cancel'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final AuthController authController = Get.find();
    final int? currentUserId = authController.user.value?.id;

    // ✨ Find out if the current user is an admin in this room.
    final isCurrentUserAdmin = controller.members
        .firstWhere((m) => m.pharmacistId == currentUserId, orElse: () => RoomMember(pharmacistId: 0, name: '', onlineStatus: '', isAdmin: false, isMuted: false))
        .isAdmin;

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
                  Obx(() => Text("Members (${controller.members.length})", style: theme.textTheme.titleLarge)),
                  // ✨ Only show the "Add Member" button if the current user is an admin.
                  if (isCurrentUserAdmin)
                    FilledButton.tonalIcon(
                      onPressed: () => _showAddMemberDialog(context),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Add Member'),
                    )
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: Obx(() {
                if (controller.isLoadingMembers.value) {
                  return const Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  itemCount: controller.members.length,
                  itemBuilder: (context, index) {
                    final member = controller.members[index];
                    final isSelf = member.pharmacistId == currentUserId;
                    final isAdmin = member.isAdmin;

                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 0,
                      color: theme.scaffoldBackgroundColor,
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(member.name.substring(0, 1)),
                        ),
                        title: Row(
                          children: [
                            Text(member.name + (isSelf ? ' (You)' : '')),
                            if (isAdmin) const SizedBox(width: 8),
                            if(isAdmin) Icon(Icons.shield, color: theme.primaryColor, size: 16, semanticLabel: "Admin"),
                          ],
                        ),
                        subtitle: Text(
                          member.onlineStatus,
                          style: TextStyle(
                            color: member.onlineStatus == 'online' ? Colors.green.shade600 : Colors.grey,
                          ),
                        ),
                        // ✨ Only show management buttons if the current user is an admin AND the target is not themselves.
                        trailing: (isCurrentUserAdmin && !isSelf)
                            ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Obx(() => IconButton(
                              icon: Icon(
                                member.isMuted.value ? Icons.block_rounded : Icons.check_circle_sharp,
                                color: member.isMuted.value ? Colors.orange.shade700 : Colors.green,
                              ),
                              tooltip: member.isMuted.value ? 'Unmute Member' : 'Mute Member',
                              onPressed: () => controller.toggleMuteStatus(member),
                            )),
                            IconButton(
                              icon: Icon(Icons.person_remove_outlined, color: Colors.red.shade400),
                              tooltip: 'Remove Member',
                              onPressed: () => controller.removeMember(member.pharmacistId),
                            ),
                          ],
                        )
                            : null, // ✨ No actions for non-admins or for yourself
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
class MessageReaction {
  final int pharmacistId;
  final String pharmacistName;
  final String emoji;

  MessageReaction({
    required this.pharmacistId,
    required this.pharmacistName,
    required this.emoji,
  });

  factory MessageReaction.fromJson(Map<String, dynamic> json) {
    return MessageReaction(
      pharmacistId: json['pharmacist_id'],
      pharmacistName: json['name'] ?? 'Unknown',
      emoji: json['emoji'],
    );
  }
}