import '../config.dart';

class Product {
  final String id;
  final String name;
  final String category;
  final String article;
  final String color;
  final double score;
  final String imageUrl;

  Product({
    required this.id,
    required this.name,
    required this.category,
    required this.article,
    required this.color,
    required this.score,
    required this.imageUrl,
  });

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: (json['name'] ?? 'Unknown').toString(),
      category: (json['category'] ?? '').toString(),
      article: (json['article'] ?? '').toString(),
      color: (json['color'] ?? '').toString(),
      score: (json['score'] as num).toDouble(),
      imageUrl: '$kBaseUrl${json['image_url']}',
    );
  }
}