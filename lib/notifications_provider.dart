import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'api_service.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String points;
  final DateTime time;
  final IconData icon;
  final Color color;
  final bool isRead;
  final String type; // Added type field

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.points,
    required this.time,
    required this.icon,
    required this.color,
    this.isRead = false,
    this.type = 'info',
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'title': title,
    'message': message,
    'points': points,
    'time': time.toIso8601String(),
    'icon': icon.codePoint,
    'color': color.value,
    'isRead': isRead,
    'type': type,
  };

  factory NotificationItem.fromBackend(Map<String, dynamic> json) {
    final type = json['type'] ?? 'info';
    IconData icon = Icons.notifications_rounded;
    Color color = Colors.blue;
    String pts = '0';

    if (type == 'referral') {
      icon = Icons.card_giftcard_rounded;
      color = const Color(0xFFFFD700); // Gold
      pts = '10000';
    }

    return NotificationItem(
      id: json['id'].toString(),
      title: json['title'] ?? '',
      message: json['message'] ?? '',
      points: pts,
      time: DateTime.parse(json['created_at']),
      icon: icon,
      color: color,
      isRead: json['is_read'] ?? false,
      type: type,
    );
  }

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: json['id'],
    title: json['title'],
    message: json['message'],
    points: json['points'],
    time: DateTime.parse(json['time']),
    icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
    color: Color(json['color']),
    isRead: json['isRead'] ?? false,
    type: json['type'] ?? 'info',
  );

  NotificationItem copyWith({bool? isRead}) => NotificationItem(
    id: id,
    title: title,
    message: message,
    points: points,
    time: time,
    icon: icon,
    color: color,
    isRead: isRead ?? this.isRead,
    type: type,
  );
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<NotificationItem>>((ref) {
  return NotificationsNotifier(ref);
});

class NotificationsNotifier extends StateNotifier<List<NotificationItem>> {
  final Ref ref;
  NotificationsNotifier(this.ref) : super([]) {
    _loadAndSync();
  }

  static const _key = 'user_notifications_v1';

  Future<void> _loadAndSync() async {
    // 1. Load local first for instant UI
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    state = raw.map((s) => NotificationItem.fromJson(jsonDecode(s))).toList()
      ..sort((a, b) => b.time.compareTo(a.time));

    // 2. Sync with backend
    await refresh();
  }

  Future<void> refresh() async {
    try {
      final api = ref.read(apiServiceProvider);
      final rawLogs = await api.getNotifications();
      final backendNotifs = rawLogs.map((l) => NotificationItem.fromBackend(l)).toList();
      
      // Merge: For now, we'll just replace state with backend since backend is the source of truth
      state = backendNotifs;
      await _save();
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, state.map((n) => jsonEncode(n.toJson())).toList());
  }

  Future<void> addNotification({
    required String title,
    required String message,
    required String points,
    required IconData icon,
    required Color color,
  }) async {
    final newItem = NotificationItem(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title,
      message: message,
      points: points,
      time: DateTime.now(),
      icon: icon,
      color: color,
    );
    state = [newItem, ...state];
    await _save();
  }

  Future<void> markAsRead(String id) async {
    state = state.map((n) => n.id == id ? n.copyWith(isRead: true) : n).toList();
    await _save();
    try {
      await ref.read(apiServiceProvider).markNotificationRead(id);
    } catch (_) {}
  }

  Future<void> markAllAsRead() async {
    final ids = state.where((n) => !n.isRead).map((n) => n.id).toList();
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    await _save();
    
    // Sync with backend
    for (var id in ids) {
      try {
        await ref.read(apiServiceProvider).markNotificationRead(id);
      } catch (_) {}
    }
  }

  Future<void> clearAll() async {
    state = [];
    await _save();
  }
}
