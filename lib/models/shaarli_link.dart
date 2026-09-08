class ShaarliLink {
  final int id;
  final String url;
  final String title;
  final String description;
  final List<String> tags;
  final bool private;
  final DateTime createdAt;
  final DateTime updatedAt;

  ShaarliLink({
    required this.id,
    required this.url,
    required this.title,
    required this.description,
    required this.tags,
    required this.private,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ShaarliLink.fromJson(Map<String, dynamic> json) {
    final created = _parseDate(json['created']);
    return ShaarliLink(
      id: int.tryParse('${json['id']}') ?? 0,
      url: json['url'] is String ? json['url'] as String : '',
      title: json['title'] is String ? json['title'] as String : '',
      description: json['description'] is String ? json['description'] as String : '',
      tags: (json['tags'] as List<dynamic>? ?? const []).whereType<String>().toList(),
      private: json['private'] is bool ? json['private'] as bool : false,
      createdAt: created,
      updatedAt: _parseDate(json['updated'], fallback: created),
    );
  }

  static DateTime _parseDate(dynamic value, {DateTime? fallback}) {
    if (value is String && value.isNotEmpty) {
      final parsed = DateTime.tryParse(value);
      if (parsed != null) {
        return parsed;
      }
    }
    return fallback ?? DateTime.now();
  }

  factory ShaarliLink.empty() {
    return ShaarliLink(
      id: 0,
      url: '',
      title: '',
      description: '',
      tags: [],
      private: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }
}
