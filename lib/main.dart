import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app/app.dart';
import 'features/items/presentation/controllers/items_provider.dart';
import 'features/bundles/presentation/providers/bundles_provider.dart';
import 'features/activity/presentation/providers/activity_provider.dart';
import 'core/services/settings_service.dart';

void main() async {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ItemsProvider()..loadItems()),
        ChangeNotifierProvider(create: (_) => BundlesProvider()..loadBundles()),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
      ],
      child: const App(),
    ),
  );
}
