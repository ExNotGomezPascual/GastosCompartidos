import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../state/app_cubits.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'group_detail_screen.dart';
import 'group_form_screen.dart';

class GroupsTab extends StatelessWidget {
  const GroupsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final groups = context.watch<GroupsCubit>().state.groups;
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Grupos', style: bold(28)),
          const SizedBox(height: 6),
          Text('Piso, viajes y eventos que compartes.', style: sans(15, color: AppColors.muted)),
          const SizedBox(height: 20),
          if (groups.isEmpty)
            const EmptyState(
              icon: AppIcon.users,
              title: 'Aún no tienes grupos',
              body: 'Crea el primero e invita a quienes comparten los gastos.',
            ),
          for (final g in groups) ...[
            GroupCard(
              overview: g,
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: g.group.id))),
            ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 8),
          AppButton('Nuevo grupo',
              icon: AppIcon.plus,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupFormScreen()))),
        ],
      ),
    );
  }
}
