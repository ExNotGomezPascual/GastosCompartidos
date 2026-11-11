import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/money.dart';
import '../data/repository.dart';
import '../state/app_cubits.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

/// Pantalla 8 del recorrido: Pago registrado. Devuelve 'group' o 'home'.
class PaymentDoneScreen extends StatelessWidget {
  const PaymentDoneScreen({super.key, required this.groupId, required this.fromId, required this.toId, required this.amount});
  final int groupId;
  final int fromId;
  final int toId;
  final int amount;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GroupDetailCubit(context.read<Repository>(), groupId),
      child: BlocBuilder<GroupDetailCubit, GroupDetailState>(
        builder: (context, s) {
          final d = s.detail;
          if (d == null) return const Scaffold();
          final cur = d.currency;
          final from = d.member(fromId), to = d.member(toId);
          final money = formatMoney(amount, cur);
          final headline = from?.isMe == true
              ? 'Le pagaste $money a ${to?.name}.'
              : to?.isMe == true
                  ? '${from?.name} te pagó $money.'
                  : '${from?.name} le pagó $money a ${to?.name}.';
          final left = d.balances[fromId] ?? 0;
          final who = from?.isMe == true ? 'Tu' : 'Su';
          final tail = left >= 0
              ? '$who saldo en ${d.group.name} quedó en cero.'
              : from?.isMe == true
                  ? 'Aún te quedan ${formatMoney(-left, cur)} pendientes.'
                  : 'Aún le quedan ${formatMoney(-left, cur)} pendientes.';

          return Scaffold(
            body: SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: Column(children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(children: [
                          Container(
                            width: 96,
                            height: 96,
                            decoration: const BoxDecoration(color: AppColors.accent, shape: BoxShape.circle),
                            alignment: Alignment.center,
                            child: const Ico(AppIcon.check, size: 44, color: AppColors.bg, stroke: 2.5),
                          ),
                          const SizedBox(height: 16),
                          Text('Pago registrado', style: bold(28)),
                          const SizedBox(height: 16),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 290),
                            child: Text('$headline $tail',
                                textAlign: TextAlign.center, style: sans(16, color: AppColors.muted, height: 1.4)),
                          ),
                        ]),
                      ),
                    ),
                  ),
                  Box(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      MonoLabel('Pendiente en el grupo'),
                      const SizedBox(height: 12),
                      if (d.transfers.isEmpty)
                        Text('Nada pendiente: el grupo está a paz y salvo.', style: sans(15))
                      else
                        for (final t in d.transfers) ...[
                          Row(children: [
                            Expanded(child: Text('${d.nameOf(t.fromId)} → ${d.nameOf(t.toId)}', style: sans(15))),
                            Text(formatMoney(t.amount, cur), style: bold(15)),
                          ]),
                          const SizedBox(height: 12),
                        ],
                      if (d.transfers.isEmpty) const SizedBox(height: 12),
                      Container(height: 1, color: AppColors.border),
                      const SizedBox(height: 12),
                      Row(children: [
                        Expanded(child: Text('Tu saldo ahora', style: sans(15, color: AppColors.muted))),
                        Text(formatMoney(d.myBalance, cur, signed: true),
                            style: bold(15, color: d.myBalance < 0 ? AppColors.coral : AppColors.accent)),
                      ]),
                    ]),
                  ),
                  const SizedBox(height: 24),
                  AppButton('Volver al grupo', onTap: () => Navigator.pop(context, 'group')),
                  const SizedBox(height: 10),
                  AppButton('Ir al inicio', kind: ButtonKind.ghost, height: 48, onTap: () => Navigator.pop(context, 'home')),
                ]),
              ),
            ),
          );
        },
      ),
    );
  }
}
