import 'package:flutter/material.dart';
import '../theme/app_ui.dart';

// gradient header (title + subtitle) for the dashboards
class GradientHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Gradient gradient;
  const GradientHeader(
      {required this.title,
      required this.subtitle,
      required this.icon,
      this.gradient = AppUI.primaryGradient,
      super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppUI.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.18),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.2)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.85),
                        fontSize: 13)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
