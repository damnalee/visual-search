import 'package:flutter/material.dart';

const Map<String, Color> _exact = {
  'black': Color(0xFF111111),
  'white': Color(0xFFFFFFFF),
  'off white': Color(0xFFF3F0E8),
  'cream': Color(0xFFF5EBD0),
  'beige': Color(0xFFD9C7A3),
  'grey': Color(0xFF9E9E9E),
  'charcoal': Color(0xFF36393F),
  'silver': Color(0xFFC0C0C0),
  'steel': Color(0xFF7B8794),
  'red': Color(0xFFE53935),
  'maroon': Color(0xFF7B1E2B),
  'burgundy': Color(0xFF6D1A36),
  'rust': Color(0xFFB7410E),
  'orange': Color(0xFFFB8C00),
  'peach': Color(0xFFFFCBA4),
  'coral': Color(0xFFFF7F6B),
  'mustard': Color(0xFFD9A400),
  'yellow': Color(0xFFFDD835),
  'gold': Color(0xFFD4AF37),
  'khaki': Color(0xFFC3B091),
  'tan': Color(0xFFD2B48C),
  'brown': Color(0xFF795548),
  'coffee brown': Color(0xFF5C4033),
  'mushroom brown': Color(0xFF9C8573),
  'taupe': Color(0xFF8B7E74),
  'olive': Color(0xFF708238),
  'green': Color(0xFF43A047),
  'lime green': Color(0xFF9CCC3A),
  'sea green': Color(0xFF2E8B57),
  'fluorescent green': Color(0xFF39FF14),
  'teal': Color(0xFF00897B),
  'turquoise blue': Color(0xFF30D5C8),
  'blue': Color(0xFF1E88E5),
  'navy blue': Color(0xFF1B2A5C),
  'lavender': Color(0xFFB9A7E6),
  'purple': Color(0xFF8E24AA),
  'violet': Color(0xFF7E57C2),
  'mauve': Color(0xFFB784A7),
  'magenta': Color(0xFFD81B8C),
  'pink': Color(0xFFF48FB1),
  'rose': Color(0xFFE75480),
  'nude': Color(0xFFE3BC9A),
  'skin': Color(0xFFE8BEAC),
  'bronze': Color(0xFFCD7F32),
  'copper': Color(0xFFB87333),
  'metallic': Color(0xFFB0B7C3),
};

const List<MapEntry<String, Color>> _contains = [
  MapEntry('navy', Color(0xFF1B2A5C)),
  MapEntry('blue', Color(0xFF1E88E5)),
  MapEntry('green', Color(0xFF43A047)),
  MapEntry('brown', Color(0xFF795548)),
  MapEntry('grey', Color(0xFF9E9E9E)),
  MapEntry('gray', Color(0xFF9E9E9E)),
  MapEntry('red', Color(0xFFE53935)),
  MapEntry('pink', Color(0xFFF48FB1)),
  MapEntry('purple', Color(0xFF8E24AA)),
  MapEntry('yellow', Color(0xFFFDD835)),
  MapEntry('orange', Color(0xFFFB8C00)),
  MapEntry('black', Color(0xFF111111)),
  MapEntry('white', Color(0xFFFFFFFF)),
];

Color colorFor(String name) {
  final key = name.trim().toLowerCase();
  final exact = _exact[key];
  if (exact != null) return exact;
  for (final entry in _contains) {
    if (key.contains(entry.key)) return entry.value;
  }
  return const Color(0xFF9E9E9E);
}