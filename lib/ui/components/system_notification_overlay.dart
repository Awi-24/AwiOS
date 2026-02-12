import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/navigator_key.dart';
import '../../core/system_bus.dart';
import '../../state/game_notifier.dart';
import '../../state/settings_notifier.dart';
import '../../ui/theme/app_theme.dart';

/// Sistema de toast independente, acionado pelo .awi via system: toast(...) ou notify(...).
/// Exibe uma caixa que desliza do topo indicando mudança/aviso.
class SystemNotificationOverlay extends ConsumerStatefulWidget {
  const SystemNotificationOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  ConsumerState<SystemNotificationOverlay> createState() => _SystemNotificationOverlayState();
}

class _SystemNotificationOverlayState extends ConsumerState<SystemNotificationOverlay> {
  StreamSubscription<SystemEvent>? _sub;

  @override
  void initState() {
    super.initState();
    _sub = SystemBus.events.listen((event) {
      if (!mounted) return;
      String? title;
      String? body;
      String? avatar;
      if (event.command == 'toast' || event.command == 'notify') {
        title = event.title ?? 'Aviso';
        body = event.body ?? '';
        avatar = event.avatar;
      }
      if (event.command == 'toast_from_other_chat' && event.title != null) {
        title = event.title;
        body = event.body ?? '';
        avatar = event.avatar;
      }
      if (title != null && title.isNotEmpty) {
        HapticFeedback.lightImpact();
        if ((event.command == 'toast' || event.command == 'notify') &&
            ref.read(settingsProvider).soundEnabled) {
          ref.read(soundServiceProvider).playNotification();
        }
        _showToast(title, body ?? '', avatarPath: avatar?.isNotEmpty == true ? avatar : null);
      }
    });
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _showToast(String title, String body, {String? avatarPath}) {
    var retries = 0;
    void doShow() {
      final ctx = context;
      if (!ctx.mounted) return;
      final overlay = navigatorKey.currentState?.overlay;
      if (overlay == null) {
        if (retries < 10) {
          retries++;
          WidgetsBinding.instance.addPostFrameCallback((_) => doShow());
        }
        return;
      }
      final padding = MediaQuery.of(ctx).padding;
      late OverlayEntry entry;
      entry = OverlayEntry(
        builder: (context) => _ToastBanner(
          topPadding: padding.top + 8,
          title: title,
          body: body,
          avatarPath: avatarPath,
          onDismiss: () {
            try { entry.remove(); } catch (_) {}
          },
        ),
      );
      overlay.insert(entry);
      Future.delayed(const Duration(seconds: 3), () {
        try { entry.remove(); } catch (_) {}
      });
    }
    doShow();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Caixa de toast com animação slide-down do topo.
class _ToastBanner extends StatefulWidget {
  const _ToastBanner({
    required this.topPadding,
    required this.title,
    required this.body,
    this.avatarPath,
    required this.onDismiss,
  });

  final double topPadding;
  final String title;
  final String body;
  final String? avatarPath;
  final VoidCallback onDismiss;

  @override
  State<_ToastBanner> createState() => _ToastBannerState();
}

class _ToastBannerState extends State<_ToastBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget _buildAvatar() {
    const size = 64.0;
    if (widget.avatarPath != null && widget.avatarPath!.isNotEmpty) {
      final path = widget.avatarPath!.startsWith('assets/') ? widget.avatarPath! : 'assets/${widget.avatarPath!}';
      return ClipOval(
        child: SizedBox(
          width: size,
          height: size,
          child: Image.asset(
            path,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => _avatarIcon(size),
          ),
        ),
      );
    }
    return _avatarIcon(size);
  }

  Widget _avatarIcon(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size / 2),
      ),
      child: Icon(Icons.notifications_outlined, color: AppTheme.primary, size: size * 0.5),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: widget.topPadding + 6,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnim,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: widget.onDismiss,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 4)),
                ],
              ),
              child: Row(
                children: [
                  _buildAvatar(),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 19, color: AppTheme.labelPrimary)),
                        if (widget.body.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(widget.body, style: const TextStyle(fontSize: 15, color: AppTheme.labelSecondary), maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
