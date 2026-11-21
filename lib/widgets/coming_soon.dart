import 'package:flutter/material.dart';
import '../brand.dart';

/// صفحة Coming Soon — بتاخد اسم الصفحة وتعرضها بشكل موحد
class ComingSoonPage extends StatelessWidget {
  const ComingSoonPage({super.key, required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Brand.background,
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(label,
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 10),
              Text('Coming Soon',
                  style: TextStyle(color: Brand.green, fontSize: 14)),
            ],
          ),
        ),
      );
}
