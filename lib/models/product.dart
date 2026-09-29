class Product {
  final String id;
  final String productName;
  final String productCode;
  final double price;
  final double? mrp;
  final int stock;
  final String? imageUrl;
  final String? categoryId;
  final String? categoryName;

  Product({
    required this.id,
    required this.productName,
    required this.productCode,
    required this.price,
    this.mrp,
    required this.stock,
    this.imageUrl,
    this.categoryId,
    this.categoryName,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      productName: json['product_name'] ?? '',
      productCode: json['product_code'] ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      mrp: json['mrp'] != null ? (json['mrp'] as num).toDouble() : null,
      stock: json['stock'] ?? 0,
      imageUrl: json['image_url'],
      categoryId: json['category_id']?.toString(),
      categoryName: json['categories'] != null ? json['categories']['category_name'] : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_name': productName,
      'product_code': productCode,
      'price': price,
      'mrp': mrp,
      'stock': stock,
      'image_url': imageUrl,
      'category_id': categoryId,
    };
  }
}

class CartItem {
  final Product product;
  int quantity;

  CartItem({
    required this.product,
    this.quantity = 1,
  });
}
