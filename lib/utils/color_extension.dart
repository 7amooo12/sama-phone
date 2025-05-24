import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Extension method for Color class to handle opacity with the new withValues syntax
/// and provide additional color manipulation methods
extension ColorExtension on Color {
  /// Returns a copy of this Color with the given opacity.
  /// Ensures the opacity is between 0.0 and 1.0.
  Color safeOpacity(double opacity) {
    // Make sure opacity is between 0.0 and 1.0
    final safeOpacity = opacity.clamp(0.0, 1.0);
    return withOpacity(safeOpacity);
  }

  /// Creates a lighter version of this color
  /// The higher the percent, the lighter the color
  Color lighter(double percent) {
    assert(percent >= 0 && percent <= 1);

    final hsl = HSLColor.fromColor(this);
    final lightness = math.min(1.0, hsl.lightness + percent);

    return hsl.withLightness(lightness).toColor();
  }

  /// Creates a darker version of this color
  /// The higher the percent, the darker the color
  Color darker(double percent) {
    assert(percent >= 0 && percent <= 1);

    final hsl = HSLColor.fromColor(this);
    final lightness = math.max(0.0, hsl.lightness - percent);

    return hsl.withLightness(lightness).toColor();
  }

  /// Creates a more saturated version of this color
  /// The higher the percent, the more saturated the color
  Color moreVibrant(double percent) {
    assert(percent >= 0 && percent <= 1);

    final hsl = HSLColor.fromColor(this);
    final saturation = math.min(1.0, hsl.saturation + percent);

    return hsl.withSaturation(saturation).toColor();
  }

  /// Creates a less saturated version of this color
  /// The higher the percent, the less saturated the color
  Color lessVibrant(double percent) {
    assert(percent >= 0 && percent <= 1);

    final hsl = HSLColor.fromColor(this);
    final saturation = math.max(0.0, hsl.saturation - percent);

    return hsl.withSaturation(saturation).toColor();
  }

  /// Shifts the hue of this color
  /// The value should be between 0 and 1, representing a full circle of the color wheel
  Color shiftHue(double amount) {
    assert(amount >= 0 && amount <= 1);

    final hsl = HSLColor.fromColor(this);
    final hue = (hsl.hue + amount * 360) % 360;

    return hsl.withHue(hue).toColor();
  }

  /// Inverts this color
  Color get inverted {
    return Color.fromRGBO(
      255 - r.toInt(),
      255 - g.toInt(),
      255 - b.toInt(),
      opacity,
    );
  }

  /// Returns a contrasting color (black or white) based on this color's brightness
  /// Useful for determining text color on a background
  Color get contrast {
    return computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }

  /// Blends this color with another color
  /// The strength parameter determines how much of the other color to blend in
  Color blend(Color other, double strength) {
    assert(strength >= 0 && strength <= 1);

    final r1 = r.toInt();
    final g1 = g.toInt();
    final b1 = b.toInt();

    final r2 = other.r.toInt();
    final g2 = other.g.toInt();
    final b2 = other.b.toInt();

    return Color.fromRGBO(
      (r1 + (r2 - r1) * strength).round(),
      (g1 + (g2 - g1) * strength).round(),
      (b1 + (b2 - b1) * strength).round(),
      opacity,
    );
  }

  /// Returns a material color swatch based on this color
  MaterialColor toMaterialColor() {
    final strengths = <double>[.05, .1, .2, .3, .4, .5, .6, .7, .8, .9];
    final swatch = <int, Color>{};
    final int r = this.r.toInt();
    final int g = this.g.toInt();
    final int b = this.b.toInt();

    for (final strength in strengths) {
      final double ds = 0.5 - strength;
      swatch[(strength * 1000).round()] = Color.fromRGBO(
        r + ((ds < 0 ? r : (255 - r)) * ds).round(),
        g + ((ds < 0 ? g : (255 - g)) * ds).round(),
        b + ((ds < 0 ? b : (255 - b)) * ds).round(),
        1,
      );
    }

    return MaterialColor(value, swatch);
  }

  /// Brightens the color by the given percent (0.0 to 1.0)
  Color brighten([double amount = 0.1]) {
    assert(amount >= 0.0 && amount <= 1.0);
    final hsl = HSLColor.fromColor(this);
    final lightness = (hsl.lightness + amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// Darkens the color by the given percent (0.0 to 1.0)
  Color darken([double amount = 0.1]) {
    assert(amount >= 0.0 && amount <= 1.0);
    final hsl = HSLColor.fromColor(this);
    final lightness = (hsl.lightness - amount).clamp(0.0, 1.0);
    return hsl.withLightness(lightness).toColor();
  }

  /// Mix this color with another color
  Color mix(Color another, [double amount = 0.5]) {
    assert(amount >= 0.0 && amount <= 1.0);
    
    return Color.fromARGB(
      255,
      _mix(red, another.red, amount),
      _mix(green, another.green, amount),
      _mix(blue, another.blue, amount),
    );
  }
  
  int _mix(int firstValue, int secondValue, double amount) {
    return (firstValue + (secondValue - firstValue) * amount).round();
  }
}
