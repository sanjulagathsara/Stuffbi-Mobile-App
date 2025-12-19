import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'theme/theme.dart';
import 'router.dart';
import '../core/sync/sync_service.dart';
import '../core/sync/sync_conflict.dart';
import '../core/widgets/conflict_resolution_dialog.dart';

/// Global navigator key for showing dialogs from anywhere
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final SyncService _syncService = SyncService();

  @override
  void initState() {
    super.initState();
    // Register conflict callback
    _syncService.setConflictCallback(_onConflictsDetected);
  }

  @override
  void dispose() {
    _syncService.setConflictCallback(null);
    super.dispose();
  }

  void _onConflictsDetected(List<SyncConflict> conflicts) {
    // Conflict resolution dialog box
    // Show dialog when conflicts are detected
    // WidgetsBinding.instance.addPostFrameCallback((_) {
    //   final context = navigatorKey.currentContext;
    //   if (context != null) {
    //     ConflictResolutionDialog.show(context, conflicts);
    //   }
    // });
  }

  @override
  Widget build(BuildContext context) {
    final GoRouter router = appRouter;
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Stuffbi',
      theme: buildTheme(),
      routerConfig: router,
    );
  }
}
