import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/pages/dashboard_page.dart';
import 'package:inventory_api_app/services/auth_service.dart';
import 'package:inventory_api_app/theme/app_theme.dart';

void main() {
  late Dio dio;
  late AuthService auth;
  late List<Map<String, dynamic>> products;
  late List<int> offsets;
  bool fail = false;

  setUp(() {
    products = [];
    offsets = [];
    fail = false;
    dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (fail) {
            handler.reject(
              DioException(
                requestOptions: options,
                type: DioExceptionType.badResponse,
                response: Response(requestOptions: options, statusCode: 500),
              ),
            );
            return;
          }
          final offset = options.queryParameters['offset'] as int? ?? 0;
          final limit = options.queryParameters['limit'] as int;
          offsets.add(offset);
          handler.resolve(
            Response(
              requestOptions: options,
              statusCode: 200,
              data: {'data': products.skip(offset).take(limit).toList()},
            ),
          );
        },
      ),
    );
    auth = AuthService(dio: dio);
  });
  tearDown(() => auth.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: DashboardPage(authService: auth),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'Ringkasan menghitung seluruh halaman produk dan harga dikali stok',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      products = List.generate(
        101,
        (i) => {'id': '$i', 'price': '2500', 'quantity': 3},
      );
      await open(tester);
      expect(find.text('101'), findsOneWidget);
      expect(find.text('303'), findsOneWidget);
      expect(find.text('Rp 757.500'), findsOneWidget);
      expect(offsets, [0, 100, 101]);
      expect(find.text('Total Produk'), findsOneWidget);
      expect(find.text('Total Stok'), findsOneWidget);
      expect(find.text('Nilai Total Inventori'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Data kosong bernilai nol; refresh menghitung data terbaru dengan nilai null',
    (tester) async {
      await open(tester);
      expect(find.text('0'), findsNWidgets(2));
      expect(find.text('Rp 0'), findsOneWidget);
      products = [
        {'id': '1', 'price': '1500', 'quantity': 2},
        {'id': '2', 'price': null, 'quantity': 4},
        {'id': '3', 'price': '9000', 'quantity': null},
      ];
      await tester.tap(find.byTooltip('Muat ulang'));
      await tester.pumpAndSettle();
      expect(find.text('3'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
      expect(find.text('Rp 3.000'), findsOneWidget);
    },
  );

  testWidgets('Kegagalan API menampilkan error dan bisa dicoba kembali', (
    tester,
  ) async {
    fail = true;
    await open(tester);
    expect(find.text('500: Server bermasalah'), findsOneWidget);
    expect(find.text('Rp 0'), findsNothing);
    fail = false;
    await tester.tap(find.text('Coba lagi'));
    await tester.pumpAndSettle();
    expect(find.text('500: Server bermasalah'), findsNothing);
    expect(find.text('Rp 0'), findsOneWidget);
  });
}
