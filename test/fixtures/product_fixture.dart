// Bentuk respons berdasarkan contoh Postman; hanya digunakan oleh test.
const productFixture = <String, dynamic>{
  'id': 'abc',
  'status': 'published',
  'name': 'Laptop',
  'price': '7500000',
  'image_url': 'asset-id',
  'category': 'Elektronik',
  'description': 'Laptop gaming',
  'quantity': 5,
};

const nullableProductFixture = <String, dynamic>{
  'id': 'abc',
  'status': 'published',
  'name': null,
  'price': null,
  'image_url': null,
  'category': null,
  'description': null,
  'quantity': null,
};
