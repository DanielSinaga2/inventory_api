import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/models/product.dart';
import 'package:inventory_api_app/services/api_service.dart';
import 'package:inventory_api_app/pages/product_page.dart';

class _SearchService extends ApiService {
  final requests =
      <
        ({
          int? limit,
          int offset,
          String search,
          Completer<List<Product>> result,
        })
      >[];
  @override
  Future<List<Product>> getProducts({
    int? limit,
    int offset = 0,
    String search = '',
  }) {
    final result = Completer<List<Product>>();
    requests.add((
      limit: limit,
      offset: offset,
      search: search,
      result: result,
    ));
    return result.future;
  }
}

void main() {
  late _SearchService service;
  setUp(() => service = _SearchService());
  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(home: ProductPage(apiService: service)),
    );
  }

  Future<void> complete(WidgetTester tester, List<Product> products) async {
    service.requests.last.result.complete(products);
    await tester.pumpAndSettle();
  }

  List<Product> products(int count) =>
      List.generate(count, (i) => Product(id: '$i', name: 'Produk $i'));

  testWidgets('Search tetap fokus ketika keyboard Android muncul', (
    tester,
  ) async {
    await open(tester);
    await complete(tester, []);
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
    await tester.enterText(find.byType(TextField), 'Laptop');
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.requests.last.search, 'Laptop');
    await complete(tester, [const Product(name: 'Laptop')]);
    expect(
      tester.widget<EditableText>(find.byType(EditableText)).focusNode.hasFocus,
      isTrue,
    );
  });

  testWidgets('Search debounce mengabaikan respons lama dan bisa dihapus', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(find.byType(TextField), 'Bu');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField), 'Buku');
    service.requests.first.result.complete([
      const Product(name: 'Respons lama'),
    ]);
    await tester.pump(const Duration(milliseconds: 200));
    expect(service.requests, hasLength(1));
    expect(find.text('Respons lama'), findsNothing);
    await tester.pump(const Duration(milliseconds: 200));
    expect(service.requests.last.search, 'Buku');
    expect(service.requests.last.offset, 0);
    await complete(tester, [const Product(name: 'Buku baru')]);
    expect(find.text('Buku baru'), findsOneWidget);
    await tester.tap(find.byTooltip('Hapus pencarian'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.requests.last.search, '');
    await complete(tester, []);
  });

  testWidgets(
    'Pagination 10 item, next dan previous mengambil halaman server',
    (tester) async {
      await open(tester);
      expect(service.requests.single.limit, 11);
      await complete(tester, products(11));
      expect(find.text('Produk 10'), findsNothing);
      await tester.tap(find.byTooltip('Halaman berikutnya'));
      await tester.pump();
      expect(service.requests.last.offset, 10);
      await complete(tester, [const Product(name: 'Halaman dua')]);
      expect(find.text('Halaman 2'), findsOneWidget);
      expect(find.text('Halaman dua'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Halaman berikutnya',
              ),
            )
            .onPressed,
        isNull,
      );
      await tester.tap(find.byTooltip('Halaman sebelumnya'));
      await tester.pump();
      expect(service.requests.last.offset, 0);
      await complete(tester, products(10));
      expect(find.text('Halaman 1'), findsOneWidget);
      expect(
        tester
            .widget<IconButton>(
              find.byWidgetPredicate(
                (w) => w is IconButton && w.tooltip == 'Halaman berikutnya',
              ),
            )
            .onPressed,
        isNull,
      );
    },
  );

  testWidgets('Spasi tambahan tidak membatalkan pencarian yang menunggu', (
    tester,
  ) async {
    await open(tester);
    await complete(tester, []);
    await tester.enterText(find.byType(TextField), 'Buku');
    await tester.pump(const Duration(milliseconds: 100));
    await tester.enterText(find.byType(TextField), 'Buku ');
    await tester.pump(const Duration(milliseconds: 400));
    expect(service.requests, hasLength(2));
    expect(service.requests.last.search, 'Buku');
    await complete(tester, []);
    expect(find.text('Produk tidak ditemukan'), findsOneWidget);
  });

  testWidgets(
    'Search dari halaman dua kembali ke halaman satu dan punya empty state',
    (tester) async {
      await open(tester);
      await complete(tester, products(11));
      await tester.tap(find.byTooltip('Halaman berikutnya'));
      await tester.pump();
      await complete(tester, products(2));
      await tester.enterText(find.byType(TextField), 'Tidak ada');
      await tester.pump(const Duration(milliseconds: 400));
      expect(service.requests.last.offset, 0);
      await complete(tester, []);
      expect(find.text('Produk tidak ditemukan'), findsOneWidget);
      expect(find.text('Halaman 1'), findsOneWidget);
    },
  );

  for (final empty in [true, false]) {
    testWidgets('Pull-to-refresh dapat ditarik pada list kosong: $empty', (
      tester,
    ) async {
      await open(tester);
      await complete(tester, empty ? [] : [const Product(name: 'Produk lama')]);
      await tester.drag(
        find.byType(empty ? ListView : GridView),
        const Offset(0, 350),
      );
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(service.requests, hasLength(2));
      expect(service.requests.last.offset, 0);
      await complete(tester, [const Product(name: 'Produk terbaru')]);
      expect(find.text('Produk terbaru'), findsOneWidget);
    });
  }

  testWidgets('Refresh gagal mempertahankan data, bukan menganggapnya kosong', (
    tester,
  ) async {
    await open(tester);
    await complete(tester, [const Product(name: 'Tetap ada')]);
    await tester.tap(find.byTooltip('Muat ulang'));
    await tester.pump();
    service.requests.last.result.completeError(
      const ApiException('Koneksi gagal'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tetap ada'), findsOneWidget);
    expect(find.text('Koneksi gagal'), findsOneWidget);
  });

  testWidgets('Halaman yang menjadi kosong kembali ke halaman sebelumnya', (
    tester,
  ) async {
    await open(tester);
    await complete(tester, products(11));
    await tester.tap(find.byTooltip('Halaman berikutnya'));
    await tester.pump();
    service.requests.last.result.complete([]);
    await tester.pump();
    expect(service.requests.last.offset, 0);
    await complete(tester, products(10));
    expect(find.text('Halaman 1'), findsOneWidget);
  });
}
