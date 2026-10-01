import 'dart:async';
import 'package:flutter/material.dart';
import 'package:signals_flutter/signals_flutter.dart';

import '../models/product.dart';
import '../services/api_service.dart';
import '../signals/product_signals.dart';
import '../utils/currency_formatter.dart';
import 'product_form_page.dart';
import '../theme/app_theme.dart';
import '../widgets/page_header.dart';

class ProductPage extends StatefulWidget {
  const ProductPage({super.key, this.apiService});

  // Runtime memakai ApiService asli; injeksi hanya diperlukan untuk pengujian.
  final ApiService? apiService;

  @override
  State<ProductPage> createState() => _ProductPageState();
}

class _ProductPageState extends State<ProductPage> {
  late final ApiService _apiService;
  final _state = ProductSignals();
  bool _isDeleting = false;
  bool _isConfirmingDelete = false;
  bool _isFormOpen = false;
  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _searchDebounce;
  static const _pageSize = 10;
  int _page = 1;
  int _requestedPage = 1;
  int _requestVersion = 0;
  String _query = '';
  bool _hasNextPage = false;
  bool _isRefreshing = false;

  bool get _actionsDisabled =>
      _state.isLoading.value ||
      _isRefreshing ||
      _isDeleting ||
      _isConfirmingDelete ||
      _isFormOpen;

  @override
  void initState() {
    super.initState();
    _apiService = widget.apiService ?? ApiService();
    _loadProducts();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    _scrollController.dispose();
    _state.dispose();
    super.dispose();
  }

  void _searchChanged(String value) {
    final query = value.trim();
    if (query == _query) {
      setState(() {});
      return;
    }
    _searchDebounce?.cancel();
    // Batalkan pengaruh respons lama segera, sebelum debounce selesai.
    _requestVersion++;
    _state.isLoading.value = true;
    _state.errorMessage.value = null;
    setState(() {
      _query = query;
      _requestedPage = 1;
      _isRefreshing = false;
    });
    _searchDebounce = Timer(
      const Duration(milliseconds: 350),
      () => _loadProducts(page: 1),
    );
  }

  Future<void> _refreshProducts() async {
    if (_actionsDisabled) return;
    await _loadProducts(page: 1, refresh: true);
  }

  Future<void> _loadProducts({int? page, bool refresh = false}) async {
    final keepContentOnError = refresh && _state.errorMessage.value == null;
    _searchDebounce?.cancel();
    final version = ++_requestVersion;
    final targetPage = page ?? _requestedPage;
    _requestedPage = targetPage;
    _state.isLoading.value = !refresh;
    _state.errorMessage.value = null;
    setState(() => _isRefreshing = refresh);
    try {
      final products = await _apiService.getProducts(
        limit: _pageSize + 1,
        offset: (targetPage - 1) * _pageSize,
        search: _query,
      );
      if (!mounted || version != _requestVersion) return;
      // Data bisa berkurang karena dihapus. Kembali ke halaman sebelumnya.
      if (products.isEmpty && targetPage > 1) {
        await _loadProducts(page: targetPage - 1);
        return;
      }
      _state.products.value = products.take(_pageSize).toList();
      _state.isLoading.value = false;
      setState(() {
        _hasNextPage = products.length > _pageSize;
        _page = targetPage;
        _isRefreshing = false;
      });
      if (_scrollController.hasClients) _scrollController.jumpTo(0);
    } on ApiException catch (e) {
      if (!mounted || version != _requestVersion) return;
      _handleLoadError(e.message, keepContentOnError);
    } catch (_) {
      if (!mounted || version != _requestVersion) return;
      _handleLoadError(
        'Terjadi kesalahan saat memuat produk. Silakan coba lagi.',
        keepContentOnError,
      );
    }
  }

  void _handleLoadError(String message, bool refresh) {
    _state.isLoading.value = false;
    if (!refresh) _state.errorMessage.value = message;
    setState(() => _isRefreshing = false);
    if (refresh) _showMessage(message);
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _openForm([Product? product]) async {
    if (_actionsDisabled) return;
    setState(() => _isFormOpen = true);
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            ProductFormPage(product: product, apiService: _apiService),
      ),
    );
    if (!mounted) return;
    setState(() => _isFormOpen = false);
    if (changed == true) await _loadProducts(page: 1);
  }

  Future<void> _deleteProduct(Product product) async {
    if (_actionsDisabled) return;
    final id = product.id;
    if (id == null || id.trim().isEmpty) {
      _showMessage('ID produk tidak tersedia. Muat ulang daftar produk.');
      return;
    }
    setState(() => _isConfirmingDelete = true);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(
          Icons.delete_outline,
          color: Color(0xFFB43F43),
          size: 32,
        ),
        title: const Text('Hapus Produk?'),
        content: Text(
          'Apakah Anda yakin ingin menghapus "${_displayText(product.name, 'Tanpa Nama')}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFB43F43),
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    setState(() => _isConfirmingDelete = false);
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await _apiService.deleteProduct(id);
      if (!mounted) return;
      _showMessage('Produk berhasil dihapus');
      await _loadProducts();
    } on ApiException catch (e) {
      if (!mounted) return;
      _showMessage(e.message);
    } catch (_) {
      if (!mounted) return;
      _showMessage('Gagal menghapus produk. Silakan coba lagi.');
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          Watch.builder(
            builder: (context) => IconButton(
              tooltip: 'Muat ulang',
              onPressed: _actionsDisabled ? null : _refreshProducts,
              icon: _isRefreshing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (MediaQuery.viewInsetsOf(context).bottom == 0)
                  Watch.builder(
                    builder: (context) => Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: PageHeader(
                      eyebrow: 'Inventori',
                      title: 'Koleksi produk',
                      subtitle: _state.isLoading.value
                          ? 'Menyiapkan daftar produkmu…'
                          : _state.errorMessage.value != null
                          ? 'Hubungkan kembali untuk melihat produkmu.'
                          : '${_state.productCount.value} produk dimuat • Kelola foto, detail, dan stok.',
                    ),
                  ),
                  ),
                Padding(
                  // Pertahankan TextField saat header hilang karena keyboard.
                  key: const ValueKey('product-search-field'),
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    enabled:
                        !_isDeleting && !_isConfirmingDelete && !_isFormOpen,
                    onChanged: _searchChanged,
                    onSubmitted: (_) => _loadProducts(page: 1),
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: 'Cari produk...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Hapus pencarian',
                              icon: const Icon(Icons.close),
                              onPressed: () {
                                _searchController.clear();
                                _searchChanged('');
                              },
                            ),
                    ),
                  ),
                ),
                Expanded(
                  child: Watch.builder(
                    // Hanya area daftar/error/loading ini yang berlangganan state produk.
                    builder: (context) => RefreshIndicator(
                      onRefresh: _refreshProducts,
                      child: _buildBody(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Watch.builder(
            builder: (context) => Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                tooltip: 'Halaman sebelumnya',
                onPressed:
                    _actionsDisabled || _state.errorMessage.value != null || _page <= 1
                    ? null
                    : () => _loadProducts(page: _page - 1),
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                'Halaman $_page',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              IconButton(
                tooltip: 'Halaman berikutnya',
                onPressed:
                    _actionsDisabled || _state.errorMessage.value != null || !_hasNextPage
                    ? null
                    : () => _loadProducts(page: _page + 1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
            ),
          ),
        ),
      ),
      floatingActionButton: Watch.builder(
        builder: (context) => FloatingActionButton.extended(
          tooltip: 'Tambah Product',
          onPressed: _actionsDisabled ? null : () => _openForm(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah produk'),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_state.isLoading.value || _isDeleting) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_state.errorMessage.value != null) {
      return _scrollableState(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 56),
              const SizedBox(height: 16),
              Text(
                'Gagal memuat produk',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(_state.errorMessage.value ?? '', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadProducts,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    if (_state.products.value.isEmpty) {
      return _scrollableState(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 56),
            const SizedBox(height: 16),
            Text(
              _query.isEmpty ? 'Belum ada produk' : 'Produk tidak ditemukan',
            ),
            if (_query.isNotEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('Coba kata kunci lain atau hapus pencarian.'),
              ),
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 36) / 2;
        final imageHeight = (cardWidth - 16).clamp(100.0, 200.0);
        final scale = MediaQuery.textScalerOf(context).scale(14) / 14;
        return GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 16,
            mainAxisExtent: imageHeight + 210 * scale,
          ),
          itemCount: _state.products.value.length,
          itemBuilder: (context, index) {
            final product = _state.products.value[index];
            return Card(
              margin: EdgeInsets.zero,
              clipBehavior: Clip.antiAlias,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: imageHeight,
                      child: _buildImage(product.imageUrl),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      _displayText(product.name, 'Tanpa Nama'),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        height: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatRupiah(product.price),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFB43F43),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _displayText(product.category, 'Tanpa Kategori'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF667A80),
                      ),
                    ),
                    Text(
                      'Stok: ${product.quantity ?? '-'}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    Text(
                      'Status: ${_displayText(product.status, '-')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.teal,
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFB51E28),
                              minimumSize: const Size(0, 36),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              textStyle: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: _actionsDisabled
                                ? null
                                : () => _showProductDetails(product),
                            child: const Text('Lihat'),
                          ),
                        ),
                        const SizedBox(width: 4),
                        _cardAction(
                          icon: Icons.edit_outlined,
                          tooltip: 'Edit',
                          color: const Color(0xFFAF681E),
                          background: const Color(0xFFFFF4E7),
                          onPressed: () => _openForm(product),
                        ),
                        const SizedBox(width: 4),
                        _cardAction(
                          icon: Icons.delete_outline,
                          tooltip: 'Delete',
                          color: const Color(0xFFB43F43),
                          background: const Color(0xFFFFEFF0),
                          onPressed: () => _deleteProduct(product),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _cardAction({
    required IconData icon,
    required String tooltip,
    required Color color,
    required Color background,
    required VoidCallback onPressed,
  }) => IconButton(
    tooltip: tooltip,
    onPressed: _actionsDisabled ? null : onPressed,
    style: IconButton.styleFrom(
      backgroundColor: background,
      foregroundColor: color,
      minimumSize: const Size(32, 36),
      maximumSize: const Size(32, 36),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(9)),
    ),
    icon: Icon(icon, size: 17),
  );

  Future<void> _showProductDetails(Product product) async {
    _state.selectedProduct.value = product;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (context) => Watch.builder(
        // Detail hanya bereaksi terhadap produk yang sedang dipilih.
        builder: (context) {
          final selected = _state.selectedProduct.value;
          if (selected == null) return const SizedBox.shrink();
          return FractionallySizedBox(
        heightFactor: 0.8,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 220, child: _buildImage(selected.imageUrl)),
              const SizedBox(height: 20),
              Text(
                _displayText(selected.name, 'Tanpa Nama'),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                formatRupiah(selected.price),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFFB43F43),
                ),
              ),
              const SizedBox(height: 16),
              Text(_displayText(selected.category, 'Tanpa Kategori')),
              Text('Stok: ${selected.quantity ?? '-'}'),
              Text('Status: ${_displayText(selected.status, '-')}'),
              const Divider(),
              const Text(
                'Deskripsi',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(_displayText(selected.description, 'Belum ada deskripsi.')),
              const SizedBox(height: 20),
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Tutup'),
              ),
            ],
          ),
        ),
          );
        },
      ),
    );
    if (mounted) _state.selectedProduct.value = null;
  }

  String _displayText(String? value, String fallback) {
    final text = value?.trim();
    return text == null || text.isEmpty ? fallback : text;
  }

  Widget _scrollableState({required Widget child}) => LayoutBuilder(
    builder: (context, constraints) => ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(child: child),
        ),
      ],
    ),
  );

  Widget _buildImage(String? assetId) {
    final id = assetId?.trim();
    const placeholder = Center(
      child: Icon(Icons.image_not_supported_outlined, size: 32),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: SizedBox(
        width: double.infinity,
        height: double.infinity,
        child: ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: id == null || id.isEmpty
              ? placeholder
              : Image.network(
                  'https://pos.cicd.web.id/assets/${Uri.encodeComponent(id)}',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => placeholder,
                ),
        ),
      ),
    );
  }
}
