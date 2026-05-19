class MenuItemModel {
  final int id;
  final String title;
  final String url;
  final int parent;

  MenuItemModel({
    required this.id,
    required this.title,
    required this.url,
    required this.parent,
  });

  factory MenuItemModel.fromJson(Map<String, dynamic> json) {
    return MenuItemModel(
      id: json['ID'],
      title: json['title'],
      url: json['url'],
      parent: json['parent'] ?? 0,
    );
  }
}
