import 'package:flutter/material.dart';

import 'pages/login_page.dart';
import 'services/auth_service.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key, this.authService});
  final AuthService? authService;

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late final AuthService _authService = widget.authService ?? AuthService();

  @override
  void dispose() {
    if (widget.authService == null) _authService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory API App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: LoginPage(authService: _authService),
    );
  }
}
