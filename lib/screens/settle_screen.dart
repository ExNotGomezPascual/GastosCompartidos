import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/money.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../domain/settlement.dart';
import '../state/app_cubits.dart';
import '../ui/icons.dart';
import '../ui/messaging.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'group_detail_screen.dart';
import 'payment_done_screen.dart';

/// Pantalla 7 del recorrido: Liquidación mínima.
class SettleScreen extends StatelessWidget {
  const SettleScreen({super.key, required this.groupId, this.fromDetail = false});
  final int groupId;
  final bool fromDetail;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GroupDetailCubit(context.read<Repository>(), groupId),
      child: _SettleView(groupId: groupId, fromDetail: fromDetail),
    );
  }
}

/// Nombre real (para mensajes que leen otras personas).
String realName(GroupDetail d, int id) => d.member(id)?.name ?? 'Alguien';

class _SettleView extends StatelessWidget {
  const _SettleView({required this.groupId, required this.fromDetail});
  final int groupId;
  final bool fromDetail;

  (String, String) _labels(GroupDetail d, Transfer t) {
    final from = d.member(t.fromId), to = d.member(t.toId);
    if (from?.isMe == true) return ('Le pagas a ${to?.name}', 'Tú pagas');
    if (to?.isMe == true) return ('${from?.name} te paga', 'A ti');
    return ('${from?.name} le paga a ${to?.name}', 'Entre ellos');
  }

  Future<void> _remind(GroupDetail d, Transfer t) async {
    final from = d.member(t.fromId)!;
    final to = d.member(t.toId)!;
    final money = formatMoney(t.amount, d.currency);
    final text = 'Hola ${from.name.split(' ').first}, te recuerdo que en “${d.group.name}” te falta pagarle '
        '$money a ${to.isMe ? 'mí' : to.name}. ¡Gracias! (Gastos Compartidos)';
    await sendMessage(phone: from.phone, text: text);
  }

  Future<void> _remindGroup(GroupDetail d) async {
    final lines = [
      for (final t in d.transfers)
        '• ${realName(d, t.fromId)} → ${realName(d, t.toId)}: ${formatMoney(t.amount, d.currency)}',
    ];
    final n = d.transfers.length;
    await shareText(
      'Cuentas de “${d.group.name}”:\n${lines.join('\n')}\n\n'
      'Con ${n == 1 ? 'este pago' : 'estos $n pagos'} quedamos a paz y salvo. (Gastos Compartidos)',
      subject: 'Cuentas de ${d.group.name}',
    );
  }

  Future<void> _markPaid(BuildContext context, GroupDetail d, Transfer t) async {
    final cur = d.currency;
    final ctrl = TextEditingController(text: moneyInputText(t.amount, cur));
    final amount = await showAppSheet<int>(
      context,
      title: 'Registrar pago',
      builder: (ctx) => StatefulBuilder(builder: (ctx, setS) {
        final v = parseMoney(ctrl.text, cur);
        final ok = v != null && v > 0 && v <= t.amount;
        return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('${d.nameOf(t.fromId)} → ${d.nameOf(t.toId)}', style: sans(15, color: AppColors.muted)),
          const SizedBox(height: 12),
          TextField(
            controller: ctrl,
            autofocus: true,
            onChanged: (_) => setS(() {}),
            keyboardType: TextInputType.numberWithOptions(decimal: cur.decimals > 0),
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
            style: bold(28),
            decoration: InputDecoration(prefixText: cur.symbol, prefixStyle: bold(28)),
          ),
          const SizedBox(height: 8),
          Text(
            v != null && v > t.amount
                ? 'No puede ser mayor a ${formatMoney(t.amount, cur)}.'
                : 'Si pagó solo una parte, escribe ese monto. El resto queda pendiente.',
            style: sans(13, color: v != null && v > t.amount ? AppColors.coral : AppColors.muted, height: 1.4),
          ),
          const SizedBox(height: 16),
          AppButton('Registrar pago', enabled: ok, onTap: () => Navigator.pop(ctx, v)),
        ]);
      }),
    );
    if (amount == null || !context.mounted) return;
    final repo = context.read<Repository>();
    final tabs = context.read<TabCubit>();
    final nav = Navigator.of(context);
    await repo.recordPayment(groupId: groupId, fromId: t.fromId, toId: t.toId, amount: amount);
    final r = await nav.push<String>(MaterialPageRoute(
      builder: (_) => PaymentDoneScreen(groupId: groupId, fromId: t.fromId, toId: t.toId, amount: amount),
    ));
    if (r == 'group') {
      if (fromDetail) {
        nav.pop();
      } else {
        nav.pushReplacement(MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: groupId)));
      }
    } else if (r == 'home') {
      tabs.go(0);
      nav.popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GroupDetailCubit, GroupDetailState>(
      builder: (context, s) {
        final d = s.detail;
        if (d == null) return const Scaffold();
        final n = d.transfers.length;
        return Screen(
          bottom: n == 0
              ? null
              : Column(mainAxisSize: MainAxisSize.min, children: [
                  AppButton('Enviar recordatorio al grupo',
                      icon: AppIcon.bell, kind: ButtonKind.light, height: 54, onTap: () => _remindGroup(d)),
                  const SizedBox(height: 8),
                  Text('La app redacta el mensaje por ti.', style: sans(13, color: AppColors.muted)),
                ]),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              ScreenHeader(title: 'Saldar cuentas', subtitle: d.group.name),
              const SizedBox(height: 18),
              MonoLabel('Liquidación mínima', color: AppColors.accent),
              const SizedBox(height: 8),
              Text(
                n == 0 ? 'Todo está saldado' : n == 1 ? '1 pago salda todo el grupo' : '$n pagos saldan todo el grupo',
                style: bold(28, height: 1.15),
              ),
              const SizedBox(height: 8),
              Text(
                n == 0
                    ? 'Nadie le debe a nadie en ${d.group.name}.'
                    : d.naiveCount > n
                        ? 'Sin simplificar serían ${d.naiveCount} transferencias cruzadas.'
                        : 'Es el menor número de pagos posible.',
                style: sans(15, color: AppColors.muted, height: 1.4),
              ),
              const SizedBox(height: 18),
              for (final t in d.transfers) ...[
                _transferCard(context, d, t),
                const SizedBox(height: 10),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _transferCard(BuildContext context, GroupDetail d, Transfer t) {
    final from = d.member(t.fromId)!, to = d.member(t.toId)!;
    final (label, sub) = _labels(d, t);
    final mine = from.isMe || to.isMe;
    return Box(
      child: Column(children: [
        Row(children: [
          Avatar(name: from.name, color: AppColors.avatar(from.colorIndex), size: 38),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Ico(AppIcon.arrowRight, size: 18, color: AppColors.muted),
          ),
          Avatar(name: to.name, color: AppColors.avatar(to.colorIndex), size: 38),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: bold(15), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(sub, style: sans(13, color: AppColors.muted)),
            ]),
          ),
          Text(formatMoney(t.amount, d.currency), style: bold(17)),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(
            child: AppButton('Marcar como pagado',
                kind: mine ? ButtonKind.outline : ButtonKind.ghost,
                height: 44,
                onTap: () => _markPaid(context, d, t)),
          ),
          if (!from.isMe) ...[
            const SizedBox(width: 8),
            Box(
              radius: 12,
              padding: EdgeInsets.zero,
              onTap: () => _remind(d, t),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Ico(from.phone == null ? AppIcon.share : AppIcon.message, size: 20, color: AppColors.accent),
                ),
              ),
            ),
          ],
        ]),
      ]),
    );
  }
}
