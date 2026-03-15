import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/storage_service.dart';
import 'screens/home_screen.dart';
import 'utils/permissions.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await StorageService.init();

  runApp(
    const ProviderScope(
      child: GroupProximityApp(),
    ),
  );
}

class GroupProximityApp extends StatefulWidget {
  const GroupProximityApp({super.key});

  @override
  State<GroupProximityApp> createState() => _GroupProximityAppState();
}

class _GroupProximityAppState extends State<GroupProximityApp> {
  @override
  void initState() {
    super.initState();
    // Request permissions after the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      requestPermissions(context);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Group Proximity Checker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
        brightness: Brightness.light,
      ),
      home: const HomeScreen(),
    );
  }
}
