import 'package:flutter/material.dart';

import 'icons.dart';
import 'theme.dart';

/// Toque sin el efecto "ripple" rectangular, con un leve desvanecido.
class Tap extends StatelessWidget {
  const Tap({super.key, required this.child, this.onTap, this.radius = 16});
  final Widget child;
  final VoidCallback? onTap;
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return child;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        splashColor: AppColors.text.withValues(alpha: .06),
        highlightColor: AppColors.text.withValues(alpha: .04),
        child: child,
      ),
    );
  }
}

class Box extends StatelessWidget {
  const Box({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.radius = 18,
    this.color = AppColors.surface,
    this.borderColor = AppColors.border,
    this.onTap,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color? borderColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: borderColor == null ? null : Border.all(color: borderColor!),
      ),
      child: child,
    );
    return onTap == null
        ? box
        : Material(
            color: Colors.transparent,
            child: InkWell(onTap: onTap, borderRadius: BorderRadius.circular(radius), child: box),
          );
  }
}

/// BotÃ³n cuadrado de 44 px (cerrar, volver, campana).
class SquareButton extends StatelessWidget {
  const SquareButton({super.key, required this.icon, this.onTap, this.iconSize = 20, this.badge = 0});
  final AppIcon icon;
  final VoidCallback? onTap;
  final double iconSize;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Box(
          onTap: onTap,
          radius: 14,
          padding: EdgeInsets.zero,
          child: SizedBox(width: 42, height: 42, child: Center(child: Ico(icon, size: iconSize))),
        ),
        if (badge > 0)
          Positioned(
            right: -4,
            top: -4,
            child: Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 5),
              decoration: BoxDecoration(
                color: AppColors.coral,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.bg, width: 2),
              ),
              alignment: Alignment.center,
              child: Text(badge > 9 ? '9+' : '$badge', style: bold(10, color: AppColors.bg)),
            ),
          ),
      ],
    );
  }
}

enum ButtonKind { primary, light, outline, ghost, dashed }

class AppButton extends StatelessWidget {
  const AppButton(
    this.label, {
    super.key,
    this.onTap,
    this.icon,
    this.kind = ButtonKind.primary,
    this.height = 56,
    this.enabled = true,
  });
  final String label;
  final VoidCallback? onTap;
  final AppIcon? icon;
  final ButtonKind kind;
  final double height;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final on = enabled && onTap != null;
    Color bg, fg;
    Border? border;
    switch (kind) {
      case ButtonKind.primary:
        bg = on ? AppColors.accent : AppColors.border;
        fg = on ? AppColors.bg : AppColors.muted;
      case ButtonKind.light:
        bg = on ? AppColors.text : AppColors.border;
        fg = on ? AppColors.bg : AppColors.muted;
      case ButtonKind.outline:
        bg = Colors.transparent;
        fg = on ? AppColors.accent : AppColors.muted;
        border = Border.all(color: on ? AppColors.accent : AppColors.border);
      case ButtonKind.ghost:
        bg = Colors.transparent;
        fg = on ? AppColors.text : AppColors.muted;
      case ButtonKind.dashed:
        bg = Colors.transparent;
        fg = AppColors.text;
    }
    final radius = height >= 52 ? 16.0 : 12.0;
    Widget content = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Ico(icon!, size: 20, color: fg), const SizedBox(width: 10)],
        Flexible(child: Text(label, style: bold(height >= 52 ? 16 : 15, color: fg), overflow: TextOverflow.ellipsis)),
      ],
    );
    Widget box = Container(
      height: height,
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(radius), border: border),
      child: content,
    );
    if (kind == ButtonKind.dashed) {
      box = CustomPaint(painter: _DashedBorder(radius: 14), child: SizedBox(height: height, child: content));
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: on ? onTap : null, borderRadius: BorderRadius.circular(radius), child: box),
    );
  }
}

class _DashedBorder extends CustomPainter {
  _DashedBorder({required this.radius});
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.muted
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final path = Path()
      ..addRRect(RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius)));
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        canvas.drawPath(metric.extractPath(d, d + 4), paint);
        d += 7;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedBorder old) => false;
}

class Avatar extends StatelessWidget {
  const Avatar({super.key, required this.name, required this.color, this.size = 40, this.ring = false});
  final String name;
  final Color color;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final ini = name.trim().isEmpty ? '?' : name.trim().characters.first.toUpperCase();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: ring ? Border.all(color: AppColors.bg, width: 2) : null,
      ),
      alignment: Alignment.center,
      child: Text(ini, style: bold(size * .36, color: AppColors.bg)),
    );
  }
}

class AvatarStack extends StatelessWidget {
  const AvatarStack({super.key, required this.items, this.max = 5});
  final List<(String, Color)> items;
  final int max;

  @override
  Widget build(BuildContext context) {
    final shown = items.take(max).toList();
    return SizedBox(
      height: 30,
      width: 30 + (shown.length - 1).clamp(0, 99) * 22.0,
      child: Stack(children: [
        for (var i = 0; i < shown.length; i++)
          Positioned(left: i * 22.0, child: Avatar(name: shown[i].$1, color: shown[i].$2, size: 30, ring: true)),
      ]),
    );
  }
}

class MonoLabel extends StatelessWidget {
  const MonoLabel(this.text, {super.key, this.color = AppColors.muted, this.size = 12});
  final String text;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(), style: mono(size, color: color));
}

/// Cabecera de pantalla: botÃ³n (volver/cerrar), tÃ­tulo y acciÃ³n opcional.
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.subtitle, this.icon = AppIcon.back, this.onBack, this.trailing, this.centered = false});
  final String title;
  final String? subtitle;
  final AppIcon icon;
  final VoidCallback? onBack;
  final Widget? trailing;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final back = SquareButton(icon: icon, onTap: onBack ?? () => Navigator.of(context).maybePop());
    final titleW = Column(
      crossAxisAlignment: centered ? CrossAxisAlignment.center : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: bold(centered ? 17 : 20), overflow: TextOverflow.ellipsis),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: sans(13, color: AppColors.muted)),
        ],
      ],
    );
    if (centered) {
      return Row(children: [back, Expanded(child: Center(child: titleW)), trailing ?? const SizedBox(width: 44)]);
    }
    return Row(children: [
      back,
      const SizedBox(width: 14),
      Expanded(child: titleW),
      ?trailing,
    ]);
  }
}

/// Selector segmentado (Piso / Viaje / Evento, tipo de divisiÃ³n...).
class Segmented<T> extends StatelessWidget {
  const Segmented({super.key, required this.options, required this.value, required this.onChanged, required this.label});
  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T) label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        for (final o in options) ...[
          if (o != options.first) const SizedBox(width: 4),
          Expanded(
            child: Tap(
              radius: 10,
              onTap: () => onChanged(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: o == value ? AppColors.accent : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(label(o), style: bold(14, color: o == value ? AppColors.bg : AppColors.muted)),
              ),
            ),
          ),
        ],
      ]),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({super.key, required this.icon, required this.color, required this.text, this.outlined = false, this.subtext});
  final AppIcon icon;
  final Color color;
  final String text;
  final String? subtext;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .14),
        borderRadius: BorderRadius.circular(14),
        border: outlined ? Border.all(color: color.withValues(alpha: .4)) : null,
      ),
      child: Row(children: [
        Ico(icon, size: 20, color: color, stroke: icon == AppIcon.check ? 2.5 : 2),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(text, style: sans(14, height: 1.35)),
            if (subtext != null) Text(subtext!, style: sans(12, color: AppColors.muted, height: 1.35)),
          ]),
        ),
      ]),
    );
  }
}

/// Fila "Etiqueta ........ Valor" dentro de una tarjeta.
class DetailRow extends StatelessWidget {
  const DetailRow({super.key, required this.label, required this.value, this.onTap, this.divider = true, this.valueColor = AppColors.text, this.padding = 14});
  final String label;
  final String value;
  final VoidCallback? onTap;
  final bool divider;
  final Color valueColor;
  final double padding;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      radius: 8,
      child: Container(
        padding: EdgeInsets.symmetric(vertical: padding),
        decoration: BoxDecoration(
          border: divider ? const Border(bottom: BorderSide(color: AppColors.border)) : null,
        ),
        child: Row(children: [
          Text(label, style: sans(15, color: AppColors.muted)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(value, textAlign: TextAlign.right, style: bold(15, color: valueColor), overflow: TextOverflow.ellipsis),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 6),
            const Ico(AppIcon.chevronRight, size: 16, color: AppColors.muted),
          ],
        ]),
      ),
    );
  }
}

class Pill extends StatelessWidget {
  const Pill(this.text, {super.key, this.color = AppColors.violet, this.fg = AppColors.bg});
  final String text;
  final Color color;
  final Color fg;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(999)),
        child: Text(text, style: bold(11, color: fg)),
      );
}

/// OpciÃ³n de una hoja inferior.
class SheetOption extends StatelessWidget {
  const SheetOption({super.key, required this.icon, required this.title, this.subtitle, required this.onTap, this.color = AppColors.accent});
  final AppIcon icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Tap(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Row(children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)),
            alignment: Alignment.center,
            child: Ico(icon, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: bold(16)),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: sans(13, color: AppColors.muted, height: 1.3)),
              ],
            ]),
          ),
        ]),
      ),
    );
  }
}

Future<T?> showAppSheet<T>(BuildContext context, {required String title, required Widget Function(BuildContext) builder}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: bold(19)),
          const SizedBox(height: 14),
          Flexible(child: SingleChildScrollView(child: builder(ctx))),
        ],
      ),
    ),
  );
}

Future<bool> confirm(BuildContext context, {required String title, required String body, String ok = 'Confirmar', bool danger = false}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text('Cancelar', style: bold(15, color: AppColors.muted))),
        TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(ok, style: bold(15, color: danger ? AppColors.coral : AppColors.accent))),
      ],
    ),
  );
  return r ?? false;
}

void toast(BuildContext context, String msg) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(msg)));
}

/// Cuerpo de pantalla con los mÃ¡rgenes del mockup (20 px a los lados).
class Screen extends StatelessWidget {
  const Screen({super.key, required this.child, this.bottom});
  final Widget child;
  final Widget? bottom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(children: [
          Expanded(child: child),
          if (bottom != null)
            Container(
              padding: EdgeInsets.fromLTRB(20, 12, 20, 16 + MediaQuery.of(context).padding.bottom),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.surface))),
              child: bottom,
            ),
        ]),
      ),
    );
  }
}
