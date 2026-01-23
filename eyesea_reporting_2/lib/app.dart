import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/services/notification_service.dart';
import 'presentation/providers/theme_provider.dart';
import 'presentation/widgets/notification_banner.dart';

class EyeseaApp extends StatelessWidget {
  final GoRouter router;

  const EyeseaApp({super.key, required this.router});

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, _) {
        return MaterialApp.router(
          title: 'Eyesea Reporting',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: themeProvider.themeMode,
          routerConfig: router,
          builder: (context, child) {
            // Wrap with notification overlay to show in-app notification banners
            final notificationService = context.read<NotificationService>();
            return NotificationOverlay(
              notificationService: notificationService,
              child: child ?? const SizedBox.shrink(),
            );
          },
        );
      },
    );
  }
}

