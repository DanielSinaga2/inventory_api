import 'dart:async';
import 'package:dio/dio.dart';
import 'package:inventory_api_app/models/product_image.dart';

import 'package:inventory_api_app/models/product.dart';
import 'package:inventory_api_app/services/api_service.dart';

class FakeCrudApiService extends ApiService {
  List<Product> serverProducts = [];
  int getCalls = 0;
  final created = <Product>[];
  final updated = <Product>[];
  final updatedIds = <String>[];
  final deletedIds = <String>[];
  final createRequests = <Completer<Product?>>[];
  final updateRequests = <Completer<Product?>>[];
  final deleteRequests = <Completer<void>>[];
  final uploads = <ProductImage>[];
  final uploadRequests = <Completer<String>>[];

  @override
  Future<String> uploadProductImage(
    ProductImage image, {
    ProgressCallback? onSendProgress,
  }) {
    uploads.add(image);
    onSendProgress?.call(1, 2);
    final request = Completer<String>();
    uploadRequests.add(request);
    return request.future;
  }

  @override
  Future<List<Product>> getProducts({
    int? limit,
    int offset = 0,
    String search = '',
  }) async {
    getCalls++;
    return List.of(serverProducts);
  }

  @override
  Future<Product?> createProduct(Product product) {
    created.add(product);
    final request = Completer<Product?>();
    createRequests.add(request);
    return request.future;
  }

  @override
  Future<Product?> updateProduct(String id, Product product) {
    updatedIds.add(id);
    updated.add(product);
    final request = Completer<Product?>();
    updateRequests.add(request);
    return request.future;
  }

  @override
  Future<void> deleteProduct(String id) {
    deletedIds.add(id);
    final request = Completer<void>();
    deleteRequests.add(request);
    return request.future;
  }
}
