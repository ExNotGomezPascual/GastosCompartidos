import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/app_cubits.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'settle_screen.dart';

/// Pestaña Saldar: primero se elige el grupo.
class SettleTab extends StatelessWidget {
  const SettleTab({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupsCubit>().state.groups;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          MonoLabel('Liquidación mínima', color: AppColors.accent),
          const SizedBox(height: 8),
          Text('Saldar cuentas', style: bold(28)),
          const SizedBox(height: 6),
          Text('Elige un grupo para ver quién le debe a quién con el menor número de pagos.',
              style: sans(15, color: AppColors.muted, height: 1.4)),
          const SizedBox(height: 20),
          if (groups.isEmpty)
            const EmptyState(
              icon: AppIcon.swap,
              title: 'Nada por saldar',
              body: 'Cuando tengas grupos con gastos, aquí verás los pagos pendientes.',
            ),
          for (final g in groups) ...[
            GroupCard(
              overview: g,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => SettleScreen(groupId: g.group.id))),
            ),
            const SizedBox(height: 12),
          ],
        ],
      ),
    );
  }
}
