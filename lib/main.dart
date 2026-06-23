import 'package:flutter/material.dart';
import 'views/home_page.dart';
import 'services/media_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  MediaService().navigatorKey = GlobalKey<NavigatorState>();
  runApp(const StorageAssistantApp());
}

class StorageAssistantApp extends StatelessWidget {
  const StorageAssistantApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '存储小助手',
      navigatorKey: MediaService().navigatorKey,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
