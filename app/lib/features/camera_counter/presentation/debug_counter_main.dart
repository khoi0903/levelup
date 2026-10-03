import 'package:flutter/material.dart';

import 'debug_counter_screen.dart';

/// Run with flutter run -t lib/features/camera_counter/presentation/debug_counter_main.dart
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'LevelUp • Camera debug',
      home: DebugCounterScreen(),
    ),
  );
}
