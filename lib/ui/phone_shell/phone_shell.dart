import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../apps/awi_app.dart';
import '../../core/app_registry.dart';
import '../../state/chat_progress_notifier.dart';
import '../../state/wallpaper_notifier.dart';
import '../theme/app_theme.dart';

/// Phone frame: responsive, max width and aspect ratio.
/// Apps vêm do [AppRegistry] para arquitetura modular.
class PhoneShell extends ConsumerWidget {
  const PhoneShell({super.key});

  static List<AwiApp> get apps => AppRegistry.apps;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unreadCount = ref.watch(chatProgressProvider).values.where((e) => e.hasUnread).length;
    final wallpaper = ref.watch(wallpaperProvider).homeWallpaper;
    return Scaffold(
      backgroundColor: AppTheme.inkBlack,
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxHeight,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppTheme.phoneBorderRadius),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (wallpaper != null)
                    Image.asset(
                      wallpaper,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const ColoredBox(color: AppTheme.background),
                    )
                  else
                    const ColoredBox(color: AppTheme.background),
                  if (wallpaper != null)
                    Container(color: Colors.white.withValues(alpha: 0.4)),
                  Column(
                    children: [
                      _StatusBar(unreadCount: unreadCount),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              'AwiOS',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.labelPrimary,
                              ),
                            ),
                            const SizedBox(height: AppTheme.spaceXl),
                            LayoutBuilder(
                              builder: (context, c) {
                                final size = (c.maxWidth * 0.2).clamp(48.0, 80.0);
                                return Wrap(
                                  alignment: WrapAlignment.center,
                                  spacing: AppTheme.spaceLg,
                                  runSpacing: AppTheme.spaceLg,
                                  children: apps.map((app) => _AppIcon(
                                    app: app,
                                    size: size,
                                    badgeCount: app.id == 'chat' ? unreadCount : 0,
                                  )).toList(),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({this.unreadCount = 0});

  final int unreadCount;

  @override
  Widget build(BuildContext context) {
    final time = DateTime.now();
    final timeStr = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceLg, vertical: AppTheme.spaceSm),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            timeStr,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppTheme.labelPrimary,
            ),
          ),
          Row(
            children: [
              if (unreadCount > 0)
                Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spaceSm),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE4405F),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      unreadCount > 99 ? '99+' : '$unreadCount',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              Icon(Icons.signal_cellular_alt, size: 16, color: AppTheme.labelPrimary.withValues(alpha: 0.8)),
              const SizedBox(width: AppTheme.spaceXs),
              Icon(Icons.wifi, size: 16, color: AppTheme.labelPrimary.withValues(alpha: 0.8)),
              const SizedBox(width: AppTheme.spaceXs),
              Icon(Icons.battery_full, size: 16, color: AppTheme.labelPrimary.withValues(alpha: 0.8)),
            ],
          ),
        ],
      ),
    );
  }
}

class _AppIcon extends StatefulWidget {
  const _AppIcon({required this.app, this.size = 64, this.badgeCount = 0});

  final AwiApp app;
  final double size;
  final int badgeCount;

  @override
  State<_AppIcon> createState() => _AppIconState();
}

class _AppIconState extends State<_AppIcon> {
  bool _hovered = false;

  static Color _accent(AwiApp app) => AppRegistry.accent(app.id);

  @override
  Widget build(BuildContext context) {
    final accent = _accent(widget.app);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (context) => widget.app,
            ),
          );
        },
        child: AnimatedScale(
          scale: _hovered ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: widget.size,
                    height: widget.size,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [accent, accent.withValues(alpha: 0.75)],
                      ),
                      borderRadius: BorderRadius.circular(widget.size * 0.22),
                      boxShadow: [
                        BoxShadow(
                          color: accent.withValues(alpha: 0.35),
                          blurRadius: widget.size * 0.2,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Icon(widget.app.icon, size: widget.size * 0.5, color: Colors.white),
                  ),
                  if (widget.badgeCount > 0)
                    Positioned(
                      top: -4,
                      right: -4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE4405F),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          widget.badgeCount > 99 ? '99+' : '${widget.badgeCount}',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppTheme.spaceSm),
              Text(
                widget.app.name,
                style: const TextStyle(
                  fontSize: 12,
                  color: AppTheme.labelPrimary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

