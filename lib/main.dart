import 'package:flutter/material.dart';
import 'package:vapi/vapi.dart';
import 'screens/language_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await VapiClient.platformInitialized.future; // ✅ correct class name
  runApp(const KrushiAI());
}

class KrushiAI extends StatelessWidget {
  const KrushiAI({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: const LanguageScreen(),
    );
  }
}