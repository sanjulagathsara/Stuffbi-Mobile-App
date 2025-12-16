import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app/app.dart';
import 'features/items/presentation/controllers/items_provider.dart';
import 'features/bundles/presentation/providers/bundles_provider.dart';
import 'features/activity/presentation/providers/activity_provider.dart';
import 'core/services/settings_service.dart';
import 'core/sync/connectivity_service.dart';
import 'core/sync/sync_service.dart';

void main() async {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  WidgetsFlutterBinding.ensureInitialized();
  await SettingsService().init();
  
  // Initialize sync services
  await ConnectivityService().initialize();
  await SyncService().initialize();
  
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BundlesProvider()..loadBundles()),
        ChangeNotifierProxyProvider<BundlesProvider, ItemsProvider>(
          create: (_) => ItemsProvider()..loadItems(),
          update: (_, bundlesProvider, itemsProvider) {
            itemsProvider!.setBundlesProvider(bundlesProvider);
            return itemsProvider;
          },
        ),
        ChangeNotifierProvider(create: (_) => ActivityProvider()),
        // Sync services
        ChangeNotifierProvider.value(value: ConnectivityService()),
        ChangeNotifierProvider.value(value: SyncService()),
      ],
      child: const App(),
    ),
  );
}

