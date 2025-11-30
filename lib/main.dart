import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'app/app.dart';
import 'features/items/presentation/controllers/items_provider.dart';
import 'features/bundles/presentation/providers/bundles_provider.dart';

void main() {
  if (Platform.isWindows || Platform.isLinux) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }
  
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ItemsProvider()..loadItems()),
        ChangeNotifierProvider(create: (_) => BundlesProvider()..loadBundles()),
      ],
      child: const App(),
    ),
  );
}
