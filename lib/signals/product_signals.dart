import 'package:signals_flutter/signals_flutter.dart';

import '../models/product.dart';

/// Reactive state khusus halaman produk; service dan endpoint tetap terpisah.
class ProductSignals {
  // Signal menyimpan state API yang dapat berubah secara reactive.
  final products = signal<List<Product>>([]);
  final isLoading = signal(true);
  final errorMessage = signal<String?>(null);
  final selectedProduct = signal<Product?>(null);

  // Computed menghasilkan nilai turunan dari products, tanpa state manual.
  late final productCount = computed(() => products.value.length);

  void dispose() {
    products.dispose();
    isLoading.dispose();
    errorMessage.dispose();
    selectedProduct.dispose();
    productCount.dispose();
  }
}
