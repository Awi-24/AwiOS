import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../awi_app.dart';
import '../../data/gallery_catalog.dart';
import '../../state/settings_notifier.dart';
import '../../state/unlocked_gallery_notifier.dart';
import '../../ui/theme/app_theme.dart';
import '../../ui/components/media_viewer.dart';

/// Gallery: shows unlocked media. "Unlock all" em Settings libera todo o catálogo.
class GalleryApp extends AwiApp {
  const GalleryApp({super.key});

  @override
  String get id => 'gallery';
  @override
  IconData get icon => Icons.photo_library_outlined;
  @override
  String get name => 'Photos';

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final unlocked = ref.watch(unlockedGalleryProvider);
        final settings = ref.watch(settingsProvider);
        final paths = settings.galleryUnlockAll
            ? kGalleryCatalog.toList()
            : unlocked.toList()..sort();

        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.galleryAccent,
            elevation: 0,
            title: const Text(
              'Photos',
              style: TextStyle(color: AppTheme.labelPrimary, fontWeight: FontWeight.w600, fontSize: 20),
            ),
          ),
          body: paths.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.photo_library_outlined, size: 64, color: AppTheme.labelTertiary),
                      SizedBox(height: AppTheme.spaceMd),
                      Text(
                        'No photos yet',
                        style: TextStyle(color: AppTheme.labelSecondary, fontSize: 17),
                      ),
                      SizedBox(height: AppTheme.spaceXs),
                      Text(
                        'Photos from chats will appear here.',
                        style: TextStyle(color: AppTheme.labelTertiary, fontSize: 14),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
              : GridView.builder(
                  padding: const EdgeInsets.all(AppTheme.spaceSm),
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 120,
                    mainAxisSpacing: AppTheme.spaceSm,
                    crossAxisSpacing: AppTheme.spaceSm,
                    childAspectRatio: 1,
                  ),
                  itemCount: paths.length,
                  itemBuilder: (context, i) {
                    return _GalleryThumb(
                      path: paths[i],
                      onTap: () => MediaViewer.showGallery(context, paths, i, showSetWallpaper: true),
                    );
                  },
                ),
        );
      },
    );
  }

}

class _GalleryThumb extends StatelessWidget {
  const _GalleryThumb({required this.path, required this.onTap});

  final String path;
  final VoidCallback onTap;

  bool get _isVideo => path.toLowerCase().endsWith('.mp4') || path.toLowerCase().endsWith('.mov');

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.galleryAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(8),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _isVideo
              ? Stack(
                  fit: StackFit.expand,
                  children: [
                    const Icon(Icons.videocam, color: AppTheme.galleryAccent, size: 40),
                    Positioned(
                      bottom: 4,
                      right: 4,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
                        child: const Icon(Icons.play_arrow, color: Colors.white, size: 20),
                      ),
                    ),
                  ],
                )
              : path.startsWith('assets/')
                  ? Image.asset(
                      path,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: AppTheme.labelTertiary, size: 40),
                    )
                  : const Icon(Icons.image_outlined, color: AppTheme.galleryAccent, size: 40),
        ),
      ),
    );
  }
}
