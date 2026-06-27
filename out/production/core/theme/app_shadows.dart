import 'package:flutter/material.dart';

class AppShadows {
  AppShadows._();

  static const List<BoxShadow> lightSoft = <BoxShadow>[
    BoxShadow(
      color: Color(0x120B1C17),
      blurRadius: 10,
      offset: Offset(0, 3),
    ),
  ];

  static const List<BoxShadow> lightMedium = <BoxShadow>[
    BoxShadow(
      color: Color(0x180B1C17),
      blurRadius: 18,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> lightHero = <BoxShadow>[
    BoxShadow(
      color: Color(0x26011D1A),
      blurRadius: 26,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> lightFloating = <BoxShadow>[
    BoxShadow(
      color: Color(0x2A02211D),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];

  static const List<BoxShadow> darkSoft = <BoxShadow>[
    BoxShadow(
      color: Color(0x33000000),
      blurRadius: 14,
      offset: Offset(0, 4),
    ),
  ];

  static const List<BoxShadow> darkMedium = <BoxShadow>[
    BoxShadow(
      color: Color(0x44000000),
      blurRadius: 20,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> darkHero = <BoxShadow>[
    BoxShadow(
      color: Color(0x55000000),
      blurRadius: 30,
      offset: Offset(0, 12),
    ),
  ];

  static const List<BoxShadow> darkFloating = <BoxShadow>[
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 32,
      offset: Offset(0, 12),
    ),
  ];
}
