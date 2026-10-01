import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/utils/currency_formatter.dart';

void main() {
  test('Format rupiah tanpa desimal dan aman terhadap nilai kosong', () {
    expect(formatRupiah(120000), 'Rp120.000');
    expect(formatRupiah(15000000), 'Rp15.000.000');
    expect(formatRupiah(250000), 'Rp250.000');
    expect(formatRupiah(120000.6), 'Rp120.001');
    expect(formatRupiah(null), 'Rp0');
    expect(formatRupiah(0), 'Rp0');
    expect(formatRupiah(double.nan), 'Rp0');
    expect(formatRupiah(double.infinity), 'Rp0');
  });
}
