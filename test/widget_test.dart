import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/main.dart';
import 'package:inventory_api_app/pages/dashboard_page.dart';
import 'package:inventory_api_app/pages/login_page.dart';
import 'package:inventory_api_app/pages/product_page.dart';
import 'package:inventory_api_app/services/auth_service.dart';
import 'fakes/auth_test_backend.dart';

void main() {
  late AuthTestBackend backend;
  late AuthService auth;
  setUp(() {
    backend = AuthTestBackend();
    auth = AuthService(dio: backend.dio);
  });
  tearDown(() => auth.dispose());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(MyApp(authService: auth));
  }

  Future<void> fill(
    WidgetTester tester, {
    String email = 'student@example.invalid',
  }) async {
    await tester.enterText(find.byType(TextFormField).first, email);
    await tester.enterText(find.byType(TextFormField).last, 'test-password');
  }

  Future<void> submit(WidgetTester tester) async {
    await tester.ensureVisible(find.text('LOGIN'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('LOGIN'));
    await tester.pump();
  }

  testWidgets(
    'Form kosong dan email invalid ditolak tanpa request; password tersembunyi',
    (tester) async {
      await open(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField).last).obscureText,
        isTrue,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
      await submit(tester);
      expect(find.text('Email tidak boleh kosong'), findsOneWidget);
      expect(find.text('Password tidak boleh kosong'), findsOneWidget);
      await fill(tester, email: 'invalid-email');
      await submit(tester);
      expect(find.text('Format email tidak valid'), findsOneWidget);
      expect(backend.requests, isEmpty);
      expect(find.byType(DashboardPage), findsNothing);
    },
  );

  testWidgets(
    'Login sukses membuka Dashboard, GET memakai token, logout menghapus sesi dan route',
    (tester) async {
      await open(tester);
      await fill(tester);
      await submit(tester);
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsNothing);
      expect(find.byType(DashboardPage), findsOneWidget);
      expect(
        Navigator.of(tester.element(find.byType(DashboardPage))).canPop(),
        isFalse,
      );
      await tester.ensureVisible(find.text('Kelola Produk'));
      await tester.tap(find.text('Kelola Produk'));
      await tester.pumpAndSettle();
      expect(find.byType(ProductPage), findsOneWidget);
      expect(backend.requests.last.path, '/items/products');
      expect(
        backend.requests.last.headers['Authorization'],
        'Bearer test-only-token',
      );
      await tester.pageBack();
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Logout'));
      await tester.pumpAndSettle();
      expect(find.byType(LoginPage), findsOneWidget);
      expect(find.byType(DashboardPage), findsNothing);
      expect(backend.dio.options.headers.containsKey('Authorization'), isFalse);
      expect(
        Navigator.of(tester.element(find.byType(LoginPage))).canPop(),
        isFalse,
      );
      expect(
        tester.widget<TextField>(find.byType(TextField).last).controller!.text,
        isEmpty,
      );
    },
  );

  for (final entry in {
    401: 'Email atau password salah.',
    403: 'Akses ditolak.',
    500: 'Terjadi kesalahan pada server.',
    0: 'Tidak dapat terhubung ke server.',
  }.entries) {
    testWidgets(
      'Login gagal ${entry.key} tetap di form dan menampilkan error',
      (tester) async {
        backend.status = entry.key == 0 ? 200 : entry.key;
        if (entry.key == 0) {
          backend.errorType = DioExceptionType.connectionError;
        }
        await open(tester);
        await fill(tester);
        await submit(tester);
        await tester.pumpAndSettle();
        expect(find.text(entry.value), findsOneWidget);
        expect(find.byType(LoginPage), findsOneWidget);
        expect(find.byType(DashboardPage), findsNothing);
        expect(
          tester
              .widget<TextField>(find.byType(TextField).last)
              .controller!
              .text,
          isEmpty,
        );
        expect(
          tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
          isNotNull,
        );
      },
    );
  }

  testWidgets('Loading menonaktifkan tombol dan mencegah double submit', (
    tester,
  ) async {
    backend.pending = Completer<void>();
    await open(tester);
    await fill(tester);
    // Simpan callback untuk mensimulasikan dua submit sebelum rebuild.
    final submitAction = tester
        .widget<FilledButton>(find.byType(FilledButton))
        .onPressed!;
    submitAction();
    submitAction();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    expect(backend.requests, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNull,
    );
    expect(find.byType(DashboardPage), findsNothing);
    backend.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.byType(DashboardPage), findsOneWidget);
  });

  testWidgets('Respons tanpa token tidak membuka Dashboard', (tester) async {
    backend.loginBody = {'data': {}};
    await open(tester);
    await fill(tester);
    await submit(tester);
    await tester.pumpAndSettle();
    expect(
      find.text('Respons login tidak valid: access token tidak tersedia.'),
      findsOneWidget,
    );
    expect(find.byType(DashboardPage), findsNothing);
  });

  testWidgets(
    'Request selesai setelah halaman ditutup tidak memanggil setState',
    (tester) async {
      backend.pending = Completer<void>();
      await open(tester);
      await fill(tester);
      await submit(tester);
      await tester.pumpWidget(const SizedBox());
      backend.pending!.complete();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
