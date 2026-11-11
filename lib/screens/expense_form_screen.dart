import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/money.dart';
import '../data/repository.dart';
import '../domain/categories.dart';
import '../domain/recurrence.dart';
import '../domain/split.dart';
import '../state/expense_form_cubit.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import '../voice/parsed_expense.dart';
import 'home_screen.dart';

/// Pantalla 5 del recorrido: Revisar gasto (también sirve para crear a mano y editar).
class ExpenseFormScreen extends StatelessWidget {
  const ExpenseFormScreen({super.key, required this.groupId, this.expenseId, this.parsed, this.transcript});
  final int groupId;
  final int? expenseId;
  final ParsedExpense? parsed;
  final String? transcript;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ExpenseFormCubit(
        context.read<Repository>(),
        groupId: groupId,
        expenseId: expenseId,
        parsed: parsed,
        transcript: transcript,
      ),
      child: const _ExpenseFormView(),
    );
  }
}

class _ExpenseFormView extends StatelessWidget {
  const _ExpenseFormView();

  Future<void> _editConcept(BuildContext context, ExpenseFormState s) async {
    final c = TextEditingController(text: s.concept);
    final ok = await showAppSheet<bool>(
      context,
      title: 'Concepto',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        TextField(
          controller: c,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          style: bold(17),
          decoration: const InputDecoration(hintText: 'Ej. Mercado D1'),
          onSubmitted: (_) => Navigator.pop(ctx, true),
        ),
        const SizedBox(height: 16),
        AppButton('Listo', onTap: () => Navigator.pop(ctx, true)),
      ]),
    );
    if (ok == true && context.mounted) context.read<ExpenseFormCubit>().setConcept(c.text.trim());
  }

  Future<void> _pickCategory(BuildContext context, ExpenseFormState s) async {
    final v = await showAppSheet<String>(
      context,
      title: 'Categoría',
      builder: (ctx) => Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in categories)
          _Chip(label: c, selected: c == s.category, onTap: () => Navigator.pop(ctx, c)),
      ]),
    );
    if (v != null && context.mounted) context.read<ExpenseFormCubit>().setCategory(v);
  }

  Future<void> _pickPayer(BuildContext context, ExpenseFormState s) async {
    final d = s.detail!;
    final v = await showAppSheet<int>(
      context,
      title: '¿Quién pagó?',
      builder: (ctx) => Column(children: [
        for (final m in d.members)
          Tap(
            onTap: () => Navigator.pop(ctx, m.id),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              child: Row(children: [
                Avatar(name: m.name, color: AppColors.avatar(m.colorIndex), size: 36),
                const SizedBox(width: 12),
                Expanded(child: Text(m.isMe ? 'Tú' : m.name, style: bold(16))),
                if (m.id == s.payerId) const Ico(AppIcon.check, size: 18, color: AppColors.accent),
              ]),
            ),
          ),
      ]),
    );
    if (v != null && context.mounted) context.read<ExpenseFormCubit>().setPayer(v);
  }

  Future<void> _pickDate(BuildContext context, ExpenseFormState s) async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: s.date,
      firstDate: DateTime(now.year - 3),
      lastDate: DateTime(now.year + 1, 12, 31),
      helpText: 'Fecha del gasto',
    );
    if (d != null && context.mounted) context.read<ExpenseFormCubit>().setDate(d);
  }

  Future<void> _save(BuildContext context) async {
    final cubit = context.read<ExpenseFormCubit>();
    final msg = await cubit.save();
    if (msg != null && context.mounted) Navigator.of(context).pop(ExpenseSaved(cubit.groupId, msg));
  }

  Future<void> _delete(BuildContext context) async {
    final cubit = context.read<ExpenseFormCubit>();
    if (await confirm(context,
        title: '¿Eliminar gasto?',
        body: 'Se recalculan los saldos del grupo. No se puede deshacer.',
        ok: 'Eliminar',
        danger: true)) {
      await cubit.delete();
      if (context.mounted) Navigator.of(context).pop(ExpenseSaved(cubit.groupId, 'Gasto eliminado.'));
    }
  }

  String _splitSummary(ExpenseFormState s) {
    final cur = s.currency;
    final amount = s.amount ?? 0;
    switch (s.splitType) {
      case SplitType.equal:
        final n = s.selected.length;
        if (n == 0) return 'Elige al menos una persona';
        if (amount <= 0) return 'Partes iguales';
        return 'Partes iguales · ${formatMoney(amount ~/ n, cur)} c/u';
      case SplitType.exact:
        final sum = s.parsedInputs.values.fold<int>(0, (a, b) => a + b);
        final diff = amount - sum;
        if (diff == 0) return 'Cuadra con el total';
        return diff > 0 ? 'Faltan ${formatMoney(diff, cur)}' : 'Sobran ${formatMoney(-diff, cur)}';
      case SplitType.percent:
        final sum = s.parsedInputs.values.fold<int>(0, (a, b) => a + b);
        final diff = 10000 - sum;
        if (diff == 0) return 'Suma 100 %';
        return diff > 0 ? 'Falta ${formatPercent(diff)} %' : 'Sobra ${formatPercent(-diff)} %';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ExpenseFormCubit, ExpenseFormState>(
      builder: (context, s) {
        final cubit = context.read<ExpenseFormCubit>();
        if (s.loading || s.detail == null) return const Scaffold();
        final d = s.detail!;
        final cur = s.currency;
        final title = cubit.editing ? 'Editar gasto' : (s.byVoice ? 'Revisar gasto' : 'Nuevo gasto');
        final summaryOk = s.split.ok;
        final hint = s.splitCountHint;

        return Screen(
          bottom: AppButton('Guardar gasto', onTap: () => _save(context), enabled: s.valid && !s.saving),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              ScreenHeader(
                title: title,
                trailing: cubit.editing ? SquareButton(icon: AppIcon.trash, onTap: () => _delete(context)) : null,
              ),
              const SizedBox(height: 18),
              if (s.byVoice && !cubit.editing) ...[
                InfoBanner(
                  icon: AppIcon.mic,
                  color: AppColors.violet,
                  outlined: true,
                  text: 'Detectado por voz. Revisa los datos antes de guardar.',
                  subtext: [
                    if (s.transcript != null && s.transcript!.isNotEmpty) '“${s.transcript}”',
                    if (s.source == ParseSource.rules) 'Analizado sin IA.',
                  ].join(' '),
                ),
                const SizedBox(height: 18),
              ],
              MonoLabel('Monto'),
              const SizedBox(height: 6),
              TextFormField(
                key: ValueKey('amount-${s.inputsVersion > 0}'),
                initialValue: s.amountText,
                onChanged: cubit.setAmount,
                keyboardType: TextInputType.numberWithOptions(decimal: cur.decimals > 0),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                style: bold(44, spacing: -.9),
                decoration: InputDecoration(
                  filled: false,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  prefixText: cur.symbol,
                  prefixStyle: bold(44, spacing: -.9),
                  hintText: '0',
                  hintStyle: bold(44, color: AppColors.border),
                ),
              ),
              const SizedBox(height: 16),
              Box(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Column(children: [
                  DetailRow(
                    label: 'Concepto',
                    value: s.concept.isEmpty ? 'Escribe el concepto' : s.concept,
                    valueColor: s.concept.isEmpty ? AppColors.coral : AppColors.text,
                    onTap: () => _editConcept(context, s),
                  ),
                  DetailRow(label: 'Categoría', value: s.category, onTap: () => _pickCategory(context, s)),
                  DetailRow(label: 'Pagó', value: d.nameOf(s.payerId ?? d.me.id), onTap: () => _pickPayer(context, s)),
                  DetailRow(label: 'Fecha', value: longDate(s.date), divider: false, onTap: () => _pickDate(context, s)),
                ]),
              ),
              const SizedBox(height: 18),
              Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text('Dividir entre', style: bold(16)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(_splitSummary(s),
                      textAlign: TextAlign.right,
                      style: bold(14, color: summaryOk ? AppColors.accent : AppColors.coral)),
                ),
              ]),
              if (hint != null && hint < d.members.length && s.byVoice && !cubit.editing) ...[
                const SizedBox(height: 6),
                Text('Dijiste $hint personas: confirma quiénes.', style: sans(13, color: AppColors.amber)),
              ],
              const SizedBox(height: 10),
              Segmented<SplitType>(
                options: SplitType.values,
                value: s.splitType,
                onChanged: cubit.setSplitType,
                label: (t) => t.label,
              ),
              const SizedBox(height: 12),
              if (s.splitType == SplitType.equal)
                Wrap(spacing: 8, runSpacing: 8, children: [
                  for (final m in d.members)
                    _MemberChip(
                      name: m.isMe ? 'Tú' : m.name,
                      initial: m.name,
                      color: AppColors.avatar(m.colorIndex),
                      selected: s.selected.contains(m.id),
                      onTap: () => cubit.toggleMember(m.id),
                    ),
                ])
              else
                Box(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  child: Column(children: [
                    for (final m in d.members)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Row(children: [
                          Avatar(name: m.name, color: AppColors.avatar(m.colorIndex), size: 34),
                          const SizedBox(width: 10),
                          Expanded(child: Text(m.isMe ? 'Tú' : m.name, style: bold(15), overflow: TextOverflow.ellipsis)),
                          SizedBox(
                            width: 130,
                            child: TextFormField(
                              key: ValueKey('in-${s.splitType.name}-${m.id}-${s.inputsVersion}'),
                              initialValue: s.inputs[m.id] ?? '',
                              onChanged: (v) => cubit.setInput(m.id, v),
                              textAlign: TextAlign.right,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.,]'))],
                              style: bold(15),
                              decoration: InputDecoration(
                                isDense: true,
                                fillColor: AppColors.bg,
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                hintText: '0',
                                prefixText: s.splitType == SplitType.exact ? cur.symbol : null,
                                suffixText: s.splitType == SplitType.percent ? '%' : null,
                                prefixStyle: sans(15, color: AppColors.muted),
                                suffixStyle: sans(15, color: AppColors.muted),
                              ),
                            ),
                          ),
                        ]),
                      ),
                  ]),
                ),
              if (!cubit.editing) ...[
                const SizedBox(height: 18),
                Box(
                  padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
                  child: Column(children: [
                    Row(children: [
                      const Ico(AppIcon.repeat, size: 20, color: AppColors.violet),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text('Repetir este gasto', style: bold(15)),
                          Text('Se registra solo en la próxima fecha', style: sans(12, color: AppColors.muted)),
                        ]),
                      ),
                      Switch(value: s.repeat, onChanged: cubit.setRepeat),
                    ]),
                    if (s.repeat) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(right: 6, bottom: 6),
                        child: Segmented<Frequency>(
                          options: Frequency.values,
                          value: s.frequency,
                          onChanged: cubit.setFrequency,
                          label: (f) => f.label,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          'Próxima vez: ${longDate(nextOccurrence(s.date, s.frequency, s.date.day))}',
                          style: sans(13, color: AppColors.muted),
                        ),
                      ),
                    ],
                  ]),
                ),
              ] else if (s.recurringId != null) ...[
                const SizedBox(height: 14),
                Text('Este gasto lo creó un gasto recurrente. Los cambios solo aplican a esta vez.',
                    style: sans(13, color: AppColors.muted, height: 1.4)),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.name, required this.initial, required this.color, required this.selected, required this.onTap});
  final String name;
  final String initial;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tap(
      radius: 999,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        height: 44,
        padding: const EdgeInsets.fromLTRB(6, 0, 16, 0),
        decoration: BoxDecoration(
          color: selected ? AppColors.text : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AppColors.text : AppColors.border),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Avatar(name: initial, color: color, size: 32),
          const SizedBox(width: 8),
          Text(name, style: bold(15, color: selected ? AppColors.bg : AppColors.muted)),
        ]),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Tap(
        radius: 999,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? AppColors.accent : AppColors.border),
          ),
          child: Text(label, style: bold(14, color: selected ? AppColors.bg : AppColors.text)),
        ),
      );
}
