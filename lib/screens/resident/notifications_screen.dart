import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/app_notification.dart';
import '../../providers/app_provider.dart';
import '../../services/firestore_service.dart';
import '../../services/notification_service.dart';
import '../../widgets/confirm_dialog.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final notificationService = NotificationService();
  final firestoreService = FirestoreService();

  Future<void> _toggleNotifications(bool value) async {
    final provider = context.read<AppProvider>();
    final user = provider.currentUser;
    if (user == null) return;
    
    try {
      await firestoreService.updateNotificationEnabled(user, value);
      provider.updateUser(user.copyWith(notificationsEnabled: value));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(value ? 'Notifications turned on' : 'Notifications turned off')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'.replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _markAllAsRead() async {
    final user = context.read<AppProvider>().currentUser;
    if (user == null) return;
    try {
      await notificationService.markAllAsRead(user.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'.replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _clearAll() async {
    final user = context.read<AppProvider>().currentUser;
    if (user == null) return;

    final confirm = await showConfirmDialog(
      context: context,
      title: 'Clear all notifications?',
      message: 'This action cannot be undone.',
      confirmText: 'Clear All',
    );

    if (confirm != true) return;

    try {
      await notificationService.clearNotifications(user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notifications cleared')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'.replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _deleteNotification(String id) async {
    try {
      await notificationService.deleteNotification(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Notification deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'.replaceAll('Exception: ', ''))),
      );
    }
  }

  Future<void> _markAsRead(String id) async {
    try {
      await notificationService.markAsRead(id);
    } catch (e) {
      // silently fail
    }
  }

  String _formatTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  Widget _buildTypeBadge(AppNotification notif, ColorScheme colorScheme) {
    String label = 'Notification';
    IconData icon = Icons.notifications;
    Color color = colorScheme.secondary;

    switch (notif.type) {
      case 'manual_arrival':
        label = 'Manual arrival update';
        icon = Icons.touch_app_outlined;
        color = Colors.blue;
        break;
      case 'geofence_arrival':
        label = 'Location-based arrival';
        icon = Icons.location_on_outlined;
        color = Colors.green;
        break;
      case 'vendor_update':
        label = 'Vendor update';
        icon = Icons.edit_note;
        color = Colors.orange;
        break;
      case 'request_response':
        label = 'Vendor response';
        icon = Icons.chat_bubble_outline;
        color = Colors.purple;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: color),
          const SizedBox(width: 4),
          Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppProvider>().currentUser;
    final colorScheme = Theme.of(context).colorScheme;

    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Please login')),
      );
    }

    final notificationsEnabled = currentUser.notificationsEnabled;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            icon: const Icon(Icons.mark_email_read),
            tooltip: 'Mark all as read',
            onPressed: _markAllAsRead,
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Clear all',
            onPressed: _clearAll,
          ),
        ],
      ),
      body: Column(
        children: [
          // Settings Toggle
          SwitchListTile(
            title: const Text('Notifications enabled'),
            subtitle: Text(notificationsEnabled
                ? 'You will receive route updates'
                : 'Notifications are turned off'),
            value: notificationsEnabled,
            onChanged: _toggleNotifications,
            secondary: Icon(notificationsEnabled ? Icons.notifications_active : Icons.notifications_off),
          ),
          const Divider(height: 1),
          
          if (!notificationsEnabled)
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              color: colorScheme.surfaceContainerHighest,
              width: double.infinity,
              child: Row(
                children: [
                  Icon(Icons.info_outline, size: 16, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(
                    'Notifications are turned off',
                    style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
                  ),
                ],
              ),
            ),

          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: notificationService.notificationsForUser(currentUser.id),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Could not load notifications: ${snapshot.error}',
                        style: TextStyle(color: colorScheme.error)),
                  );
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final notifications = snapshot.data ?? [];
                
                // Sort locally: newest first
                notifications.sort((a, b) {
                  final aTime = a.createdAt;
                  final bTime = b.createdAt;
                  if (aTime == null && bTime == null) return 0;
                  if (aTime == null) return 1;
                  if (bTime == null) return -1;
                  return bTime.compareTo(aTime);
                });

                if (notifications.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_none, size: 48, color: colorScheme.outline),
                        const SizedBox(height: 16),
                        Text(
                          'No notifications yet',
                          style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: notifications.length,
                  separatorBuilder: (context, index) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final notif = notifications[index];
                    return ListTile(
                      tileColor: notif.read ? null : colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
                      leading: Stack(
                        children: [
                          CircleAvatar(
                            backgroundColor: colorScheme.secondaryContainer,
                            child: Icon(Icons.notifications, color: colorScheme.secondary, size: 20),
                          ),
                          if (!notif.read)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                  color: colorScheme.error,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: colorScheme.surface, width: 1.5),
                                ),
                              ),
                            ),
                        ],
                      ),
                      title: Text(
                        notif.vendorName,
                        style: TextStyle(fontWeight: notif.read ? FontWeight.normal : FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          _buildTypeBadge(notif, colorScheme),
                          const SizedBox(height: 4),
                          Text(
                            notif.message,
                            style: TextStyle(
                              color: notif.read ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
                            ),
                          ),
                          if (notif.createdAt != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              _formatTime(notif.createdAt),
                              style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                            ),
                          ]
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _deleteNotification(notif.id),
                        tooltip: 'Delete notification',
                      ),
                      onTap: () {
                        if (!notif.read) {
                          _markAsRead(notif.id);
                        }
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
