import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/models.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

(AppIcon, Color) groupTypeIcon(GroupType t) => switch (t) {
      GroupType.piso => (AppIcon.house, AppColors.accent),
      GroupType.viaje => (AppIcon.mountain, AppColors.violet),
      GroupType.evento => (AppIcon.calendar, AppColors.amber),
    };

class GroupTypeBadge extends StatelessWidget {
  const GroupTypeBadge(this.type, {super.key, this.size = 46});
  final GroupType type;
  final double size;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = groupTypeIcon(type);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(14)),
      alignment: Alignment.center,
      child: Ico(icon, color: color),
    );
  }
}

/// Texto y color del saldo propio: "Te deben", "Debes" o "Al día".
(String, Color) balanceLabel(int balance) {
  if (balance > 0) return ('Te deben', AppColors.accent);
  if (balance < 0) return ('Debes', AppColors.coral);
  return ('Al día', AppColors.muted);
}

class GroupCard extends StatelessWidget {
  const GroupCard({super.key, required this.overview, required this.onTap, this.trailing});
  final GroupOverview overview;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final g = overview;
    final (label, color) = balanceLabel(g.myBalance);
    return Box(
      onTap: onTap,
      child: Row(children: [
        GroupTypeBadge(g.type),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(g.group.name, style: bold(16), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 3),
            Text('${g.type.longLabel} · ${g.memberCount} ${g.memberCount == 1 ? 'persona' : 'personas'}',
                style: sans(13, color: AppColors.muted)),
          ]),
        ),
        const SizedBox(width: 8),
        trailing ??
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text(label, style: sans(12, color: AppColors.muted)),
              const SizedBox(height: 3),
              if (g.myBalance != 0)
                Text(formatMoney(g.myBalance.abs(), g.currency), style: bold(16, color: color))
              else
                const Ico(AppIcon.check, size: 18, color: AppColors.muted),
            ]),
      ]),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});
  final AppIcon icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Box(
      padding: const EdgeInsets.all(20),
      child: Column(children: [
        Ico(icon, size: 28, color: AppColors.muted),
        const SizedBox(height: 10),
        Text(title, style: bold(16), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(body, style: sans(14, color: AppColors.muted, height: 1.4), textAlign: TextAlign.center),
        if (action != null) ...[const SizedBox(height: 14), action!],
      ]),
    );
  }
}
