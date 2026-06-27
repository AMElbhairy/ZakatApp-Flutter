import 'package:flutter/widgets.dart';

class AppRadii {
  AppRadii._();

  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 24;
  static const double x2l = 32;

  static const BorderRadius card = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius hero = BorderRadius.all(Radius.circular(xl));
  static const BorderRadius pill = BorderRadius.all(Radius.circular(x2l));
}
