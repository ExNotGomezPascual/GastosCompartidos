import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/money.dart';
import '../data/models.dart';
import '../state/app_cubits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'group_detail_screen.dart';
import 'group_form_screen.dart';
import 'notifications_screen.dart';
import 'voice_screen.dart';

/// Pantalla 2 del recorrido: Inicio.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  static Future<void> openVoice(BuildContext context, List<GroupOverview> groups, {int? groupId}) async {
    if (groups.isEmpty) {
      toast(context, 'Primero crea un grupo para registrar gastos.');
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupFormScreen()));
      return;
    }
    final id = groupId ?? groups.first.group.id;
    final saved = await Navigator.of(context).push<ExpenseSaved>(
      MaterialPageRoute(builder: (_) => VoiceScreen(groupId: id)),
    );
    if (saved != null && context.mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => GroupDetailScreen(groupId: saved.groupId, banner: saved.message),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = context.select((AppCubit c) => c.state.profile);
    final groups = context.watch<GroupsCubit>().state.groups;
    final unread = context.select((NoticesCubit c) => c.unread);
    final name = profile?.name ?? '';
    final now = DateTime.now();

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(children: [
            Avatar(name: name, color: AppColors.accent, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(greeting(now), style: sans(13, color: AppColors.muted)),
                const SizedBox(height: 2),
                Text('Hola, ${name.split(' ').first}', style: bold(20), overflow: TextOverflow.ellipsis),
              ]),
            ),
            SquareButton(
              icon: AppIcon.bell,
              iconSize: 22,
              badge: unread,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())),
            ),
          ]),
          const SizedBox(height: 20),
          _BalanceCard(groups: groups, now: now),
          const SizedBox(height: 20),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Expanded(child: Text('Tus grupos', style: bold(18))),
            Tap(
              radius: 8,
              onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GroupFormScreen())),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Text('+ Nuevo grupo', style: bold(14, color: AppColors.accent)),
              ),
            ),
          ]),
          const SizedBox(height: 12),
          if (groups.isEmpty)
            const EmptyState(
              icon: AppIcon.users,
              title: 'Aún no tienes grupos',
              body: 'Crea uno para tu piso, un viaje o un evento y agrega a quienes comparten los gastos.',
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
          Material(
            color: AppColors.accent,
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => openVoice(context, groups),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: const BoxDecoration(color: AppColors.bg, shape: BoxShape.circle),
                    alignment: Alignment.center,
                    child: const Ico(AppIcon.mic, size: 24, color: AppColors.accent),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Registrar gasto por voz', style: bold(17, color: AppColors.bg)),
                      const SizedBox(height: 2),
                      Text('Di qué pagaste y para quién', style: sans(14, color: AppColors.bg)),
                    ]),
                  ),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.groups, required this.now});
  final List<GroupOverview> groups;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    // Totales por moneda: no se suman monedas distintas.
    final byCur = <String, (int, int)>{};
    final count = <String, int>{};
    for (final g in groups) {
      final c = g.group.currency;
      final (owed, owe) = byCur[c] ?? (0, 0);
      byCur[c] = g.myBalance > 0 ? (owed + g.myBalance, owe) : (owed, owe - (g.myBalance < 0 ? g.myBalance : 0));
      count[c] = (count[c] ?? 0) + 1;
    }
    final codes = byCur.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
    final main = codes.isEmpty ? 'COP' : codes.first;
    final cur = currencyOf(main);
    final (owed, owe) = byCur[main] ?? (0, 0);
    final net = owed - owe;
    final multi = codes.length > 1;

    Widget mini(String label, int v, Color color) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.circular(14)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: sans(13, color: AppColors.muted)),
              const SizedBox(height: 4),
              Text(formatMoney(v, cur), style: bold(18, color: color)),
            ]),
          ),
        );

    return Box(
      radius: 22,
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        MonoLabel('Tu balance · ${monthName(now)}${multi ? ' · $main' : ''}'),
        const SizedBox(height: 16),
        Text(formatMoney(net, cur, signed: true),
            style: bold(40, color: net < 0 ? AppColors.coral : AppColors.accent, spacing: -.8)),
        const SizedBox(height: 4),
        Text(
          net > 0
              ? 'a tu favor entre todos tus grupos'
              : net < 0
                  ? 'en contra entre todos tus grupos'
                  : groups.isEmpty
                      ? 'crea un grupo para empezar'
                      : 'estás al día en todos tus grupos',
          style: sans(14, color: AppColors.muted),
        ),
        const SizedBox(height: 16),
        Row(children: [
          mini('Te deben', owed, AppColors.accent),
          const SizedBox(width: 10),
          mini('Debes', owe, AppColors.coral),
        ]),
        for (final code in codes.skip(1)) ...[
          const SizedBox(height: 10),
          Builder(builder: (_) {
            final (o, w) = byCur[code]!;
            final c = currencyOf(code);
            return Row(children: [
              Expanded(child: Text('En $code', style: sans(13, color: AppColors.muted))),
              Text('${formatMoney(o, c)} a favor · ${formatMoney(w, c)} en contra', style: sans(13)),
            ]);
          }),
        ],
      ]),
    );
  }
}

/// Resultado de guardar un gasto: a qué grupo ir y qué mensaje mostrar.
class ExpenseSaved {
  const ExpenseSaved(this.groupId, this.message);
  final int groupId;
  final String message;
}
