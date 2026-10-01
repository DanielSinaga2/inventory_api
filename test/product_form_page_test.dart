import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/models/product.dart';
import 'package:inventory_api_app/pages/product_form_page.dart';
import 'package:inventory_api_app/services/api_service.dart';

import 'fakes/crud_api_service.dart';

const existingProduct = Product(
  id: 'e74c3421-47de-4eba-9724-aa0fbbd0ff2c',
  name: 'Laptop',
  price: 120000,
  category: 'Elektronik',
  description: 'Deskripsi lama',
  quantity: 5,
  status: 'draft',
  imageUrl: 'asset-id',
);

Finder field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> fillProductForm(WidgetTester tester) async {
  for (final entry in {
    'Nama Produk': '  Buku Baru  ',
    'Harga': '120000',
    'Kategori': '  Buku  ',
    'Deskripsi': '  Deskripsi  ',
    'Stok': '2',
  }.entries) {
    await tester.ensureVisible(field(entry.key));
    await tester.enterText(field(entry.key), entry.value);
  }
}

Future<void> submitForm(WidgetTester tester, String label) async {
  final button = find.widgetWithText(FilledButton, label);
  await tester.pumpAndSettle();
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pump();
}

void main() {
  late FakeCrudApiService service;
  bool? result;

  setUp(() {
    service = FakeCrudApiService();
    result = null;
  });

  Future<void> openForm(WidgetTester tester, {Product? product}) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                result = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        ProductFormPage(product: product, apiService: service),
                  ),
                );
              },
              child: const Text('Buka'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
  }

  testWidgets('Create tampil dan validasi kosong mencegah request', (
    tester,
  ) async {
    await openForm(tester);
    expect(find.text('Tambah Product'), findsOneWidget);
    expect(find.text('published'), findsOneWidget);
    await submitForm(tester, 'Simpan');
    expect(find.text('Nama produk wajib diisi'), findsOneWidget);
    expect(find.text('Harga wajib diisi'), findsOneWidget);
    expect(find.text('Kategori wajib diisi'), findsOneWidget);
    expect(service.created, isEmpty);
  });

  testWidgets('Harga dan stok invalid atau negatif tidak dikirim', (
    tester,
  ) async {
    await openForm(tester);
    await fillProductForm(tester);
    for (final input in [
      [
        'abc',
        '1.5',
        'Harga harus berupa angka',
        'Stok harus berupa bilangan bulat',
      ],
      [
        'NaN',
        'abc',
        'Harga harus berupa angka',
        'Stok harus berupa bilangan bulat',
      ],
      ['-1', '-2', 'Harga tidak boleh negatif', 'Stok tidak boleh negatif'],
      ['', '', 'Harga wajib diisi', 'Stok wajib diisi'],
    ]) {
      await tester.ensureVisible(field('Harga'));
      await tester.enterText(field('Harga'), input[0]);
      await tester.ensureVisible(field('Stok'));
      await tester.enterText(field('Stok'), input[1]);
      await submitForm(tester, 'Simpan');
      expect(find.text(input[2]), findsOneWidget);
      expect(find.text(input[3]), findsOneWidget);
    }
    expect(service.created, isEmpty);
  });

  testWidgets('Create valid trim payload, loading, cegah duplikat, pop true', (
    tester,
  ) async {
    await openForm(tester);
    await fillProductForm(tester);
    await submitForm(tester, 'Simpan');
    expect(service.created.single.toJson(), {
      'name': 'Buku Baru',
      'price': '120000',
      'category': 'Buku',
      'description': 'Deskripsi',
      'quantity': 2,
      'status': 'published',
    });
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    await tester.tap(find.byType(FilledButton));
    expect(service.created, hasLength(1));
    service.createRequests.single.complete(null);
    await tester.pumpAndSettle();
    expect(result, isTrue);
    expect(find.byType(ProductFormPage), findsNothing);
  });

  for (final edit in [false, true]) {
    testWidgets(
      'Error ${edit ? 'PATCH' : 'POST'} mempertahankan data dan bisa retry',
      (tester) async {
        await openForm(tester, product: edit ? existingProduct : null);
        await fillProductForm(tester);
        await submitForm(tester, edit ? 'Update' : 'Simpan');
        final requests = edit ? service.updateRequests : service.createRequests;
        requests.single.completeError(const ApiException('403 Forbidden'));
        await tester.pumpAndSettle();
        expect(find.byType(ProductFormPage), findsOneWidget);
        expect(find.text('403 Forbidden'), findsOneWidget);
        expect(
          tester.widget<TextField>(field('Nama Produk')).controller?.text,
          '  Buku Baru  ',
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(result, isNull);
        await submitForm(tester, edit ? 'Update' : 'Simpan');
        expect(requests, hasLength(2));
        requests.last.complete(null);
        await tester.pumpAndSettle();
        expect(result, isTrue);
      },
    );
  }

  testWidgets('Edit terisi, PATCH memakai UUID asli, sukses pop true', (
    tester,
  ) async {
    await openForm(tester, product: existingProduct);
    expect(find.text('Edit Product'), findsOneWidget);
    for (final entry in {
      'Nama Produk': 'Laptop',
      'Harga': '120000',
      'Kategori': 'Elektronik',
      'Deskripsi': 'Deskripsi lama',
      'Stok': '5',
    }.entries) {
      expect(
        tester.widget<TextField>(field(entry.key)).controller?.text,
        entry.value,
      );
    }
    expect(find.text('draft'), findsOneWidget);
    await submitForm(tester, 'Update');
    expect(service.updatedIds.single, existingProduct.id);
    expect(service.updated.single.toJson().containsKey('image_url'), isFalse);
    expect(service.updated.single.toJson().containsKey('id'), isFalse);
    service.updateRequests.single.complete(null);
    await tester.pumpAndSettle();
    expect(result, isTrue);
  });

  testWidgets('Edit nullable aman dan ID kosong tidak mengirim request', (
    tester,
  ) async {
    await openForm(tester, product: const Product());
    expect(tester.widget<TextField>(field('Nama Produk')).controller?.text, '');
    expect(tester.widget<TextField>(field('Stok')).controller?.text, '0');
    await submitForm(tester, 'Update');
    expect(
      find.text('ID produk tidak tersedia. Muat ulang daftar produk.'),
      findsOneWidget,
    );
    expect(service.updated, isEmpty);
    expect(service.created, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Status existing tidak dikenal harus dipilih kembali', (
    tester,
  ) async {
    await openForm(
      tester,
      product: const Product(id: 'uuid', status: 'archived'),
    );
    await fillProductForm(tester);
    await submitForm(tester, 'Update');
    expect(find.text('Status wajib dipilih'), findsOneWidget);
    expect(service.updated, isEmpty);
  });

  for (final edit in [false, true]) {
    testWidgets('Submit setelah dispose aman (edit: $edit)', (tester) async {
      await openForm(tester, product: edit ? existingProduct : null);
      await fillProductForm(tester);
      await submitForm(tester, edit ? 'Update' : 'Simpan');
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      (edit ? service.updateRequests : service.createRequests).single.complete(
        null,
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  }
}
