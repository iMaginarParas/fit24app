import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final String points;
  final DateTime time;
  final IconData icon;
  final Color color;
  final bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.points,
    required this.time,
    required this.icon,
    required this.color,
    this.isRead = false,
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
  };

  factory NotificationItem.fromJson(Map<String, dynamic> json) => NotificationItem(
    id: json['id'],
    title: json['title'],
    message: json['message'],
    points: json['points'],
    time: DateTime.parse(json['time']),
    icon: IconData(json['icon'], fontFamily: 'MaterialIcons'),
    color: Color(json['color']),
    isRead: json['isRead'] ?? false,
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
  );
}

final notificationsProvider = StateNotifierProvider<NotificationsNotifier, List<NotificationItem>>((ref) {
  return NotificationsNotifier();
});

class NotificationsNotifier extends StateNotifier<List<NotificationItem>> {
  NotificationsNotifier() : super([]) {
    _load();
  }

  static const _key = 'user_notifications_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    state = raw.map((s) => NotificationItem.fromJson(jsonDecode(s))).toList()
      ..sort((a, b) => b.time.compareTo(a.time));
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

  Future<void> markAllAsRead() async {
    state = state.map((n) => n.copyWith(isRead: true)).toList();
    await _save();
  }

  Future<void> clearAll() async {
    state = [];
    await _save();
  }
}
