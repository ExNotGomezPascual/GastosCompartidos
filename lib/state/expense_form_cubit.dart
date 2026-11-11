import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/money.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../domain/recurrence.dart';
import '../domain/split.dart';
import '../voice/parsed_expense.dart';

class ExpenseFormState extends Equatable {
  const ExpenseFormState({
    this.loading = true,
    this.detail,
    this.amountText = '',
    this.concept = '',
    this.category = 'Otros',
    this.payerId,
    required this.date,
    this.splitType = SplitType.equal,
    this.selected = const {},
    this.inputs = const {},
    this.inputsVersion = 0,
    this.repeat = false,
    this.frequency = Frequency.monthly,
    this.byVoice = false,
    this.source,
    this.transcript,
    this.splitCountHint,
    this.recurringId,
    this.saving = false,
  });

  final bool loading;
  final GroupDetail? detail;
  final String amountText;
  final String concept;
  final String category;
  final int? payerId;
  final DateTime date;
  final SplitType splitType;

  /// Participantes en partes iguales.
  final Set<int> selected;

  /// Texto escrito por integrante en montos o porcentajes.
  final Map<int, String> inputs;

  /// Cambia cuando la app reescribe [inputs], para refrescar los campos.
  final int inputsVersion;
  final bool repeat;
  final Frequency frequency;
  final bool byVoice;
  final ParseSource? source;
  final String? transcript;
  final int? splitCountHint;
  final int? recurringId;
  final bool saving;

  Currency get currency => detail?.currency ?? currencyOf('COP');
  int? get amount => parseMoney(amountText, currency);

  List<int> get orderedIds => detail?.members.map((m) => m.id).toList() ?? const [];

  Map<int, int> get parsedInputs => {
        for (final e in inputs.entries)
          e.key: ?(splitType == SplitType.percent ? parsePercent(e.value) : parseMoney(e.value, currency)),
      };

  SplitResult get split => computeShares(
        amount: amount ?? 0,
        type: splitType,
        memberIds: splitType == SplitType.equal
            ? orderedIds.where(selected.contains).toList()
            : orderedIds,
        inputs: parsedInputs,
      );

  bool get valid => !loading && (amount ?? 0) > 0 && concept.trim().isNotEmpty && payerId != null && split.ok;

  ExpenseFormState copyWith({
    bool? loading,
    GroupDetail? detail,
    String? amountText,
    String? concept,
    String? category,
    int? payerId,
    DateTime? date,
    SplitType? splitType,
    Set<int>? selected,
    Map<int, String>? inputs,
    int? inputsVersion,
    bool? repeat,
    Frequency? frequency,
    bool? byVoice,
    ParseSource? source,
    String? transcript,
    int? splitCountHint,
    int? recurringId,
    bool? saving,
  }) =>
      ExpenseFormState(
        loading: loading ?? this.loading,
        detail: detail ?? this.detail,
        amountText: amountText ?? this.amountText,
        concept: concept ?? this.concept,
        category: category ?? this.category,
        payerId: payerId ?? this.payerId,
        date: date ?? this.date,
        splitType: splitType ?? this.splitType,
        selected: selected ?? this.selected,
        inputs: inputs ?? this.inputs,
        inputsVersion: inputsVersion ?? this.inputsVersion,
        repeat: repeat ?? this.repeat,
        frequency: frequency ?? this.frequency,
        byVoice: byVoice ?? this.byVoice,
        source: source ?? this.source,
        transcript: transcript ?? this.transcript,
        splitCountHint: splitCountHint ?? this.splitCountHint,
        recurringId: recurringId ?? this.recurringId,
        saving: saving ?? this.saving,
      );

  @override
  List<Object?> get props => [
        loading, identityHashCode(detail), amountText, concept, category, payerId, date, splitType,
        selected.toList()..sort(), inputs.entries.map((e) => (e.key, e.value)).toList(), inputsVersion,
        repeat, frequency, byVoice, source, transcript, splitCountHint, recurringId, saving,
      ];
}

class ExpenseFormCubit extends Cubit<ExpenseFormState> {
  ExpenseFormCubit(this.repo, {required this.groupId, this.expenseId, ParsedExpense? parsed, String? transcript})
      : super(ExpenseFormState(date: dateOnly(DateTime.now()))) {
    _load(parsed, transcript);
  }

  final Repository repo;
  final int groupId;
  final int? expenseId;
  bool get editing => expenseId != null;

  Future<void> _load(ParsedExpense? parsed, String? transcript) async {
    final d = await repo.groupDetail(groupId);
    if (d == null || isClosed) return;
    final cur = d.currency;
    final allIds = d.members.map((m) => m.id).toSet();

    if (expenseId != null) {
      final item = d.expenses.where((e) => e.expense.id == expenseId).firstOrNull;
      if (item == null) return;
      final e = item.expense;
      final type = SplitType.parse(e.splitType);
      emit(state.copyWith(
        loading: false,
        detail: d,
        amountText: moneyInputText(e.amount, cur),
        concept: e.concept,
        category: e.category,
        payerId: e.payerId,
        date: e.date,
        splitType: type,
        selected: item.shares.map((s) => s.memberId).toSet(),
        inputs: {
          for (final s in item.shares)
            if (s.input != null)
              s.memberId: type == SplitType.percent ? formatPercent(s.input!) : moneyInputText(s.input!, cur),
        },
        inputsVersion: 1,
        byVoice: e.byVoice,
        recurringId: e.recurringId,
      ));
      return;
    }

    final participants = parsed?.participantIds?.where(allIds.contains).toSet();
    emit(state.copyWith(
      loading: false,
      detail: d,
      amountText: parsed?.amount == null ? '' : moneyInputText(parsed!.amount!, cur),
      concept: parsed?.concept ?? '',
      category: parsed?.category ?? 'Otros',
      payerId: (parsed?.payerId != null && allIds.contains(parsed!.payerId)) ? parsed.payerId : d.me.id,
      selected: (participants == null || participants.isEmpty) ? allIds : participants,
      byVoice: parsed != null,
      source: parsed?.source,
      transcript: transcript,
      splitCountHint: parsed?.splitCount,
      inputsVersion: 1,
    ));
  }

  void setAmount(String v) => emit(state.copyWith(amountText: v));
  void setConcept(String v) => emit(state.copyWith(concept: v));
  void setCategory(String v) => emit(state.copyWith(category: v));
  void setPayer(int id) => emit(state.copyWith(payerId: id));
  void setDate(DateTime d) => emit(state.copyWith(date: dateOnly(d)));
  void setRepeat(bool v) => emit(state.copyWith(repeat: v));
  void setFrequency(Frequency f) => emit(state.copyWith(frequency: f));

  void toggleMember(int id) {
    final s = {...state.selected};
    if (!s.remove(id)) s.add(id);
    emit(state.copyWith(selected: s));
  }

  void setInput(int id, String v) => emit(state.copyWith(inputs: {...state.inputs, id: v}));

  /// Al cambiar de tipo se precargan valores que ya cuadran (partes iguales).
  void setSplitType(SplitType t) {
    if (t == state.splitType) return;
    final ids = state.orderedIds.where(state.selected.contains).toList();
    final cur = state.currency;
    Map<int, String> inputs = {};
    if (t == SplitType.exact && (state.amount ?? 0) > 0 && ids.isNotEmpty) {
      final eq = computeShares(amount: state.amount!, type: SplitType.equal, memberIds: ids).shares;
      inputs = {for (final e in eq.entries) e.key: moneyInputText(e.value, cur)};
    } else if (t == SplitType.percent && ids.isNotEmpty) {
      final eq = computeShares(amount: 10000, type: SplitType.equal, memberIds: ids).shares;
      inputs = {for (final e in eq.entries) e.key: formatPercent(e.value)};
    } else if (t == SplitType.equal) {
      final withValue = state.parsedInputs.entries.where((e) => e.value > 0).map((e) => e.key).toSet();
      emit(state.copyWith(splitType: t, selected: withValue.isEmpty ? state.selected : withValue));
      return;
    }
    emit(state.copyWith(splitType: t, inputs: inputs, inputsVersion: state.inputsVersion + 1));
  }

  /// Guarda y devuelve el mensaje de confirmación, o null si no es válido.
  Future<String?> save() async {
    final s = state;
    if (!s.valid || s.saving) return null;
    emit(s.copyWith(saving: true));
    final split = s.split;
    final amount = s.amount!;
    final inputs = s.parsedInputs;
    await repo.saveExpense(
      id: expenseId,
      groupId: groupId,
      concept: s.concept.trim(),
      category: s.category,
      amount: amount,
      payerId: s.payerId!,
      date: s.date,
      splitType: s.splitType,
      shares: split.shares,
      inputs: inputs,
      byVoice: s.byVoice,
      recurringId: s.recurringId,
    );
    if (s.repeat && !editing) {
      await repo.addRecurring(
        groupId: groupId,
        concept: s.concept.trim(),
        category: s.category,
        amount: amount,
        payerId: s.payerId!,
        splitType: s.splitType,
        frequency: s.frequency,
        firstDate: s.date,
        memberIds: split.shares.keys.toList(),
        inputs: inputs,
      );
    }
    final values = split.shares.values.toSet();
    final concept = s.concept.trim();
    var msg = editing ? 'Gasto de ${concept.toLowerCase()} actualizado.' : 'Gasto de ${concept.toLowerCase()} guardado.';
    if (values.length == 1 && split.shares.length > 1) {
      msg += ' Cada uno pone ${formatMoney(values.first, s.currency)}.';
    } else if (values.length > 1) {
      final values2 = split.shares.values.toList()..sort();
      if (values2.last - values2.first <= 1) msg += ' Cada uno pone ~${formatMoney(values2.last, s.currency)}.';
    }
    if (s.repeat && !editing) msg += ' Se repetirá cada ${_every(s.frequency)}.';
    return msg;
  }

  String _every(Frequency f) => switch (f) {
        Frequency.weekly => 'semana',
        Frequency.biweekly => 'quince días',
        Frequency.monthly => 'mes',
        Frequency.yearly => 'año',
      };

  Future<void> delete() async {
    if (expenseId != null) await repo.deleteExpense(expenseId!);
  }
}
