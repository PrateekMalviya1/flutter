import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/product.dart';

class ProductService {
  ProductService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Product>> fetchProducts() async {
    final response = await _client.get(Uri.https('dummyjson.com', '/products'));
    if (response.statusCode != 200) {
      throw http.ClientException(
        'Product request failed with status ${response.statusCode}.',
      );
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final products = body['products'] as List<dynamic>;
    return products
        .map((item) => Product.fromJson(item as Map<String, dynamic>))
        .toList(growable: false);
  }
}
