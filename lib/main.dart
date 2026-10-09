import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'language/english_coach_controller.dart';
import 'screens/veltrix_home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = EnglishCoachController();
  runApp(ChangeNotifierProvider.value(
    value: controller,
    child: const VeltrixApp(),
  ));
  // Keep startup fast: show the first frame before reading local preferences.
  await controller.init();
}

class VeltrixApp extends StatelessWidget {
  const VeltrixApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'VELTRIX AI — English Mastery',
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF72E3D3), brightness: Brightness.dark),
      scaffoldBackgroundColor: const Color(0xFF0B1119),
      splashFactory: InkRipple.splashFactory,
      textTheme: const TextTheme(bodyMedium: TextStyle(color: Color(0xFFF1F5FA))),
    ),
    home: const VeltrixHomeScreen(),
  );
}
