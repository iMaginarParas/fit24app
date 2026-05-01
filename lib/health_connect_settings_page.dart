import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:health/health.dart';
import 'health_service.dart';
import 'shell.dart';

class HealthConnectSettingsPage extends ConsumerStatefulWidget {
  const HealthConnectSettingsPage({super.key});

  @override
  ConsumerState<HealthConnectSettingsPage> createState() => _HealthConnectSettingsPageState();
}

class _HealthConnectSettingsPageState extends ConsumerState<HealthConnectSettingsPage> {
  bool _isAuthorized = false;
  bool _loading = true;
  String _lastSync = 'Never';

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    setState(() => _loading = true);
    
    // Check if Health Connect is installed
    final h = Health();
    final installed = await h.isHealthConnectAvailable();
    
    if (installed != HealthConnectSdkStatus.sdkAvailable) {
      if (mounted) {
        setState(() {
          _isAuthorized = false;
          _loading = false;
        });
        _showInstallDialog();
      }
      return;
    }

    final authorized = await HealthService.isAuthorized();
    final prefs = await SharedPreferences.getInstance();
    final lastSyncTime = prefs.getString('hc_last_sync') ?? 'Never';
    
    if (mounted) {
      setState(() {
        _isAuthorized = authorized;
        _lastSync = lastSyncTime;
        _loading = false;
      });
    }
  }

  void _showInstallDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: kCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Health Connect Missing', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text('Health Connect is required to sync your fitness data. Would you like to install it from the Play Store?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Later', style: TextStyle(color: Colors.white.withOpacity(0.4)))),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await Health().installHealthConnect();
            }, 
            child: const Text('Install Now', style: TextStyle(color: kTeal, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );
  }

  Future<void> _handleSync() async {
    setState(() => _loading = true);
    final ok = await HealthService.connectAndSync();
    if (ok) {
      final now = DateFormat('MMM dd, yyyy HH:mm').format(DateTime.now());
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('hc_last_sync', now);
      await _checkStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sync completed successfully!'), backgroundColor: kTeal),
        );
      }
    } else {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not connect to Health Connect. Check permissions.'), backgroundColor: kCoral),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Health Connect', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator(color: kTeal))
        : ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _statusCard(),
              const SizedBox(height: 32),
              _sectionHeader('Data Sync'),
              _infoTile('Last Successful Sync', _lastSync, Icons.sync_rounded),
              _infoTile('Syncing Data', 'Steps, Calories, Distance', Icons.data_usage_rounded),
              
              const SizedBox(height: 40),
              _btn(_isAuthorized ? 'Sync Now' : 'Connect Health Connect', _isAuthorized ? kTeal : kPink, _handleSync),
              
              if (_isAuthorized) ...[
                const SizedBox(height: 16),
                _btn('Manage Permissions', kCard, () async {
                  // This typically requires opening the system settings for Health Connect
                  // For now, we trigger requestAuthorization again which opens the system picker
                  await _handleSync();
                }, isOutlined: true),
              ],
              
              const SizedBox(height: 40),
              _disclaimer(),
            ],
          ),
    );
  }

  Widget _statusCard() => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: kCard,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: _isAuthorized ? kTeal.withOpacity(0.2) : kPink.withOpacity(0.2)),
    ),
    child: Row(
      children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            color: (_isAuthorized ? kTeal : kPink).withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(_isAuthorized ? Icons.check_circle_rounded : Icons.error_outline_rounded, 
            color: _isAuthorized ? kTeal : kPink, size: 30),
        ),
        const SizedBox(width: 20),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_isAuthorized ? 'Connected' : 'Not Connected', 
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(_isAuthorized 
                ? 'Fit24 is syncing with your health history.' 
                : 'Connect to import your steps from other apps.',
                style: TextStyle(color: Colors.white.withOpacity(0.4), fontSize: 13)),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Text(title.toUpperCase(), style: TextStyle(
        fontSize: 11, fontWeight: FontWeight.w800, color: Colors.white.withOpacity(0.3), letterSpacing: 1.5)),
  );

  Widget _infoTile(String label, String val, IconData icon) => Padding(
    padding: const EdgeInsets.only(bottom: 20),
    child: Row(
      children: [
        Icon(icon, color: Colors.white24, size: 20),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: TextStyle(color: Colors.white.withOpacity(0.3), fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(val, style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    ),
  );

  Widget _btn(String t, Color c, VoidCallback onTap, {bool isOutlined = false}) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: isOutlined ? Colors.transparent : c,
        borderRadius: BorderRadius.circular(16),
        border: isOutlined ? Border.all(color: Colors.white10) : null,
      ),
      child: Center(child: Text(t, style: TextStyle(
        fontWeight: FontWeight.w900, 
        color: isOutlined ? Colors.white70 : Colors.black))),
    ),
  );

  Widget _disclaimer() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.02),
      borderRadius: BorderRadius.circular(16),
    ),
    child: Text(
      'Fit24 respects your privacy. We only read data you have specifically authorized in Health Connect. Your data is used exclusively to calculate your Fit Points and Rewards.',
      style: TextStyle(color: Colors.white.withOpacity(0.2), fontSize: 11, height: 1.5),
      textAlign: TextAlign.center,
    ),
  );
}
