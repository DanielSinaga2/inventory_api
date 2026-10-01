import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/models/product.dart';
import 'package:inventory_api_app/pages/product_page.dart';
import 'package:inventory_api_app/services/api_service.dart';

import 'fakes/crud_api_service.dart';
import 'product_form_page_test.dart' show fillProductForm, submitForm;

const product = Product(
  id: 'original-uuid',
  name: 'Buku',
  price: 2500,
  category: 'Buku',
  quantity: 1,
  status: 'published',
);

void main() {
  late FakeCrudApiService service;

  setUp(() {
    service = FakeCrudApiService()..serverProducts = [product];
  });

  Future<void> openPage(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProductPage(apiService: service)),
    );
    await tester.pumpAndSettle();
  }

  Future<void> confirmDelete(WidgetTester tester) async {
    await tester.ensureVisible(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Produk?'), findsOneWidget);
    expect(
      find.text('Apakah Anda yakin ingin menghapus "Buku"?'),
      findsOneWidget,
    );
    await tester.tap(find.text('Hapus'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('Batal delete tidak mengirim request atau refresh', (
    tester,
  ) async {
    await openPage(tester);
    await tester.ensureVisible(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Hapus Produk?'), findsOneWidget);
    await tester.tap(find.text('Batal'));
    await tester.pumpAndSettle();
    expect(service.deletedIds, isEmpty);
    expect(service.getCalls, 1);
    expect(find.byTooltip('Delete'), findsOneWidget);
  });

  testWidgets(
    'Delete memakai ID asli, loading, sukses mengambil ulang server',
    (tester) async {
      await openPage(tester);
      await confirmDelete(tester);
      expect(service.deletedIds, ['original-uuid']);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('Delete'), findsNothing);
      expect(
        tester
            .widget<FloatingActionButton>(find.byType(FloatingActionButton))
            .onPressed,
        isNull,
      );
      service.serverProducts = [];
      service.deleteRequests.single.complete();
      await tester.pumpAndSettle();
      expect(service.getCalls, 2);
      expect(find.text('Belum ada produk'), findsOneWidget);
      expect(find.text('Produk berhasil dihapus'), findsOneWidget);
    },
  );

  testWidgets('Delete gagal tidak menghapus item dan bisa diulang', (
    tester,
  ) async {
    await openPage(tester);
    await confirmDelete(tester);
    service.deleteRequests.single.completeError(
      const ApiException('403 Forbidden'),
    );
    await tester.pumpAndSettle();
    expect(find.text('403 Forbidden'), findsOneWidget);
    expect(find.byTooltip('Edit'), findsOneWidget);
    expect(find.byTooltip('Delete'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(service.getCalls, 1);
    await confirmDelete(tester);
    expect(service.deletedIds, hasLength(2));
    service.deleteRequests.last.complete();
    await tester.pumpAndSettle();
  });

  testWidgets('ID null atau kosong tidak memanggil DELETE', (tester) async {
    service.serverProducts = [const Product(name: 'Tanpa ID')];
    await openPage(tester);
    await tester.ensureVisible(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Delete'));
    await tester.pumpAndSettle();
    expect(
      find.text('ID produk tidak tersedia. Muat ulang daftar produk.'),
      findsOneWidget,
    );
    expect(service.deletedIds, isEmpty);
    expect(find.byType(AlertDialog), findsNothing);
  });

  for (final edit in [false, true]) {
    testWidgets(
      '${edit ? 'PATCH' : 'POST'} sukses memuat ulang data dari server',
      (tester) async {
        await openPage(tester);
        await tester.ensureVisible(
          find.byTooltip(edit ? 'Edit' : 'Tambah Product'),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip(edit ? 'Edit' : 'Tambah Product'));
        await tester.pumpAndSettle();
        await fillProductForm(tester);
        await submitForm(tester, edit ? 'Update' : 'Simpan');
        // Sengaja berbeda dari input form: UI wajib memakai hasil GET terbaru.
        service.serverProducts = [
          const Product(id: 'server-uuid', name: 'Hasil Server'),
        ];
        (edit ? service.updateRequests : service.createRequests).single
            .complete(null);
        await tester.pumpAndSettle();
        expect(service.getCalls, 2);
        expect(find.text('Hasil Server'), findsOneWidget);
        expect(find.text('Buku Baru'), findsNothing);
      },
    );
  }

  testWidgets('Kembali dari form tanpa menyimpan tidak refresh', (
    tester,
  ) async {
    await openPage(tester);
    await tester.tap(find.byTooltip('Tambah Product'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(service.getCalls, 1);
    expect(service.created, isEmpty);
  });

  testWidgets('DELETE selesai setelah dispose aman', (tester) async {
    await openPage(tester);
    await confirmDelete(tester);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    service.deleteRequests.single.complete();
    await tester.pumpAndSettle();
    expect(service.getCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
