/// MySQL product row represented for the storefront UI.
class Product {
  const Product({
    required this.sku,
    required this.code,
    required this.name,
    required this.brand,
    required this.price,
    required this.category,
    required this.gender,
    required this.size,
    required this.color,
  });

  final String sku;
  final String code;
  final String name;
  final String brand;
  final int price;
  final String category;
  final String gender;
  final String size;
  final String color;

  String get audience {
    final normalized = gender.toUpperCase();
    if (normalized == 'W' || gender.contains('여성')) return '여성';
    if (normalized == 'K' || gender.contains('키즈') || gender.contains('아동')) {
      return '아동';
    }
    return '남녀공용';
  }

  String get modelKey => code.isNotEmpty ? code : '$brand|$name';

  factory Product.fromJson(Map<String, dynamic> json) => Product(
    sku: '${json['SKU'] ?? ''}',
    code: '${json['pr_code'] ?? ''}',
    name: '${json['pr_name'] ?? ''}',
    brand: '${json['pr_brand'] ?? ''}',
    price: (json['pr_price'] as num?)?.round() ?? 0,
    category: '${json['category'] ?? ''}',
    gender: '${json['gender'] ?? ''}',
    size: '${json['size'] ?? ''}',
    color: '${json['color'] ?? ''}',
  );
}
