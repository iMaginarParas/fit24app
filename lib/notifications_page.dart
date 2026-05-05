import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shell.dart';
import 'package:intl/intl.dart';
import 'notifications_provider.dart';

class NotificationsPage extends ConsumerStatefulWidget {
  const NotificationsPage({super.key});

  @override
  ConsumerState<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends ConsumerState<NotificationsPage> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when user views the page
    Future.microtask(() => ref.read(notificationsProvider.notifier).markAllAsRead());
  }

  @override
  Widget build(BuildContext context) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [kBg, Color(0xFF1A1F25)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                pinned: true,
                expandedHeight: 80,
                flexibleSpace: ClipRect(
                  child: BackdropFilter(
                    filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: Container(color: kBg.withOpacity(0.5)),
                  ),
                ),
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 22),
                  onPressed: () => Navigator.pop(context),
                ),
                title: const Text('Notifications', 
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w900, letterSpacing: -0.5)),
                centerTitle: true,
                actions: [
                  if (notifications.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white54),
                      onPressed: () => _confirmClear(context),
                    ),
                ],
              ),

              if (notifications.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.03),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.notifications_none_rounded, size: 64, color: Colors.white.withOpacity(0.1)),
                        ),
                        const SizedBox(height: 24),
                        Text('No notifications yet', 
                          style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 16, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                )
              else
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final notif = notifications[index];
                      final color = notif.color;
                      final time = notif.time;
                      
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: notif.isRead ? Colors.white.withOpacity(0.03) : Colors.white.withOpacity(0.06),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: notif.isRead ? Colors.white.withOpacity(0.06) : color.withOpacity(0.2)),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 48, height: 48,
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(notif.icon, color: color, size: 24),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(notif.title, style: const TextStyle(
                                          fontSize: 16, fontWeight: FontWeight.w800, color: Colors.white)),
                                      ),
                                      Text(_formatTime(time), style: TextStyle(
                                        fontSize: 10, color: Colors.white.withOpacity(0.4))),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(notif.message, style: TextStyle(
                                    fontSize: 13, color: Colors.white.withOpacity(0.6), height: 1.4)),
                                  const SizedBox(height: 12),
                                  if (notif.points.isNotEmpty && notif.points != '0')
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: color.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: color.withOpacity(0.3)),
                                      ),
                                      child: Text('${notif.points.startsWith('+') ? '' : '+'}${notif.points} Points', style: TextStyle(
                                        fontSize: 11, fontWeight: FontWeight.w800, color: color)),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                    childCount: notifications.length,
                  ),
                ),
              const SliverToBoxAdapter(child: SizedBox(height: 40)),
            ],
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(time);
  }

  void _confirmClear(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        title: const Text('Clear all?', style: TextStyle(color: Colors.white)),
        content: const Text('Do you want to delete all notifications?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          TextButton(
            onPressed: () {
              ref.read(notificationsProvider.notifier).clearAll();
              Navigator.pop(ctx);
            }, 
            child: const Text('CLEAR', style: TextStyle(color: kCoral))
          ),
        ],
      ),
    );
  }
}

