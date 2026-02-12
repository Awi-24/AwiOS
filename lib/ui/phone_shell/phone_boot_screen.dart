import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'phone_shell.dart';

/// Tela inicial do celular: carregamento falso com GIF de boot.
/// Depois do tempo mínimo, navega para a PhoneShell.
class PhoneBootScreen extends StatefulWidget {
  const PhoneBootScreen({super.key});

  @override
  State<PhoneBootScreen> createState() => _PhoneBootScreenState();
}

class _PhoneBootScreenState extends State<PhoneBootScreen> {
  static const _minDuration = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();
    Future.delayed(_minDuration, () {
      if (mounted) _navigate();
    });
  }

  void _navigate() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const PhoneShell(),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 300,
                child: Image.asset(
                  'assets/videos/awiOS.gif',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Text(
                    'AwiOS',
                    style: TextStyle(
                      fontSize: 35,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.labelPrimary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: AppTheme.spaceXl),
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(AppTheme.labelSecondary.withValues(alpha: 0.7)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

