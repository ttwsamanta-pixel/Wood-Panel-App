class Article {
  const Article({
    required this.id,
    required this.category,
    required this.title,
    required this.excerpt,
    required this.imageUrl,
    required this.date,
    required this.readingMinutes,
    required this.author,
    this.authorAvatarUrl = '',
    required this.url,
    required this.html,
  });

  final int id;
  final String category;
  final String title;
  final String excerpt;
  final String imageUrl;
  final DateTime date;
  final int readingMinutes;
  final String author;
  final String authorAvatarUrl;
  final String url;
  final String html;
}

class MagazineIssue {
  const MagazineIssue({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.date,
    required this.description,
    required this.fileSize,
  });

  final int id;
  final String title;
  final String coverUrl;
  final DateTime date;
  final String description;
  final String fileSize;
}

class AppEvent {
  const AppEvent({
    required this.title,
    required this.date,
    required this.location,
    required this.imageUrl,
  });

  final String title;
  final String date;
  final String location;
  final String imageUrl;
}

class YouTubeVideo {
  const YouTubeVideo({
    required this.id,
    required this.title,
    required this.description,
    required this.thumbnailUrl,
    required this.url,
    required this.publishedAt,
    required this.views,
  });

  final String id;
  final String title;
  final String description;
  final String thumbnailUrl;
  final String url;
  final DateTime publishedAt;
  final int views;
}
