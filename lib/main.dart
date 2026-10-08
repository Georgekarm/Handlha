import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  ErrorWidget.builder = (details) {
    return Material(
      color: const Color(0xFFF6F7F5),
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'حصل خطأ أثناء عرض الشاشة.\n${details.exception}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFF1E2D2B),
                fontSize: 16,
                decoration: TextDecoration.none,
              ),
            ),
          ),
        ),
      ),
    );
  };

  runApp(const ProviderScope(child: SekreterakApp()));
}


