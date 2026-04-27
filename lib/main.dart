// main.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'shell.dart';
import 'auth.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0A0D0F),
  ));
  runApp(const ProviderScope(child: Fit24App()));
}

class Fit24App extends StatelessWidget {
  const Fit24App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Fit24',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: kBg,
      colorScheme: const ColorScheme.dark(primary: kGreen, surface: kSurface),
    ),
    home: const AuthGate(), // ← was AppShell, now checks auth first
  );
}