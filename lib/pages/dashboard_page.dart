import 'package:flutter/material.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_theme.dart';
import '../utils/currency_formatter.dart';
import 'login_page.dart';
import 'product_page.dart';

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key, required this.authService});
  final AuthService authService;

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  bool _loading = true;
  String? _error;
  int _productCount = 0;
  int _stock = 0;
  double _value = 0;

  @override
  void initState() {
    super.initState();
    _loadOverview();
  }

  Future<void> _loadOverview() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var count = 0;
      var stock = 0;
      var value = 0.0;
      // Ambil seluruh halaman agar ringkasan tidak terpotong limit default API.
      while (true) {
        final products = await widget.authService.apiService.getProducts(
          limit: 100,
          offset: count,
        );
        if (!mounted) return;
        if (products.isEmpty) break;
        count += products.length;
        for (final product in products) {
          final quantity = product.quantity ?? 0;
          stock += quantity;
          value += (product.price ?? 0) * quantity;
        }
      }
      setState(() {
        _productCount = count;
        _stock = stock;
        _value = value;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Ringkasan inventori gagal dimuat. Silakan coba lagi.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openProducts() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProductPage(apiService: widget.authService.apiService),
      ),
    );
    if (mounted) await _loadOverview();
  }

  void _logout() {
    widget.authService.logout();
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginPage(authService: widget.authService),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppTheme.canvas,
    appBar: AppBar(
      backgroundColor: AppTheme.canvas,
      title: const Text('Simple Inventory'),
      actions: [
        IconButton(
          tooltip: 'Muat ulang',
          onPressed: _loading ? null : _loadOverview,
          icon: const Icon(Icons.refresh),
        ),
        IconButton(
          tooltip: 'Logout',
          onPressed: _logout,
          icon: const Icon(Icons.logout, size: 21),
        ),
        const SizedBox(width: 8),
      ],
    ),
    body: SafeArea(
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
            children: [
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF123C40), AppTheme.teal],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.teal.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 7),
                    ),
                  ],
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Inventory Overview',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Pantau produk dan stok kamu dalam satu tempat.',
                      style: TextStyle(
                        color: Color(0xFFCDE6DE),
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 56),
                  child: Center(
                    child: CircularProgressIndicator(color: AppTheme.teal),
                  ),
                )
              else if (_error != null)
                Column(
                  children: [
                    Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    TextButton(
                      onPressed: _loadOverview,
                      child: const Text('Coba lagi'),
                    ),
                  ],
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = (constraints.maxWidth - 12) / 2;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _statCard(
                          width: width,
                          icon: Icons.inventory_2_outlined,
                          color: AppTheme.teal,
                          value: '$_productCount',
                          label: 'Total Produk',
                        ),
                        _statCard(
                          width: width,
                          icon: Icons.layers_outlined,
                          color: AppTheme.teal,
                          value: '$_stock',
                          label: 'Total Stok',
                        ),
                        _statCard(
                          width: width,
                          icon: Icons.payments_outlined,
                          color: AppTheme.teal,
                          value: formatRupiah(_value).replaceFirst('Rp', 'Rp '),
                          label: 'Nilai Total Inventori',
                        ),
                      ],
                    );
                  },
                ),
              const SizedBox(height: 32),
              const Text(
                'Aksi Cepat',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.teal,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: _loading ? null : _openProducts,
                icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                label: const Text('Kelola Produk'),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Widget _statCard({
    required double width,
    required IconData icon,
    required Color color,
    required String value,
    required String label,
  }) => Container(
    width: width,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppTheme.line),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.ink,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF667A80),
            height: 1.4,
          ),
        ),
      ],
    ),
  );
}
