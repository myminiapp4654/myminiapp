import 'package:flutter/material.dart';

// ── Retro 8-bit palette ───────────────────────────────────────
const kBg = Color(0xFF0D0D0D);
const kPanel = Color(0xFF1A1A2A);
const kBorder = Color(0xFF3A3A5A);
const kAccent = Color(0xFF00FF88);
const kAccentDim = Color(0xFF007744);
const kWarn = Color(0xFFFFCC00);
const kDanger = Color(0xFFFF2244);
const kWhite = Color(0xFFE0E0E0);
const kDim = Color(0xFF555577);
const kBlue = Color(0xFF0099FF);

// ── Text ──────────────────────────────────────────────────────
Widget pixelText(String text, Color color, double size,
    {TextAlign align = TextAlign.center, TextDecoration? decoration}) {
  return Text(
    text,
    textAlign: align,
    style: TextStyle(
      color: color,
      fontSize: size,
      fontWeight: FontWeight.w900,
      letterSpacing: 1.2,
      fontFamily: 'monospace',
      decoration: decoration,
      decorationColor: color,
    ),
  );
}

// ── Container ─────────────────────────────────────────────────
Widget pixelContainer({
  required Widget child,
  Color color = kPanel,
  Color borderColor = kBorder,
  EdgeInsets padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  EdgeInsets margin = EdgeInsets.zero,
  double borderWidth = 2,
}) {
  return Container(
    margin: margin,
    padding: padding,
    decoration: BoxDecoration(
      color: color,
      border: Border.all(color: borderColor, width: borderWidth),
      borderRadius: BorderRadius.zero,
    ),
    child: child,
  );
}

// ── Button ────────────────────────────────────────────────────
Widget pixelButton({
  required String label,
  required VoidCallback? onTap,
  Color color = kPanel,
  Color textColor = kWhite,
  Color borderColor = kAccent,
  double fontSize = 13,
  EdgeInsets padding = const EdgeInsets.symmetric(vertical: 14),
  bool fullWidth = true,
}) {
  return GestureDetector(
    onTap: onTap,
    child: Opacity(
      opacity: onTap == null ? 0.4 : 1.0,
      child: Container(
        width: fullWidth ? double.infinity : null,
        padding: padding,
        margin: const EdgeInsets.only(bottom: 2),
        decoration: BoxDecoration(
          color: color,
          border: Border.all(color: borderColor, width: 2),
          borderRadius: BorderRadius.zero,
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                      color: borderColor.withValues(alpha: 0.5),
                      blurRadius: 0,
                      offset: const Offset(3, 3)),
                ]
              : null,
        ),
        child: pixelText(label, textColor, fontSize),
      ),
    ),
  );
}

// ── Input decoration ──────────────────────────────────────────
InputDecoration pixelInputDecoration(String hint, {IconData? icon}) {
  return InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(
        color: kDim,
        fontFamily: 'monospace',
        fontSize: 13,
        letterSpacing: 1),
    prefixIcon: icon != null ? Icon(icon, color: kDim, size: 18) : null,
    counterText: '',
    enabledBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: kBorder, width: 2),
    ),
    focusedBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: kAccent, width: 2),
    ),
    errorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: kDanger, width: 2),
    ),
    focusedErrorBorder: const OutlineInputBorder(
      borderRadius: BorderRadius.zero,
      borderSide: BorderSide(color: kDanger, width: 2),
    ),
    errorStyle: const TextStyle(color: kDanger, fontFamily: 'monospace'),
    filled: true,
    fillColor: kPanel,
    contentPadding:
        const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

// ── AppBar ────────────────────────────────────────────────────
PreferredSizeWidget pixelAppBar({
  required String title,
  Color titleColor = kAccent,
  String? subtitle,
  List<Widget>? actions,
  bool automaticallyImplyLeading = true,
  VoidCallback? onBack,
  BuildContext? context,
}) {
  return AppBar(
    backgroundColor: kPanel,
    elevation: 0,
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: automaticallyImplyLeading && onBack != null
        ? IconButton(
            icon: const Icon(Icons.arrow_back, color: kAccent),
            onPressed: onBack,
          )
        : automaticallyImplyLeading
            ? null
            : null,
    iconTheme: const IconThemeData(color: kAccent),
    title: subtitle != null
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              pixelText(title, titleColor, 13),
              pixelText(subtitle, kDim, 10),
            ],
          )
        : pixelText(title, titleColor, 14),
    centerTitle: true,
    actions: actions,
    bottom: PreferredSize(
      preferredSize: const Size.fromHeight(2),
      child: Container(height: 2, color: kAccent.withValues(alpha: 0.4)),
    ),
  );
}

// ── Loading scaffold ──────────────────────────────────────────
Widget pixelLoading() => const Scaffold(
      backgroundColor: kBg,
      body: Center(child: CircularProgressIndicator(color: kAccent)),
    );
