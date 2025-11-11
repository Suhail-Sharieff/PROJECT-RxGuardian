// lib/models/notification_model.dart

import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:get/get_rx/src/rx_types/rx_types.dart';

import 'dart:convert';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:timeago_flutter/timeago_flutter.dart' as timeago;

// Import your models and other controllers
import '../controllers/auth_controller.dart';
import '../network/network_constants.dart';
enum NotificationType { success, info, warning, error }

class Notification {
  final int id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime createdAt;
  final RxBool isRead; // Use RxBool to make it reactive

  Notification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.createdAt,
    required bool isRead,
  }) : isRead = isRead.obs;

  factory Notification.fromJson(Map<String, dynamic> json) {
    NotificationType type;
    switch (json['type']) {
      case 'success':
        type = NotificationType.success;
        break;
      case 'warning':
        type = NotificationType.warning;
        break;
      case 'error':
        type = NotificationType.error;
        break;
      default:
        type = NotificationType.info;
    }

    return Notification(
      id: json['notification_id'],
      title: json['title'] ?? 'No Title',
      message: json['message'] ?? 'No message body.',
      type: type,
      createdAt: DateTime.parse(json['created_at']),
      isRead: json['is_read']==1,
    );
  }
}
class NotificationController extends GetxController {
  final AuthController authController = Get.find();
  late IO.Socket socket;

  var notifications = <Notification>[].obs;
  var isLoading = true.obs;

  // Computed property for unread count
  int get unreadCount => notifications.where((n) => !n.isRead.value).length;

  @override
  void onInit() {
    super.onInit();
    fetchNotifications();
    _connectToSocket();
  }

  void _connectToSocket() {
    final token = authController.accessToken;
    socket = IO.io('http://$main_uri', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': true,
      'auth': {'token': token},
    });

    socket.onConnect((_) {
      print('🔔 Notification socket connected');
      _setupSocketListeners();
    });
    socket.onDisconnect((_) => print('🔔 Notification socket disconnected'));
  }

  void _setupSocketListeners() {
    // Listen for all broadcasted notification types
    ['daily_notifications', 'weekly_notifications', 'monthly_notifications', 'custom_notification']
        .forEach((event) {
      socket.on(event, (data) {
        final List<dynamic> newNotifsData = data['data'];
        final newNotifications = newNotifsData.map((notifJson) {
          // The backend needs to be consistent and send notification_id
          // For now, let's create a temporary one if missing
          if(notifJson['notification_id'] == null) {
            notifJson['notification_id'] = DateTime.now().millisecondsSinceEpoch;
          }
          if(notifJson['created_at'] == null){
            notifJson['created_at'] = DateTime.now().toIso8601String();
          }
          return Notification.fromJson(notifJson);
        }).toList();

        notifications.insertAll(0, newNotifications);
        update(); // Force update for unreadCount
      });
    });
  }

  Future<void> fetchNotifications() async {
    try {
      isLoading.value = true;
      final url = Uri.http(main_uri, '/notifications');
      final response = await http.get(url, headers: {'Authorization': 'Bearer ${authController.accessToken}'});

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body)['data'];
        notifications.value = data.map((json) => Notification.fromJson(json)).toList();
      } else {
        Get.snackbar('Error', 'Failed to load notifications. ');
      }
    } catch (e) {
      Get.snackbar('Error', 'An error occurred: $e');
      log(e.toString());
    } finally {
      isLoading.value = false;
      update(); // Update unreadCount
    }
  }

  void markAsRead(int notificationId) {
    final notification = notifications.firstWhereOrNull((n) => n.id == notificationId);
    if (notification != null && !notification.isRead.value) {
      notification.isRead.value = true;
      socket.emit('mark_notification_read', {'notification_id': notificationId});
      update(); // Update unreadCount
    }
  }

  void markAllAsRead() {
    for (var notification in notifications) {
      if (!notification.isRead.value) {
        notification.isRead.value = true;
        socket.emit('mark_notification_read', {'notification_id': notification.id});
      }
    }
    update(); // Update unreadCount
  }

  @override
  void onClose() {
    socket.dispose();
    super.onClose();
  }
}
class NotificationIcon extends StatelessWidget {
  const NotificationIcon({super.key});

  @override
  Widget build(BuildContext context) {
    // Initialize the controller when the icon is first built
    final NotificationController controller = Get.put(NotificationController());

    return GetBuilder<NotificationController>(
      builder: (controller) {
        return PopupMenuButton(
          tooltip: "Notifications",
          offset: const Offset(0, 50),
          child: Stack(
            alignment: Alignment.center,
            children: [
              const Icon(Icons.notifications_outlined, size: 28),
              if (controller.unreadCount > 0)
                Positioned(
                  top: 8,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${controller.unreadCount}',
                      style: const TextStyle(color: Colors.white, fontSize: 10),
                    ),
                  ),
                ),
            ],
          ),
          itemBuilder: (context) => [
            PopupMenuItem(
              enabled: false,
              child: SizedBox(
                width: 350,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Panel Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text("Notifications", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                        if(controller.unreadCount > 0)
                          TextButton(
                            onPressed: () {
                              controller.markAllAsRead();
                              Navigator.pop(context); // Close popup
                            },
                            child: const Text("Mark all as read"),
                          ),
                      ],
                    ),
                    const Divider(),
                    // Notification List
                    controller.isLoading.value
                        ? const Center(child: CircularProgressIndicator())
                        : controller.notifications.isEmpty
                        ? const Center(child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Text("You're all caught up!"),
                    ))
                        : SizedBox(
                      height: 400, // Constrain height
                      child: ListView.builder(
                        itemCount: controller.notifications.length,
                        itemBuilder: (ctx, index) {
                          final notif = controller.notifications[index];
                          return NotificationTile(notification: notif);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class NotificationTile extends StatelessWidget {
  final Notification notification;
  const NotificationTile({super.key, required this.notification});

  IconData _getIconForType(NotificationType type) {
    switch (type) {
      case NotificationType.success: return Icons.check_circle_outline;
      case NotificationType.warning: return Icons.warning_amber_rounded;
      case NotificationType.error: return Icons.error_outline;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = Get.find<NotificationController>();
    return Obx(
          () => ListTile(
        onTap: () => controller.markAsRead(notification.id),
        leading: Icon(_getIconForType(notification.type), size: 28),
        title: Text(notification.title, style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 4),
            Text(timeago.format(notification.createdAt), style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
          ],
        ),
        trailing: !notification.isRead.value
            ? const Icon(Icons.circle, color: Colors.blue, size: 12)
            : null,
      ),
    );
  }
}