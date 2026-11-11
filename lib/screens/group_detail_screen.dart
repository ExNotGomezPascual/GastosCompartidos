import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/money.dart';
import '../data/database.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../domain/recurrence.dart';
import '../state/app_cubits.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'common.dart';
import 'expense_form_screen.dart';
import 'group_form_screen.dart';
import 'home_screen.dart';
import 'settle_screen.dart';
import 'voice_screen.dart';

/// Pantalla 6 del recorrido: Detalle del grupo.
class GroupDetailScreen extends StatelessWidget {
  const GroupDetailScreen({super.key, required this.groupId, this.banner});
  final int groupId;
  final String? banner;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => GroupDetailCubit(context.read<Repository>(), groupId),
      child: _GroupDetailView(groupId: groupId, initialBanner: banner),
    );
  }
}

class _GroupDetailView extends StatefulWidget {
  const _GroupDetailView({required this.groupId, this.initialBanner});
  final int groupId;
  final String? initialBanner;

  @override
  State<_GroupDetailView> createState() => _GroupDetailViewState();
}

class _GroupDetailViewState extends State<_GroupDetailView> {
  String? _banner;

  @override
  void initState() {
    super.initState();
    _banner = widget.initialBanner;
  }

  Future<void> _handle(Future<ExpenseSaved?> f) async {
    final r = await f;
    if (r != null && mounted) setState(() => _banner = r.message);
  }

  void _addSheet() {
    showAppSheet<void>(
      context,
      title: 'Agregar gasto',
      builder: (ctx) => Column(children: [
        SheetOption(
          icon: AppIcon.mic,
          color: AppColors.violet,
          title: 'Por voz',
          subtitle: 'Di qué pagaste y para quién.',
          onTap: () {
            Navigator.pop(ctx);
            _handle(Navigator.of(context).push<ExpenseSaved>(
                MaterialPageRoute(builder: (_) => VoiceScreen(groupId: widget.groupId, lockGroup: true))));
          },
        ),
        SheetOption(
          icon: AppIcon.keyboard,
          title: 'Escribirlo',
          subtitle: 'Llena el monto, el concepto y cómo se divide.',
          onTap: () {
            Navigator.pop(ctx);
            _handle(Navigator.of(context).push<ExpenseSaved>(
                MaterialPageRoute(builder: (_) => ExpenseFormScreen(groupId: widget.groupId))));
          },
        ),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupDetailCubit, GroupDetailState>(
      listenWhen: (a, b) => !b.loading && b.detail == null,
      listener: (context, _) => Navigator.of(context).maybePop(),
      builder: (context, s) {
        final d = s.detail;
        if (d == null) return const Scaffold();
        final cur = d.currency;
        final now = DateTime.now();
        final (_, balColor) = balanceLabel(d.myBalance);
        Widget stat(String label, String value, Color color) => Expanded(
              child: Box(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(label, style: sans(13, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  FittedBox(fit: BoxFit.scaleDown, child: Text(value, style: bold(22, color: color))),
                ]),
              ),
            );

        return Screen(
          bottom: AppButton(
            'Ver quién le debe a quién',
            icon: AppIcon.swap,
            onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => SettleScreen(groupId: widget.groupId, fromDetail: true))),
          ),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            children: [
              ScreenHeader(
                title: d.group.name,
                subtitle: '${d.type.longLabel} · ${cur.code}',
                trailing: Tap(
                  radius: 15,
                  onTap: () => Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => GroupFormScreen(groupId: widget.groupId))),
                  child: AvatarStack(items: [
                    for (final m in d.members) (m.name, AppColors.avatar(m.colorIndex)),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                stat('Gastos de ${monthName(now)}', formatMoney(d.monthTotal(now), cur), AppColors.text),
                const SizedBox(width: 10),
                stat('Tu saldo', formatMoney(d.myBalance, cur, signed: true),
                    d.myBalance == 0 ? AppColors.text : balColor),
              ]),
              if (_banner != null) ...[
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => setState(() => _banner = null),
                  child: InfoBanner(icon: AppIcon.check, color: AppColors.accent, text: _banner!),
                ),
              ],
              const SizedBox(height: 16),
              Row(children: [
                Expanded(child: Text('Gastos', style: bold(17))),
                Tap(
                  radius: 8,
                  onTap: _addSheet,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text('+ Agregar', style: bold(14, color: AppColors.accent)),
                  ),
                ),
              ]),
              const SizedBox(height: 4),
              if (d.expenses.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: EmptyState(
                    icon: AppIcon.mic,
                    title: 'Sin gastos todavía',
                    body: 'Registra el primero por voz o escribiéndolo.',
                    action: AppButton('Agregar gasto', height: 44, kind: ButtonKind.outline, onTap: _addSheet),
                  ),
                ),
              for (final e in d.expenses) _expenseRow(d, e),
              if (d.recurrings.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Gastos recurrentes', style: bold(17)),
                const SizedBox(height: 4),
                for (final r in d.recurrings) _recurringRow(d, r),
              ],
              if (d.payments.isNotEmpty) ...[
                const SizedBox(height: 20),
                Text('Pagos registrados', style: bold(17)),
                const SizedBox(height: 4),
                for (final p in d.payments) _paymentRow(d, p),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _expenseRow(GroupDetail d, ExpenseItem item) {
    final e = item.expense;
    final payer = d.member(e.payerId);
    final who = payer?.isMe == true ? 'Pagaste tú' : 'Pagó ${payer?.name ?? 'alguien'}';
    return Tap(
      radius: 8,
      onTap: () => _handle(Navigator.of(context).push<ExpenseSaved>(MaterialPageRoute(
          builder: (_) => ExpenseFormScreen(groupId: d.group.id, expenseId: e.id)))),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surface))),
        child: Row(children: [
          Avatar(name: payer?.name ?? '?', color: AppColors.avatar(payer?.colorIndex ?? 0)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Flexible(child: Text(e.concept, style: bold(15), overflow: TextOverflow.ellipsis)),
                if (e.byVoice) ...[const SizedBox(width: 8), const Pill('POR VOZ')],
                if (e.recurringId != null) ...[
                  const SizedBox(width: 6),
                  const Ico(AppIcon.repeat, size: 14, color: AppColors.muted),
                ],
              ]),
              const SizedBox(height: 3),
              Text('$who · ${shortDate(e.date)}', style: sans(13, color: AppColors.muted)),
            ]),
          ),
          const SizedBox(width: 8),
          Text(formatMoney(e.amount, d.currency), style: bold(15)),
        ]),
      ),
    );
  }

  Widget _recurringRow(GroupDetail d, Recurring r) {
    final f = Frequency.parse(r.frequency);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.surface))),
      child: Row(children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(color: AppColors.violet.withValues(alpha: .15), shape: BoxShape.circle),
          alignment: Alignment.center,
          child: const Ico(AppIcon.repeat, size: 18, color: AppColors.violet),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(r.concept, style: bold(15)),
            const SizedBox(height: 3),
            Text('${f.label} · próximo ${shortDate(r.nextDate).toLowerCase()} · paga ${d.nameOf(r.payerId).toLowerCase() == 'tú' ? 'tú' : d.nameOf(r.payerId)}',
                style: sans(13, color: AppColors.muted)),
          ]),
        ),
        Text(formatMoney(r.amount, d.currency), style: bold(15)),
        IconButton(
          tooltip: 'Dejar de repetir',
          onPressed: () async {
            final repo = context.read<Repository>();
            if (await confirm(context,
                title: 'Dejar de repetir',
                body: '“${r.concept}” no se registrará más. Los gastos ya creados se mantienen.',
                ok: 'Dejar de repetir',
                danger: true)) {
              await repo.deleteRecurring(r.id);
            }
          },
          icon: const Ico(AppIcon.close, size: 18, color: AppColors.muted),
        ),
      ]),
    );
  }

  Widget _paymentRow(GroupDetail d, Payment p) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(children: [
        const SizedBox(width: 40, child: Center(child: Ico(AppIcon.check, size: 18, color: AppColors.accent))),
        const SizedBox(width: 12),
        Expanded(
          child: Text('${d.nameOf(p.fromId)} → ${d.nameOf(p.toId)} · ${shortDate(p.date)}',
              style: sans(14, color: AppColors.muted)),
        ),
        Text(formatMoney(p.amount, d.currency), style: bold(14)),
      ]),
    );
  }
}
