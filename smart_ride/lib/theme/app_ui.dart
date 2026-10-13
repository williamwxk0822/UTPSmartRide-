import 'package:flutter/material.dart';

// ---------------- ui kit ----------------
// colors, gradients, shadows
// styling only, no logic in here
class AppUI {
  // main colors
  static const Color primary = Color(0xFF3D5AFE);
  static const Color primaryDark = Color(0xFF1A237E);
  static const Color bg = Color(0xFFF4F6FB);
  static const Color ink = Color(0xFF1B1F2E);
  static const Color inkSoft = Color(0xFF6B7280);

  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF283593), Color(0xFF3D5AFE), Color(0xFF00B0FF)],
  );

  static LinearGradient tintGradient(Color c) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [c, Color.lerp(c, Colors.black, 0.25)!],
      );

  static List<BoxShadow> softShadow = [
    BoxShadow(
      color: const Color(0xFF1A237E).withOpacity(0.08),
      blurRadius: 24,
      offset: const Offset(0, 8),
    ),
  ];

  static BoxDecoration card({double radius = 20}) => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: softShadow,
      );

  static BoxDecoration banner(Color c) => BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.withOpacity(0.35)),
      );
}
