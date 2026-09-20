import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/assistant_controller.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = AssistantController();
  await controller.init();
  runApp(ChangeNotifierProvider.value(value: controller, child: const AtlasApp()));
}

class AtlasApp extends StatelessWidget {
  const AtlasApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    title: 'Atlas One',
    theme: ThemeData(useMaterial3: true, colorSchemeSeed: const Color(0xFF6C63FF), brightness: Brightness.dark),
    home: const HomeScreen(),
  );
}
