// Field aplikasi berdasarkan response products yang diverifikasi di Postman.
class Product {
  const Product({
    this.id,
    this.status,
    this.name,
    this.price,
    this.imageUrl,
    this.category,
    this.description,
    this.quantity,
  });

  final String? id;
  final String? status;
  final String? name;
  final double? price;
  final String? imageUrl;
  final String? category;
  final String? description;
  final int? quantity;

  factory Product.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    final parsedPrice = _parseNumber(json['price']);
    final parsedQuantity = _parseNumber(json['quantity']);

    return Product(
      id: rawId is String || rawId is num ? rawId.toString() : null,
      status: _parseString(json['status']),
      name: _parseString(json['name']),
      // Nilai tidak valid tetap null, bukan diubah menjadi harga nol.
      price: parsedPrice != null && parsedPrice.isFinite ? parsedPrice : null,
      imageUrl: _parseString(json['image_url']),
      category: _parseString(json['category']),
      description: _parseString(json['description']),
      // Stok pecahan dianggap tidak valid, bukan dibulatkan diam-diam.
      quantity:
          parsedQuantity != null &&
              parsedQuantity.isFinite &&
              parsedQuantity == parsedQuantity.truncateToDouble()
          ? parsedQuantity.toInt()
          : null,
    );
  }

  static String? _parseString(dynamic value) => value is String ? value : null;

  static double? _parseNumber(dynamic value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  // Payload POST/PATCH tanpa id. Field null diabaikan, bukan untuk menghapus nilai.
  Map<String, dynamic> toJson() {
    final amount = price;
    if (amount != null && !amount.isFinite) {
      throw ArgumentError('Harga harus berupa angka yang valid');
    }
    return {
      if (status != null) 'status': status,
      if (name != null) 'name': name,
      if (amount != null)
        'price': amount == amount.truncateToDouble()
            ? amount.toStringAsFixed(0)
            : amount.toString(),
      if (imageUrl != null) 'image_url': imageUrl,
      if (category != null) 'category': category,
      if (description != null) 'description': description,
      if (quantity != null) 'quantity': quantity,
    };
  }
}
