import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/pages/product_form_page.dart';
import 'package:inventory_api_app/services/api_service.dart';
import 'fakes/crud_api_service.dart';
import 'fixtures/image_fixture.dart';
import 'product_form_page_test.dart' show fillProductForm, submitForm;

void main() {
  late FakeCrudApiService service;
  setUp(() => service = FakeCrudApiService());

  Future<void> openForm(
    WidgetTester tester,
    Future<XFile?> Function() pick,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProductFormPage(apiService: service, pickImage: pick),
      ),
    );
    await tester.ensureVisible(find.text('Pilih gambar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Pilih gambar'));
    // Codec decoding runs outside the fake test clock.
    await tester.runAsync(
      () async => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Upload sebelum POST; retry POST tidak mengunggah gambar lagi', (
    tester,
  ) async {
    await openForm(
      tester,
      () async =>
          XFile.fromData(imageFixture(), name: 'foto.png', path: 'foto.png'),
    );
    expect(find.text('foto.png'), findsOneWidget);
    await fillProductForm(tester);
    await submitForm(tester, 'Simpan');
    expect(service.uploads, hasLength(1));
    expect(service.created, isEmpty);
    expect(find.text('Mengunggah gambar 50%'), findsOneWidget);
    service.uploadRequests.single.complete('asset-uploaded');
    await tester.pump();
    expect(service.created.single.imageUrl, 'asset-uploaded');
    service.createRequests.single.completeError(
      const ApiException('Server sedang sibuk'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Server sedang sibuk'), findsOneWidget);
    await submitForm(tester, 'Simpan');
    expect(service.uploads, hasLength(1));
    expect(service.created.last.toJson()['image_url'], 'asset-uploaded');
    service.createRequests.last.completeError(
      const ApiException('Coba lagi nanti'),
    );
    await tester.pumpAndSettle();
  });

  testWidgets('Upload gagal tidak mengirim POST dan pilihan gambar tetap ada', (
    tester,
  ) async {
    await openForm(
      tester,
      () async =>
          XFile.fromData(imageFixture(), name: 'foto.png', path: 'foto.png'),
    );
    await fillProductForm(tester);
    await submitForm(tester, 'Simpan');
    service.uploadRequests.single.completeError(
      const ApiException('Upload ditolak'),
    );
    await tester.pumpAndSettle();
    expect(service.created, isEmpty);
    expect(find.text('Upload ditolak'), findsOneWidget);
    expect(find.text('foto.png'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
  });

  testWidgets('Batal picker tidak menambah gambar atau request', (
    tester,
  ) async {
    await openForm(tester, () async => null);
    expect(find.text('Pilih gambar'), findsOneWidget);
    expect(service.uploads, isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('File non-gambar ditolak sebelum upload', (tester) async {
    await openForm(
      tester,
      () async => XFile.fromData(
        imageFixture().sublist(0, 3),
        name: 'palsu.png',
        path: 'palsu.png',
      ),
    );
    expect(find.text('Gunakan gambar JPG, PNG, atau WebP.'), findsOneWidget);
    expect(service.uploads, isEmpty);
  });
}
