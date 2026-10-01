import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'dashboard_page.dart';
import '../services/auth_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.authService});
  final AuthService authService;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  bool _hidePassword = true;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _login() async {
    if (_isLoading || _formKey.currentState?.validate() != true) return;
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      await widget.authService.login(
        email: _emailController.text,
        password: _passwordController.text,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(
          builder: (_) => DashboardPage(authService: widget.authService),
        ),
      );
    } on AuthException catch (e) {
      if (mounted) setState(() => _errorMessage = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorMessage = 'Tidak dapat login. Silakan coba lagi.');
      }
    } finally {
      if (mounted) {
        _passwordController.clear();
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1040),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 760;
                final form = Padding(
                  padding: EdgeInsets.all(wide ? 40 : 24),
                  child: _form(),
                );
                return Card(
                  clipBehavior: Clip.antiAlias,
                  child: wide
                      ? Row(
                          children: [
                            Expanded(child: _welcome()),
                            Expanded(child: form),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [_welcome(compact: true), form],
                        ),
                );
              },
            ),
          ),
        ),
      ),
    ),
  );

  Widget _welcome({bool compact = false}) => Container(
    padding: EdgeInsets.all(compact ? 24 : 40),
    constraints: BoxConstraints(minHeight: compact ? 0 : 520),
    decoration: const BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [Color(0xFF123C40), Color(0xFF087F72)],
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.inventory_2_outlined,
                color: Colors.white,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'INVENTORY',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
              ),
            ),
          ],
        ),
        SizedBox(height: compact ? 24 : 70),
        Text(
          'Lebih rapi.\nLebih terkendali.',
          style: TextStyle(
            color: Colors.white,
            fontSize: compact ? 30 : 40,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 18),
        const Text(
          'Satu tempat untuk produk, foto, dan stok usahamu.',
          style: TextStyle(color: Color(0xFFCDE6DE), fontSize: 16, height: 1.6),
        ),
        if (!compact) ...[
          const SizedBox(height: 50),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.auto_awesome_outlined, color: Color(0xFFBEE7C8)),
                SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Atur produk dengan lebih mudah,\nmulai dari satu langkah kecil.',
                    style: TextStyle(color: Colors.white, height: 1.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    ),
  );

  Widget _form() => Form(
    key: _formKey,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'SELAMAT DATANG KEMBALI',
          style: TextStyle(
            fontSize: 10,
            letterSpacing: 1.8,
            color: AppTheme.teal,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Inventory API App',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 8),
        const Text(
          'Masuk dan mulai kelola koleksi produkmu.',
          style: TextStyle(color: Color(0xFF667A80), height: 1.5),
        ),
        const SizedBox(height: 28),
        TextFormField(
          controller: _emailController,
          enabled: !_isLoading,
          decoration: const InputDecoration(
            labelText: 'Email',
            prefixIcon: Icon(Icons.mail_outline),
          ),
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          validator: (value) {
            final email = value?.trim() ?? '';
            if (email.isEmpty) return 'Email tidak boleh kosong';
            if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
              return 'Format email tidak valid';
            }
            return null;
          },
        ),
        const SizedBox(height: 18),
        TextFormField(
          controller: _passwordController,
          enabled: !_isLoading,
          decoration: InputDecoration(
            labelText: 'Password',
            prefixIcon: const Icon(Icons.lock_outline),
            suffixIcon: IconButton(
              tooltip: _hidePassword
                  ? 'Tampilkan password'
                  : 'Sembunyikan password',
              icon: Icon(
                _hidePassword
                    ? Icons.visibility_outlined
                    : Icons.visibility_off_outlined,
              ),
              onPressed: () => setState(() => _hidePassword = !_hidePassword),
            ),
          ),
          obscureText: _hidePassword,
          enableSuggestions: false,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onFieldSubmitted: (_) => _login(),
          validator: (value) => value == null || value.trim().isEmpty
              ? 'Password tidak boleh kosong'
              : null,
        ),
        const SizedBox(height: 24),
        if (_errorMessage != null) ...[
          Text(
            _errorMessage!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(
          onPressed: _isLoading ? null : _login,
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('LOGIN'),
                    SizedBox(width: 12),
                    Icon(Icons.arrow_forward, size: 18),
                  ],
                ),
        ),
        const SizedBox(height: 20),
        const Text(
          'Masuk menggunakan akun Anda. Sesi berakhir saat aplikasi ditutup.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: Color(0xFF667A80), height: 1.6),
        ),
      ],
    ),
  );
}
