class Category {
  final String id;
  final String categoryName;
  final String? categoryImage;

  Category({
    required this.id,
    required this.categoryName,
    this.categoryImage,
  });

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'].toString(),
      categoryName: json['category_name'] ?? '',
      categoryImage: json['category_image'],
    );
  }
}
