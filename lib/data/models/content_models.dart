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

  factory Article.fromJson(Map<String, dynamic> json) {
    return Article(
      id: (json['id'] as num?)?.toInt() ?? 0,
      category: json['category'] as String? ?? '',
      title: json['title'] as String? ?? '',
      excerpt: json['excerpt'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      readingMinutes: (json['readingMinutes'] as num?)?.toInt() ?? 1,
      author: json['author'] as String? ?? 'Wood & Panel',
      authorAvatarUrl: json['authorAvatarUrl'] as String? ?? '',
      url: json['url'] as String? ?? '',
      html: json['html'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'category': category,
        'title': title,
        'excerpt': excerpt,
        'imageUrl': imageUrl,
        'date': date.toIso8601String(),
        'readingMinutes': readingMinutes,
        'author': author,
        'authorAvatarUrl': authorAvatarUrl,
        'url': url,
        'html': html,
      };
}

class MagazineIssue {
  const MagazineIssue({
    required this.id,
    required this.title,
    required this.coverUrl,
    required this.date,
    required this.description,
    required this.fileSize,
    this.readUrl = '',
  });

  final int id;
  final String title;
  final String coverUrl;
  final DateTime date;
  final String description;
  final String fileSize;
  final String readUrl;

  factory MagazineIssue.fromJson(Map<String, dynamic> json) {
    return MagazineIssue(
      id: (json['id'] as num?)?.toInt() ?? 0,
      title: json['title'] as String? ?? '',
      coverUrl: json['coverUrl'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      description: json['description'] as String? ?? '',
      fileSize: json['fileSize'] as String? ?? '',
      readUrl: json['readUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'coverUrl': coverUrl,
        'date': date.toIso8601String(),
        'description': description,
        'fileSize': fileSize,
        'readUrl': readUrl,
      };
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

  factory AppEvent.fromJson(Map<String, dynamic> json) {
    return AppEvent(
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      location: json['location'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'date': date,
        'location': location,
        'imageUrl': imageUrl,
      };
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

  factory YouTubeVideo.fromJson(Map<String, dynamic> json) {
    return YouTubeVideo(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
      url: json['url'] as String? ?? '',
      publishedAt: DateTime.tryParse(json['publishedAt'] as String? ?? '') ??
          DateTime.now(),
      views: (json['views'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'thumbnailUrl': thumbnailUrl,
        'url': url,
        'publishedAt': publishedAt.toIso8601String(),
        'views': views,
      };
}
