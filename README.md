# Inventory API App

Aplikasi praktikum Flutter dengan Dio dan REST API `https://pos.cicd.web.id`.

## Fitur

- Dummy login dengan validasi input → Dashboard → Products.
- CRUD produk (GET, POST, PATCH, DELETE) menggunakan data server.
- Model null-safe, parsing JSON, loading, error handling, dan retry.
- Pilih gambar JPG/PNG/WebP maksimal 5 MB, preview, lalu upload ke `/files`.
- Search melalui API, dengan debounce 350 ms dan perlindungan respons lama.
- Pagination 10 produk per halaman, tombol sebelumnya/berikutnya.
- Pull-to-refresh, termasuk pada daftar kosong; tombol muat ulang untuk desktop.
- Refresh mempertahankan kata pencarian dan kembali ke halaman pertama.

Search menggunakan parameter `search` Directus, sehingga mencakup field teks produk.
Pagination menggunakan `limit` dan `offset` dengan urutan ID yang stabil. Satu item
lebih diambil untuk menentukan apakah halaman berikutnya tersedia.

## Menjalankan

```sh
flutter pub get
flutter run -d chrome
```

Lakukan restart penuh setelah perubahan plugin. Build Windows desktop memerlukan
dukungan symlink (Developer Mode).

Login masih berupa dummy: input tidak dikirim atau disimpan sebagai credential.
Tidak ada token atau credential praktikum yang di-hardcode.

## Validasi

```sh
dart format lib test
flutter analyze
flutter test
flutter build web
```

Test otomatis menggunakan fake/mocked API dan tidak mengubah data server nyata.
