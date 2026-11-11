import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/database.dart';
import '../state/app_cubits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'group_detail_screen.dart';
import 'settle_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NoticesCubit _cubit;

  @override
  void initState() {
    super.initState();
    _cubit = context.read<NoticesCubit>();
  }

  @override
  void dispose() {
    _cubit.markRead();
    super.dispose();
  }

  (AppIcon, Color) _style(String kind) => switch (kind) {
        'recurrente' => (AppIcon.repeat, AppColors.violet),
        'pago' => (AppIcon.check, AppColors.accent),
        'cobro' => (AppIcon.bell, AppColors.coral),
        _ => (AppIcon.bell, AppColors.muted),
      };

  void _open(AppNotice n) {
    if (n.groupId == null) return;
    final page = n.kind == 'cobro'
        ? SettleScreen(groupId: n.groupId!)
        : GroupDetailScreen(groupId: n.groupId!);
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context) {
    final notices = context.watch<NoticesCubit>().state;
    return Screen(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          const ScreenHeader(title: 'Avisos'),
          const SizedBox(height: 20),
          if (notices.isEmpty)
            const EmptyState(
              icon: AppIcon.bell,
              title: 'Sin avisos',
              body: 'Aquí verás los gastos recurrentes que se registren solos, los pagos y lo que tienes por cobrar.',
            ),
          for (final n in notices) ...[
            Box(
              onTap: n.groupId == null ? null : () => _open(n),
              borderColor: n.read ? AppColors.border : AppColors.accent.withValues(alpha: .5),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Builder(builder: (_) {
                  final (icon, color) = _style(n.kind);
                  return Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(color: color.withValues(alpha: .15), borderRadius: BorderRadius.circular(12)),
                    alignment: Alignment.center,
                    child: Ico(icon, size: 20, color: color),
                  );
                }),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(n.title, style: bold(15)),
                    const SizedBox(height: 3),
                    Text(n.body, style: sans(14, color: AppColors.muted, height: 1.35)),
                    const SizedBox(height: 6),
                    Text(timeAgo(n.createdAt), style: mono(11)),
                  ]),
                ),
              ]),
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}
