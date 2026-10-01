import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_api_app/models/product.dart';

import 'fixtures/product_fixture.dart';

void main() {
  test('Harga payload memakai string tanpa desimal untuk bilangan bulat', () {
    expect(const Product(price: 120000).toJson()['price'], '120000');
    expect(const Product(price: 12.5).toJson()['price'], '12.5');
    expect(
      () => const Product(price: double.nan).toJson(),
      throwsArgumentError,
    );
  });
  test('Field respons Postman diparsing dan payload tidak memuat id', () {
    final product = Product.fromJson(productFixture);
    expect(product.id, 'abc');
    expect(product.status, 'published');
    expect(product.name, 'Laptop');
    expect(product.price, 7500000.0);
    expect(product.imageUrl, 'asset-id');
    expect(product.category, 'Elektronik');
    expect(product.description, 'Laptop gaming');
    expect(product.quantity, 5);
    expect(
      product.toJson(),
      {...productFixture, 'price': '7500000'}..remove('id'),
    );
  });

  test('Record nullable tetap dapat diparsing', () {
    final product = Product.fromJson(nullableProductFixture);
    expect(product.name, isNull);
    expect(product.price, isNull);
    expect(product.imageUrl, isNull);
    expect(product.category, isNull);
    expect(product.description, isNull);
    expect(product.quantity, isNull);
  });

  test('Harga 120000 diterima sebagai integer, double, dan string', () {
    for (final value in [120000, 120000.0, '120000']) {
      expect(Product.fromJson({'price': value}).price, 120000.0);
    }
  });

  test('Quantity menerima bilangan bulat dan menolak nilai tidak valid', () {
    for (final value in [5, 5.0, '5', '5.0']) {
      expect(Product.fromJson({'quantity': value}).quantity, 5);
    }
    for (final value in [null, 'abc', true, [], {}, 1.5, 'NaN', 'Infinity']) {
      expect(Product.fromJson({'quantity': value}).quantity, isNull);
    }
  });

  test('Harga menerima integer, double, string numerik, dan null', () {
    for (final value in [100, 100.0, '100', ' 100.0 ']) {
      expect(Product.fromJson({'price': value}).price, 100.0);
    }
    for (final value in [null, 'abc', true, [], {}, 'NaN', 'Infinity']) {
      expect(Product.fromJson({'price': value}).price, isNull);
    }
  });

  test('Field kosong atau bertipe tidak sesuai aman diparsing', () {
    final empty = Product.fromJson({});
    expect(empty.id, isNull);
    expect(empty.name, isNull);
    expect(empty.price, isNull);
    expect(Product.fromJson({'id': 12}).id, '12');
    expect(Product.fromJson({'id': 'uuid'}).id, 'uuid');
    expect(Product.fromJson({'id': [], 'name': 42}).id, isNull);
    expect(Product.fromJson({'name': 42}).name, isNull);
  });

  test('Payload hanya berisi field yang tersedia tanpa id', () {
    expect(const Product(id: '12', name: 'Buku', price: 0).toJson(), {
      'name': 'Buku',
      'price': '0',
    });
    expect(const Product().toJson(), isEmpty);
  });
}
