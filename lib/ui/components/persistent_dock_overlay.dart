import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../apps/awi_app.dart';
import '../../core/app_registry.dart';
import '../../core/navigator_key.dart';
import '../../state/chat_progress_notifier.dart';
import '../theme/app_theme.dart';

/// Persistent dock at bottom edge. Small tab expands/collapses the bar. Fully hidden when collapsed.
/// CRITICAL: Overlay height must include expanded dock so taps reach the bar (otherwise content eats them).
class PersistentDockOverlay extends ConsumerStatefulWidget {
  const PersistentDockOverlay({
    super.key,
    required this.child,
  });

  final Widget child;

  static List<AwiApp> get apps => AppRegistry.apps;

  @override
  ConsumerState<PersistentDockOverlay> createState() => _PersistentDockOverlayState();
}

class _PersistentDockOverlayState extends ConsumerState<PersistentDockOverlay> {
  bool _dockExpanded = false;

  static const _collapsedHeight = 14.0;
  static const _tabHeight = 20.0;
  static const _dockHeight = 96.0;
  static const _expandedHeight = _tabHeight + _dockHeight;

  @override
  Widget build(BuildContext context) {
    final messagesBadgeCount = ref.watch(chatProgressProvider).values.where((e) => e.hasUnread).length;
    final overlayHeight = _dockExpanded ? _expandedHeight : _collapsedHeight;
    return Stack(
      fit: StackFit.expand,
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: overlayHeight,
          child: _DockWithTab(
            apps: PersistentDockOverlay.apps,
            messagesBadgeCount: messagesBadgeCount,
            expanded: _dockExpanded,
            onExpandedChanged: (v) => setState(() => _dockExpanded = v),
          ),
        ),
      ],
    );
  }
}

class _DockWithTab extends StatefulWidget {
  const _DockWithTab({
    required this.apps,
    required this.messagesBadgeCount,
    required this.expanded,
    required this.onExpandedChanged,
  });

  final List<AwiApp> apps;
  final int messagesBadgeCount;
  final bool expanded;
  final void Function(bool) onExpandedChanged;

  @override
  State<_DockWithTab> createState() => _DockWithTabState();
}

class _DockWithTabState extends State<_DockWithTab> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnim;

  static const _tabHeight = 20.0;
  static const _dockHeight = 96.0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggle() {
    HapticFeedback.selectionClick();
    final next = !widget.expanded;
    widget.onExpandedChanged(next);
    if (next) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final centerX = constraints.maxWidth / 2;
        return Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomCenter,
          children: [
            Positioned(
              left: 0,
              right: 0,
              bottom: _tabHeight,
              height: _dockHeight,
              child: SlideTransition(
                position: _slideAnim,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: _DockBar(
                    apps: widget.apps,
                    messagesBadgeCount: widget.messagesBadgeCount,
                    vertical: false,
                  ),
                ),
              ),
            ),
            Positioned(
              left: centerX - 24,
              bottom: 0,
              child: _DockTab(expanded: widget.expanded, onTap: _toggle),
            ),
          ],
        );
      },
    );
  }
}

class _DockTab extends StatefulWidget {
  const _DockTab({required this.expanded, required this.onTap});

  final bool expanded;
  final VoidCallback onTap;

  @override
  State<_DockTab> createState() => _DockTabState();
}

class _DockTabState extends State<_DockTab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _hovered ? 1.08 : 1.0,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          child: Container(
            width: 48,
            height: 12,
            margin: const EdgeInsets.only(bottom: 1),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.9),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 4,
                  offset: const Offset(0, -1),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                widget.expanded ? Icons.expand_more : Icons.expand_less,
                size: 16,
                color: AppTheme.labelSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DockBar extends StatelessWidget {
  const _DockBar({
    required this.apps,
    required this.messagesBadgeCount,
    this.vertical = false,
  });

  final List<AwiApp> apps;
  final int messagesBadgeCount;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final children = apps.map((app) => _DockIcon(
      app: app,
      badgeCount: app.id == 'chat' ? messagesBadgeCount : 0,
    )).toList();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spaceXl, vertical: AppTheme.spaceMd),
      margin: const EdgeInsets.symmetric(horizontal: AppTheme.spaceMd, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: vertical
          ? Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: children.map((c) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: c,
              )).toList(),
            )
          : Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (int i = 0; i < children.length; i++) ...[
                  children[i],
                  if (i < children.length - 1) const SizedBox(width: 14),
                ],
              ],
            ),
    );
  }
}

class _DockIcon extends StatefulWidget {
  const _DockIcon({required this.app, this.badgeCount = 0});

  final AwiApp app;
  final int badgeCount;

  @override
  State<_DockIcon> createState() => _DockIconState();
}

class _DockIconState extends State<_DockIcon> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accent = AppRegistry.accent(widget.app.id);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () {
          HapticFeedback.lightImpact();
          navigatorKey.currentState?.push(
            MaterialPageRoute<void>(
              builder: (context) => widget.app,
            ),
          );
        },
        child: AnimatedScale(
          scale: _hovered ? 1.12 : 1.0,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(widget.app.icon, size: 28, color: accent),
              ),
              if (widget.badgeCount > 0)
                Positioned(
                  top: -2,
                  right: -2,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFE4405F),
                      shape: BoxShape.circle,
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
        ),
      ),
    );
  }
}
