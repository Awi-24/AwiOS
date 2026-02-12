import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';

import '../awi_app.dart';
import '../chat/chat_app.dart';
import '../../state/settings_notifier.dart';
import '../../state/game_notifier.dart';
import '../../state/chapter_selector_provider.dart';
import '../../ui/theme/app_theme.dart';

/// Settings: autosave, language, text speed, gallery unlock all.
class SettingsApp extends AwiApp {
  const SettingsApp({super.key});

  @override
  String get id => 'settings';
  @override
  IconData get icon => Icons.settings_outlined;
  @override
  String get name => 'Settings';

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final settings = ref.watch(settingsProvider);
        return Scaffold(
          backgroundColor: AppTheme.background,
          appBar: AppBar(
            backgroundColor: AppTheme.surface,
            foregroundColor: AppTheme.settingsAccent,
            elevation: 0,
            title: const Text(
              'Settings',
              style: TextStyle(color: AppTheme.labelPrimary, fontWeight: FontWeight.w600, fontSize: 20),
            ),
          ),
          body: ListView(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceSm),
                child: Text(
                  'Game',
                  style: TextStyle(
                    color: AppTheme.labelSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SwitchListTile(
                value: settings.autosaveEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).setAutosave(v),
                title: const Text('Auto-save', style: TextStyle(color: AppTheme.labelPrimary)),
                subtitle: const Text('Save progress automatically'),
                activeTrackColor: AppTheme.settingsAccent.withValues(alpha: 0.5),
                activeThumbColor: AppTheme.settingsAccent,
              ),
              SwitchListTile(
                value: settings.soundEnabled,
                onChanged: (v) => ref.read(settingsProvider.notifier).setSoundEnabled(v),
                title: const Text('Sounds', style: TextStyle(color: AppTheme.labelPrimary)),
                subtitle: const Text('Message send/receive, notifications'),
                activeTrackColor: AppTheme.settingsAccent.withValues(alpha: 0.5),
                activeThumbColor: AppTheme.settingsAccent,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceSm),
                child: Text(
                  'Dialogue',
                  style: TextStyle(
                    color: AppTheme.labelSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.speed, color: AppTheme.settingsAccent),
                title: const Text('Text speed', style: TextStyle(color: AppTheme.labelPrimary)),
                subtitle: Text('${settings.textSpeed}x'),
                trailing: SizedBox(
                  width: 120,
                  child: Slider(
                    value: settings.textSpeed,
                    min: 0.5,
                    max: 3,
                    divisions: 5,
                    onChanged: (v) => ref.read(settingsProvider.notifier).setTextSpeed(v),
                    activeColor: AppTheme.settingsAccent,
                    inactiveColor: AppTheme.settingsAccent.withValues(alpha: 0.5),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceSm),
                child: Text(
                  'Language',
                  style: TextStyle(
                    color: AppTheme.labelSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.language, color: AppTheme.settingsAccent),
                title: const Text('Language', style: TextStyle(color: AppTheme.labelPrimary)),
                subtitle: Text(settings.language == 'en' ? 'English' : settings.language),
                trailing: DropdownButton<String>(
                  value: settings.language,
                  items: const [
                    DropdownMenuItem(value: 'en', child: Text('English')),
                    DropdownMenuItem(value: 'pt', child: Text('Português')),
                  ],
                  onChanged: (v) {
                    if (v != null) ref.read(settingsProvider.notifier).setLanguage(v);
                  },
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceSm),
                child: Text(
                  'Gallery',
                  style: TextStyle(
                    color: AppTheme.labelSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              SwitchListTile(
                value: settings.galleryUnlockAll,
                onChanged: (v) => ref.read(settingsProvider.notifier).setGalleryUnlockAll(v),
                title: const Text('Unlock all photos', style: TextStyle(color: AppTheme.labelPrimary)),
                subtitle: const Text('Show all gallery images (for testing)'),
                activeTrackColor: AppTheme.settingsAccent.withValues(alpha: 0.5),
                activeThumbColor: AppTheme.settingsAccent,
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceSm),
                child: Text(
                  'Data',
                  style: TextStyle(
                    color: AppTheme.labelSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever, color: AppTheme.settingsAccent),
                title: const Text('Reset chat history', style: TextStyle(color: AppTheme.labelPrimary)),
                subtitle: const Text('Clear progress, saves and chat previews'),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reset chat history?'),
                      content: const Text(
                        'This will clear all progress, save data and chat previews. This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(gameNotifierProvider.notifier).resetChatHistory();
                  }
                },
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(AppTheme.spaceMd, AppTheme.spaceLg, AppTheme.spaceMd, AppTheme.spaceSm),
                child: Text(
                  'Debug',
                  style: TextStyle(
                    color: AppTheme.labelSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.playlist_play, color: AppTheme.settingsAccent),
                title: const Text('Select chapter', style: TextStyle(color: AppTheme.labelPrimary)),
                subtitle: const Text('Start at a chapter (default vars)'),
                onTap: () async {
                  HapticFeedback.lightImpact();
                  if (!context.mounted) return;
                  await _showChapterSelector(context, ref);
                },
              ),
              ListTile(
                leading: const Icon(Icons.cleaning_services, color: AppTheme.settingsAccent),
                title: const Text('Clear all data', style: TextStyle(color: AppTheme.labelPrimary)),
                subtitle: const Text('Reset chat history + unlocked gallery images + cache'),
                onTap: () async {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Clear all data?'),
                      content: const Text(
                        'This will clear all progress, saves, chat previews, unlocked gallery images and cached data. This cannot be undone.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Clear all'),
                        ),
                      ],
                    ),
                  );
                  if (confirmed == true) {
                    await ref.read(gameNotifierProvider.notifier).clearAllData();
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

Future<void> _showChapterSelector(BuildContext context, WidgetRef ref) async {
  final chapters = ref.read(selectableChaptersProvider);
  if (chapters.isEmpty) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No chapter available')));
    }
    return;
  }
  final selected = await showDialog<SelectableChapter>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Select chapter'),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: chapters.length,
          itemBuilder: (context, i) {
            final ch = chapters[i];
            return ListTile(
              title: Text(ch.name),
              subtitle: Text(ch.chapterId),
              trailing: ch.isCompleted ? const Icon(Icons.check_circle, color: Colors.green, size: 20) : null,
              onTap: () => Navigator.pop(ctx, ch),
            );
          },
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
      ],
    ),
  );
  if (selected != null && context.mounted) {
    ref.read(pendingChapterStartProvider.notifier).setPending(
      chatId: selected.storyId,
      chapterId: selected.chapterId,
      scriptPath: selected.scriptPath,
    );
    Navigator.pop(context); // Fecha Settings
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ChatApp()));
  }
}
