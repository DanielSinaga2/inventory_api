import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/models/product.dart';
import 'package:inventory_api_app/pages/product_page.dart';
import 'package:inventory_api_app/services/api_service.dart';

import 'fixtures/product_fixture.dart';

class _TestApiService extends ApiService {
  final requests = <Completer<List<Product>>>[];

  @override
  Future<List<Product>> getProducts({
    int? limit,
    int offset = 0,
    String search = '',
  }) {
    final request = Completer<List<Product>>();
    requests.add(request);
    return request.future;
  }
}

void main() {
  late _TestApiService service;

  setUp(() => service = _TestApiService());

  Future<void> openPage(WidgetTester tester) =>
      tester.pumpWidget(MaterialApp(home: ProductPage(apiService: service)));

  testWidgets(
    'Layar kecil menampilkan dua kolom dan tombol Lihat membuka detail',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await openPage(tester);
      service.requests.single.complete([
        const Product(
          name: 'Produk Kiri',
          description: 'Detail produk pertama',
        ),
        const Product(name: 'Produk Kanan'),
      ]);
      await tester.pumpAndSettle();
      final left = tester.getTopLeft(find.text('Produk Kiri'));
      final right = tester.getTopLeft(find.text('Produk Kanan'));
      expect(left.dy, right.dy);
      expect(left.dx, lessThan(right.dx));
      expect(find.byType(GridView), findsOneWidget);
      await tester.ensureVisible(find.text('Lihat').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lihat').first);
      await tester.pumpAndSettle();
      expect(find.text('Detail produk pertama'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Loading menjadi daftar dengan harga dan fallback null', (
    tester,
  ) async {
    await openPage(tester);
    expect(service.requests, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    service.requests.single.complete([
      Product.fromJson({...productFixture, 'image_url': null}),
      Product.fromJson({...nullableProductFixture, 'status': null}),
    ]);
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    for (final text in [
      'Laptop',
      'Elektronik',
      'Rp7.500.000',
      'Stok: 5',
      'Status: published',
      'Tanpa Nama',
      'Tanpa Kategori',
      'Rp0',
      'Stok: -',
      'Status: -',
    ]) {
      expect(find.text(text), findsOneWidget);
    }
    expect(find.byIcon(Icons.image_not_supported_outlined), findsNWidgets(2));
    expect(find.byType(FloatingActionButton), findsOneWidget);
  });

  testWidgets('List kosong menampilkan empty state', (tester) async {
    await openPage(tester);
    service.requests.single.complete([]);
    await tester.pumpAndSettle();
    expect(find.text('Belum ada produk'), findsOneWidget);
    expect(find.text('Gagal memuat produk'), findsNothing);
  });

  testWidgets('Error menampilkan pesan dan Coba Lagi menjalankan GET ulang', (
    tester,
  ) async {
    await openPage(tester);
    service.requests.single.completeError(
      const ApiException('401 Unauthorized'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Gagal memuat produk'), findsOneWidget);
    expect(find.text('401 Unauthorized'), findsOneWidget);
    await tester.tap(find.text('Coba Lagi'));
    await tester.pump();
    expect(service.requests, hasLength(2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('401 Unauthorized'), findsNothing);
    service.requests.last.complete([const Product(name: 'Berhasil')]);
    await tester.pumpAndSettle();
    expect(find.text('Berhasil'), findsOneWidget);
  });

  for (final fails in [false, true]) {
    testWidgets('Respons setelah dispose aman (error: $fails)', (tester) async {
      await openPage(tester);
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      if (fails) {
        service.requests.single.completeError(
          const ApiException('Koneksi gagal'),
        );
      } else {
        service.requests.single.complete([]);
      }
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Gambar gagal menjadi placeholder dan list tetap tampil', (
    tester,
  ) async {
    await openPage(tester);
    // HTTP pada widget test ditolak oleh binding, memicu errorBuilder.
    service.requests.single.complete([Product.fromJson(productFixture)]);
    await tester.pumpAndSettle();
    final image = tester.widget<Image>(find.byType(Image));
    expect(
      (image.image as NetworkImage).url,
      'https://pos.cicd.web.id/assets/asset-id',
    );
    expect(image.fit, BoxFit.cover);
    expect(find.byIcon(Icons.image_not_supported_outlined), findsOneWidget);
    expect(find.text('Laptop'), findsOneWidget);
    expect(find.text('Gagal memuat produk'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
