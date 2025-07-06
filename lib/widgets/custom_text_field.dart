import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/accountant_theme_config.dart';

class CustomTextField extends StatelessWidget {
  const CustomTextField({
    super.key,
    required this.controller,
    required this.labelText,
    this.hintText = '',
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.textInputAction,
    this.focusNode,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.enabled,
    this.validator,
    this.contentPadding,
    this.inputFormatters,
    this.helperText,
  });
  final TextEditingController controller;
  final String labelText;
  final String hintText;
  final IconData? prefixIcon;
  final IconData? suffixIcon;
  final bool obscureText;
  final TextInputType keyboardType;
  final int? maxLines;
  final TextInputAction? textInputAction;
  final FocusNode? focusNode;
  final Function(String)? onChanged;
  final Function(String)? onSubmitted;
  final Function()? onTap;
  final bool? enabled;
  final String? Function(String?)? validator;
  final EdgeInsetsGeometry? contentPadding;
  final List<TextInputFormatter>? inputFormatters;
  final String? helperText;

  /// Determines the effective keyboard type based on the configuration
  /// When using TextInputAction.newline with multiline (maxLines > 1 or null),
  /// Flutter requires TextInputType.multiline to avoid assertion errors
  TextInputType _getEffectiveKeyboardType() {
    // If maxLines is null or > 1 (multiline) and textInputAction is newline,
    // we must use TextInputType.multiline
    final isMultiline = maxLines == null || (maxLines != null && maxLines! > 1);
    final isNewlineAction = textInputAction == TextInputAction.newline;

    if (isMultiline && isNewlineAction) {
      return TextInputType.multiline;
    }

    // Otherwise, use the provided keyboardType
    return keyboardType;
  }

  @override
  Widget build(BuildContext context) {
    // Automatically set keyboardType to multiline when using newline action with multiline
    final effectiveKeyboardType = _getEffectiveKeyboardType();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AccountantThemeConfig.defaultBorderRadius),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.15),
                Colors.white.withOpacity(0.05),
              ],
            ),
            border: Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: controller,
            style: GoogleFonts.cairo(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
            decoration: InputDecoration(
              labelText: labelText,
              labelStyle: GoogleFonts.cairo(
                color: Colors.white.withOpacity(0.8),
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              hintText: hintText,
              hintStyle: GoogleFonts.cairo(
                color: Colors.white.withOpacity(0.6),
                fontSize: 14,
              ),
              prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, color: Colors.white.withOpacity(0.7))
                : null,
              suffixIcon: suffixIcon != null
                ? Icon(suffixIcon, color: Colors.white.withOpacity(0.7))
                : null,
              contentPadding: contentPadding ??
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              errorStyle: GoogleFonts.cairo(
                color: AccountantThemeConfig.dangerRed,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            obscureText: obscureText,
            keyboardType: effectiveKeyboardType,
            maxLines: maxLines,
            textInputAction: textInputAction,
            focusNode: focusNode,
            onChanged: onChanged,
            onFieldSubmitted: onSubmitted,
            onTap: onTap,
            enabled: enabled,
            validator: validator,
            inputFormatters: inputFormatters,
            textDirection: TextDirection.rtl, // RTL support for Arabic
          ),
        ),
        if (helperText != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 12),
            child: Text(
              helperText!,
              style: GoogleFonts.cairo(
                color: Colors.white.withOpacity(0.6),
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
              textDirection: TextDirection.rtl,
            ),
          ),
      ],
    );
  }
}
