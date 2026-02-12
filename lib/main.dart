import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/app_registry.dart';
import 'core/navigator_key.dart';
import 'core/secure_asset_bundle.dart';
import 'data/stories_loader.dart';
import 'data/stories_manifest.dart';
import 'state/instahub_notifier.dart';
import 'state/unlocked_gallery_notifier.dart';
import 'ui/components/persistent_dock_overlay.dart';
import 'ui/components/system_notification_overlay.dart';
import 'ui/phone_shell/phone_boot_screen.dart';
import 'ui/theme/app_theme.dart';

/// Asset bundle that decrypts encrypted assets in release mode.
/// In debug mode, delegates to rootBundle (no encryption).
final secureAssetBundle = SecureAssetBundle();

/// Transição suave de páginas: slide + fade.
class _SlideWithFadeTransitionBuilder extends PageTransitionsBuilder {
  const _SlideWithFadeTransitionBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    const begin = Offset(0.03, 0);
    const end = Offset.zero;
    const curve = Curves.easeOutCubic;
    final slideTween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
    final fadeTween = Tween(begin: 0.0, end: 1.0).chain(CurveTween(curve: curve));
    return SlideTransition(
      position: animation.drive(slideTween),
      child: FadeTransition(
        opacity: animation.drive(fadeTween),
        child: child,
      ),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppRegistry.registerDefaults();
  gLoadedStories = await loadStoriesFromManifest(bundle: secureAssetBundle);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: AppTheme.inkBlack,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  runApp(
    ProviderScope(
      child: DefaultAssetBundle(
        bundle: secureAssetBundle,
        child: const AwiOSApp(),
      ),
    ),
  );
}

/// Garante que o InstaHubNotifier seja construído no início para escutar triggers do script.
class AwiOSApp extends ConsumerWidget {
  const AwiOSApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(instahubProvider);
    ref.watch(unlockedGalleryProvider);
    return SystemNotificationOverlay(
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'AwiOS',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: AppTheme.primary, brightness: Brightness.light),
          appBarTheme: const AppBarTheme(
            centerTitle: true,
            elevation: 0,
            scrolledUnderElevation: 0,
          ),
          pageTransitionsTheme: const PageTransitionsTheme(
            builders: {
              TargetPlatform.android: _SlideWithFadeTransitionBuilder(),
              TargetPlatform.iOS: _SlideWithFadeTransitionBuilder(),
              TargetPlatform.windows: _SlideWithFadeTransitionBuilder(),
              TargetPlatform.macOS: _SlideWithFadeTransitionBuilder(),
              TargetPlatform.linux: _SlideWithFadeTransitionBuilder(),
              TargetPlatform.fuchsia: _SlideWithFadeTransitionBuilder(),
            },
          ),
        ),
        home: const PhoneBootScreen(),
        builder: (context, child) => PersistentDockOverlay(child: child!),
      ),
    );
  }
}
