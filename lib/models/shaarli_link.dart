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
    return ShaarliLink(
      id: json['id'],
      url: json['url'],
      title: json['title'],
      description: json['description'],
      tags: List<String>.from(json['tags']),
      private: json['private'] ?? false,
      createdAt: json['created'].isEmpty
          ? DateTime.now()
          : DateTime.parse(json['created']),
      updatedAt: json['updated'].isEmpty
          ? DateTime.parse(json['created'])
          : DateTime.parse(json['updated']),
    );
  }
}
