/// Definições de posts do InstaHub. Usado por InstaHubApp e InstaHubNotifier.
class InstaHubPostDef {
  final String id;
  final String author;
  final String content;
  final String? imagePath;
  final String? videoPath;

  const InstaHubPostDef({
    required this.id,
    required this.author,
    required this.content,
    this.imagePath,
    this.videoPath,
  });

  bool get hasMedia => imagePath != null || videoPath != null;
}

const Map<String, InstaHubPostDef> kInstaHubPosts = {
  'p01': InstaHubPostDef(
    id: 'p01',
    author: 'Marcus',
    content: 'Finally finished the project! 🎉',
  ),
  'p02': InstaHubPostDef(
    id: 'p02',
    author: 'Alice',
    content: 'Meeting tomorrow at 10am. Don\'t miss it!',
  ),
  'p03': InstaHubPostDef(
    id: 'p03',
    author: 'Bob',
    content: 'Bug logs on the drive. Feel free to check.',
  ),
  'p_tulip': InstaHubPostDef(
    id: 'p_tulip',
    author: 'AwiOS',
    content: 'Guide: A tulip for you 🌷',
    imagePath: 'assets/images/tulip.png',
  ),
  'p_sunset': InstaHubPostDef(
    id: 'p_sunset',
    author: 'AwiOS',
    content: 'Sunset on the horizon 🌅',
    imagePath: 'assets/images/sunset_sky.png',
  ),
  'p_casal': InstaHubPostDef(
    id: 'p_casal',
    author: 'Alice',
    content: 'Our moment at the beach 💕',
    imagePath: 'assets/images/mountain_snow.png',
  ),
  'p_secreto': InstaHubPostDef(
    id: 'p_secreto',
    author: '???',
    content: 'You need to see this...',
    imagePath: 'assets/images/mountain_snow.png',
  ),
  'p_video': InstaHubPostDef(
    id: 'p_video',
    author: 'AwiOS',
    content: 'Video demo in feed 📹',
    videoPath: 'assets/videos/awiOS.mp4',
  ),
  'festa01': InstaHubPostDef(
    id: 'festa01',
    author: 'Liam',
    content: 'Pics from last night\'s party! 🍻',
    imagePath: 'assets/images/avatar/festa_bar.png',
  ),
};
