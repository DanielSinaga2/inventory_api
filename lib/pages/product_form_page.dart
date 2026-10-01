import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'dart:ui' as ui;

import '../models/product.dart';
import '../models/product_image.dart';
import '../services/api_service.dart';
import '../widgets/page_header.dart';
import '../theme/app_theme.dart';

class ProductFormPage extends StatefulWidget {
  const ProductFormPage({
    super.key,
    this.product,
    this.apiService,
    this.pickImage,
  });

  final Product? product;
  final ApiService? apiService;
  final Future<XFile?> Function()? pickImage;

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final ApiService _apiService;
  late final TextEditingController _name;
  late final TextEditingController _price;
  late final TextEditingController _category;
  late final TextEditingController _description;
  late final TextEditingController _quantity;
  String? _status;
  String? _errorMessage;
  bool _isSubmitting = false;
  bool _isPickingImage = false;
  ProductImage? _selectedImage;
  String? _uploadedImageId;
  double? _uploadProgress;
  String? _imageError;

  Future<void> _pickImage() async {
    if (_isSubmitting || _isPickingImage) return;
    setState(() {
      _isPickingImage = true;
      _imageError = null;
    });
    try {
      final file =
          await (widget.pickImage?.call() ??
              openFile(
                acceptedTypeGroups: const [
                  XTypeGroup(
                    label: 'Gambar',
                    extensions: ['jpg', 'jpeg', 'png', 'webp'],
                    mimeTypes: ['image/jpeg', 'image/png', 'image/webp'],
                    uniformTypeIdentifiers: [
                      'public.jpeg',
                      'public.png',
                      'org.webmproject.webp',
                    ],
                  ),
                ],
              ));
      if (file == null) return;
      if (await file.length() > ProductImage.maxBytes) {
        throw const FormatException('Ukuran gambar maksimal 5 MB.');
      }
      final selected = ProductImage.fromBytes(
        await file.readAsBytes(),
        file.name,
      );
      // Pastikan isi file benar-benar bisa ditampilkan sebelum upload.
      final codec = await ui.instantiateImageCodec(
        selected.bytes,
        targetWidth: 480,
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
      if (!mounted) return;
      setState(() {
        _selectedImage = selected;
        _uploadedImageId = null;
      });
    } on FormatException catch (e) {
      if (mounted) setState(() => _imageError = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _imageError =
              'Gambar tidak dapat dibaca. Silakan pilih file lain.',
        );
      }
    } finally {
      if (mounted) setState(() => _isPickingImage = false);
    }
  }

  bool get _isEditing => widget.product != null;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    final product = widget.product;
    _name = TextEditingController(text: product?.name ?? '');
    _price = TextEditingController(
      text: product?.toJson()['price'] as String? ?? '',
    );
    _category = TextEditingController(text: product?.category ?? '');
    _description = TextEditingController(text: product?.description ?? '');
    _quantity = TextEditingController(
      text: product?.quantity?.toString() ?? '0',
    );
    // Status asing/null tidak diubah diam-diam saat edit; pengguna harus memilih.
    _status = product == null
        ? 'published'
        : ['published', 'draft'].contains(product.status)
        ? product.status
        : null;
  }

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _category.dispose();
    _description.dispose();
    _quantity.dispose();
    super.dispose();
  }

  String? _validatePrice(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Harga wajib diisi';
    final price = double.tryParse(text);
    if (price == null || !price.isFinite) return 'Harga harus berupa angka';
    if (price < 0) return 'Harga tidak boleh negatif';
    return null;
  }

  String? _validateQuantity(String? value) {
    final text = value?.trim() ?? '';
    if (text.isEmpty) return 'Stok wajib diisi';
    final quantity = int.tryParse(text);
    if (quantity == null) return 'Stok harus berupa bilangan bulat';
    if (quantity < 0) return 'Stok tidak boleh negatif';
    return null;
  }

  Future<void> _submit() async {
    if (_isSubmitting || _isPickingImage) return;
    final id = widget.product?.id;
    if (_isEditing && (id == null || id.trim().isEmpty)) {
      setState(
        () => _errorMessage =
            'ID produk tidak tersedia. Muat ulang daftar produk.',
      );
      return;
    }
    if (_formKey.currentState?.validate() != true) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final selected = _selectedImage;
      if (selected != null && _uploadedImageId == null) {
        _uploadedImageId = await _apiService.uploadProductImage(
          selected,
          onSendProgress: (sent, total) {
            if (mounted) {
              setState(() => _uploadProgress = total > 0 ? sent / total : null);
            }
          },
        );
        if (!mounted) return;
        setState(() => _uploadProgress = null);
      }
      final product = Product(
        name: _name.text.trim(),
        price: double.parse(_price.text.trim()),
        category: _category.text.trim(),
        description: _description.text.trim(),
        quantity: int.parse(_quantity.text.trim()),
        status: _status,
        imageUrl: _uploadedImageId,
      );
      if (_isEditing && id != null) {
        await _apiService.updateProduct(id, product);
      } else {
        await _apiService.createProduct(product);
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _errorMessage = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(
        () => _errorMessage = 'Gagal menyimpan produk. Silakan coba lagi.',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
          _uploadProgress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isSubmitting && !_isPickingImage,
      child: Scaffold(
        appBar: AppBar(
          title: Text(_isEditing ? 'Edit Product' : 'Tambah Product'),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      PageHeader(
                        eyebrow: _isEditing
                            ? 'Perbarui koleksi'
                            : 'Produk baru',
                        title: _isEditing
                            ? 'Detail yang selalu terbaru.'
                            : 'Lengkapi cerita produkmu.',
                        subtitle:
                            'Tambahkan foto dan informasi produk agar mudah dikenali.',
                      ),
                      const SizedBox(height: 24),
                      _imageSection(),
                      const SizedBox(height: 28),
                      const Text(
                        'Informasi produk',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Isi harga tanpa pemisah ribuan. Deskripsi boleh dikosongkan.',
                        style: TextStyle(
                          color: Color(0xFF667A80),
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _field(
                        'Nama Produk',
                        _name,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Nama produk wajib diisi'
                            : null,
                      ),
                      _field(
                        'Harga',
                        _price,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        validator: _validatePrice,
                      ),
                      _field(
                        'Kategori',
                        _category,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Kategori wajib diisi'
                            : null,
                      ),
                      _field('Deskripsi', _description, maxLines: 3),
                      _field(
                        'Stok',
                        _quantity,
                        keyboardType: TextInputType.number,
                        validator: _validateQuantity,
                      ),
                      DropdownButtonFormField<String>(
                        initialValue: _status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const [
                          DropdownMenuItem(
                            value: 'published',
                            child: Text('published'),
                          ),
                          DropdownMenuItem(
                            value: 'draft',
                            child: Text('draft'),
                          ),
                        ],
                        onChanged: _isSubmitting
                            ? null
                            : (value) => setState(() => _status = value),
                        validator: (value) =>
                            value == null ? 'Status wajib dipilih' : null,
                      ),
                      const SizedBox(height: 24),
                      if (_errorMessage != null) ...[
                        Text(
                          _errorMessage ?? '',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],
                      FilledButton(
                        onPressed: _isSubmitting || _isPickingImage
                            ? null
                            : _submit,
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Text(_isEditing ? 'Update' : 'Simpan'),
                      ),
                      if (_isSubmitting) ...[
                        const SizedBox(height: 12),
                        Text(
                          _selectedImage != null && _uploadedImageId == null
                              ? 'Mengunggah gambar${_uploadProgress == null ? '…' : ' ${(100 * (_uploadProgress ?? 0)).round()}%'}'
                              : 'Menyimpan produk…',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        enabled: !_isSubmitting,
        decoration: InputDecoration(labelText: label),
        keyboardType: keyboardType,
        maxLines: maxLines,
        validator: validator,
      ),
    );
  }

  Widget _imageSection() {
    final selected = _selectedImage;
    final existingId = widget.product?.imageUrl;
    final hasExisting = existingId != null && existingId.trim().isNotEmpty;
    const placeholder = Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.add_photo_alternate_outlined,
          size: 44,
          color: AppTheme.teal,
        ),
        SizedBox(height: 12),
        Text('Foto membuat produk lebih mudah dikenali'),
      ],
    );
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(
                height: 180,
                child: ColoredBox(
                  color: const Color(0xFFE8F2EE),
                  child: selected != null
                      ? Image.memory(
                          selected.bytes,
                          fit: BoxFit.contain,
                          cacheWidth: 720,
                          errorBuilder: (_, _, _) => const Center(
                            child: Icon(Icons.broken_image_outlined),
                          ),
                        )
                      : hasExisting
                      ? Image.network(
                          'https://pos.cicd.web.id/assets/${Uri.encodeComponent(existingId)}',
                          fit: BoxFit.contain,
                          errorBuilder: (_, _, _) => placeholder,
                        )
                      : placeholder,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              selected?.filename ??
                  (hasExisting
                      ? 'Foto produk saat ini'
                      : 'Foto produk • Opsional'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            const Text(
              'JPG, PNG, atau WebP. Maksimal 5 MB.',
              style: TextStyle(fontSize: 12, color: Color(0xFF667A80)),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _isSubmitting || _isPickingImage
                      ? null
                      : _pickImage,
                  icon: const Icon(Icons.upload_outlined),
                  label: Text(
                    _isPickingImage
                        ? 'Membaca gambar…'
                        : selected != null || hasExisting
                        ? 'Ganti gambar'
                        : 'Pilih gambar',
                  ),
                ),
                if (selected != null)
                  TextButton(
                    onPressed: _isSubmitting
                        ? null
                        : () => setState(() {
                            _selectedImage = null;
                            _uploadedImageId = null;
                            _imageError = null;
                          }),
                    child: const Text('Batalkan pilihan'),
                  ),
              ],
            ),
            if (_imageError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _imageError ?? '',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
