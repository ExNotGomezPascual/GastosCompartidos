import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/money.dart';
import '../domain/recurrence.dart';
import '../domain/settlement.dart';
import '../domain/split.dart';
import 'database.dart';
import 'models.dart';

class MemberInUseException implements Exception {
  MemberInUseException(this.name);
  final String name;
  @override
  String toString() =>
      '$name tiene gastos o pagos en el grupo. Elimina esos registros antes de quitarlo.';
}

class Repository {
  Repository(this.db);
  final AppDatabase db;

  /// Recalcula [load] cada vez que cambia cualquier tabla.
  Stream<T> _watch<T>(Future<T> Function() load) async* {
    yield await load();
    await for (final _ in db.tableUpdates()) {
      yield await load();
    }
  }

  // ---------------------------------------------------------------- Perfil

  Future<Profile?> profile() =>
      (db.select(db.profiles)..where((p) => p.id.equals(1))).getSingleOrNull();

  Stream<Profile?> watchProfile() =>
      (db.select(db.profiles)..where((p) => p.id.equals(1))).watchSingleOrNull();

  Future<void> saveProfile(String name, String? phone) async {
    await db.transaction(() async {
      await db.into(db.profiles).insertOnConflictUpdate(
          ProfilesCompanion.insert(id: const Value(1), name: name, phone: Value(phone)));
      await (db.update(db.members)..where((m) => m.isMe.equals(true)))
          .write(MembersCompanion(name: Value(name), phone: Value(phone)));
    });
  }

  // ---------------------------------------------------------------- Grupos

  Future<List<GroupOverview>> groupsOverview() async {
    final groups = await (db.select(db.expenseGroups)
          ..orderBy([(g) => OrderingTerm.asc(g.createdAt), (g) => OrderingTerm.asc(g.id)]))
        .get();
    final out = <GroupOverview>[];
    for (final g in groups) {
      final d = await groupDetail(g.id);
      if (d != null) out.add(GroupOverview(g, d.members.length, d.myBalance));
    }
    return out;
  }

  Stream<List<GroupOverview>> watchGroupsOverview() => _watch(groupsOverview);

  Future<GroupDetail?> groupDetail(int groupId) async {
    final g = await (db.select(db.expenseGroups)..where((x) => x.id.equals(groupId)))
        .getSingleOrNull();
    if (g == null) return null;
    final members = await (db.select(db.members)
          ..where((m) => m.groupId.equals(groupId))
          ..orderBy([(m) => OrderingTerm.desc(m.isMe), (m) => OrderingTerm.asc(m.id)]))
        .get();
    final expenses = await (db.select(db.expenses)
          ..where((e) => e.groupId.equals(groupId))
          ..orderBy([(e) => OrderingTerm.desc(e.date), (e) => OrderingTerm.desc(e.id)]))
        .get();
    final ids = expenses.map((e) => e.id).toList();
    final shares = ids.isEmpty
        ? <ExpenseShare>[]
        : await (db.select(db.expenseShares)..where((s) => s.expenseId.isIn(ids))).get();
    final payments = await (db.select(db.payments)
          ..where((p) => p.groupId.equals(groupId))
          ..orderBy([(p) => OrderingTerm.desc(p.date), (p) => OrderingTerm.desc(p.id)]))
        .get();
    final recurrings =
        await (db.select(db.recurrings)..where((r) => r.groupId.equals(groupId))).get();

    final items = [
      for (final e in expenses)
        ExpenseItem(e, shares.where((s) => s.expenseId == e.id).toList()),
    ];
    final ledger = [
      for (final i in items)
        LedgerExpense(i.expense.payerId, i.expense.amount,
            {for (final s in i.shares) s.memberId: s.amount}),
    ];
    final ledgerPay = [for (final p in payments) LedgerPayment(p.fromId, p.toId, p.amount)];
    final memberIds = members.map((m) => m.id).toList();
    final balances = computeBalances(memberIds, ledger, ledgerPay);
    return GroupDetail(
      group: g,
      members: members,
      expenses: items,
      payments: payments,
      recurrings: recurrings,
      balances: balances,
      transfers: minimalTransfers(balances, order: memberIds),
      naiveCount: naiveTransferCount(ledger, ledgerPay),
    );
  }

  Stream<GroupDetail?> watchGroupDetail(int groupId) => _watch(() => groupDetail(groupId));

  Future<int> createGroup({
    required String name,
    required GroupType type,
    required String currency,
    required List<MemberDraft> members,
  }) {
    return db.transaction(() async {
      final id = await db.into(db.expenseGroups).insert(ExpenseGroupsCompanion.insert(
            name: name,
            type: type.name,
            currency: currency,
            createdAt: DateTime.now(),
          ));
      var color = 1;
      for (final m in members) {
        await db.into(db.members).insert(MembersCompanion.insert(
              groupId: id,
              name: m.name,
              phone: Value(m.phone),
              isMe: Value(m.isMe),
              invited: Value(m.invited),
              colorIndex: m.isMe ? 0 : color++,
            ));
      }
      return id;
    });
  }

  Future<void> updateGroup({
    required int groupId,
    required String name,
    required GroupType type,
    required String currency,
    required List<MemberDraft> members,
  }) async {
    final detail = await groupDetail(groupId);
    if (detail == null) return;
    final keep = members.map((m) => m.id).whereType<int>().toSet();
    final involved = detail.involvedMemberIds;
    for (final m in detail.members) {
      if (!keep.contains(m.id) && involved.contains(m.id)) throw MemberInUseException(m.name);
    }
    await db.transaction(() async {
      await (db.update(db.expenseGroups)..where((g) => g.id.equals(groupId))).write(
          ExpenseGroupsCompanion(name: Value(name), type: Value(type.name), currency: Value(currency)));
      for (final m in detail.members) {
        if (!keep.contains(m.id)) {
          await (db.delete(db.members)..where((x) => x.id.equals(m.id))).go();
        }
      }
      var color = detail.members.fold<int>(0, (c, m) => m.colorIndex > c ? m.colorIndex : c) + 1;
      for (final m in members) {
        if (m.id != null) {
          await (db.update(db.members)..where((x) => x.id.equals(m.id!))).write(MembersCompanion(
              name: Value(m.name), phone: Value(m.phone), invited: Value(m.invited)));
        } else {
          await db.into(db.members).insert(MembersCompanion.insert(
                groupId: groupId,
                name: m.name,
                phone: Value(m.phone),
                invited: Value(m.invited),
                colorIndex: color++,
              ));
        }
      }
    });
  }

  Future<void> deleteGroup(int groupId) =>
      (db.delete(db.expenseGroups)..where((g) => g.id.equals(groupId))).go();

  Future<void> markInvited(int memberId) =>
      (db.update(db.members)..where((m) => m.id.equals(memberId)))
          .write(const MembersCompanion(invited: Value(true)));

  // ---------------------------------------------------------------- Gastos

  Future<int> saveExpense({
    int? id,
    required int groupId,
    required String concept,
    required String category,
    required int amount,
    required int payerId,
    required DateTime date,
    required SplitType splitType,
    required Map<int, int> shares,
    Map<int, int> inputs = const {},
    bool byVoice = false,
    int? recurringId,
  }) {
    return db.transaction(() async {
      final companion = ExpensesCompanion(
        groupId: Value(groupId),
        concept: Value(concept),
        category: Value(category),
        amount: Value(amount),
        payerId: Value(payerId),
        date: Value(date),
        splitType: Value(splitType.name),
        byVoice: Value(byVoice),
        recurringId: Value(recurringId),
      );
      int expenseId;
      if (id == null) {
        expenseId = await db
            .into(db.expenses)
            .insert(companion.copyWith(createdAt: Value(DateTime.now())));
      } else {
        expenseId = id;
        await (db.update(db.expenses)..where((e) => e.id.equals(id))).write(companion);
        await (db.delete(db.expenseShares)..where((s) => s.expenseId.equals(id))).go();
      }
      for (final e in shares.entries) {
        await db.into(db.expenseShares).insert(ExpenseSharesCompanion.insert(
              expenseId: expenseId,
              memberId: e.key,
              amount: e.value,
              input: Value(splitType == SplitType.equal ? null : inputs[e.key]),
            ));
      }
      return expenseId;
    });
  }

  Future<void> deleteExpense(int id) =>
      (db.delete(db.expenses)..where((e) => e.id.equals(id))).go();

  // ---------------------------------------------------------------- Recurrentes

  Future<int> addRecurring({
    required int groupId,
    required String concept,
    required String category,
    required int amount,
    required int payerId,
    required SplitType splitType,
    required Frequency frequency,
    required DateTime firstDate,
    required List<int> memberIds,
    Map<int, int> inputs = const {},
  }) {
    return db.into(db.recurrings).insert(RecurringsCompanion.insert(
          groupId: groupId,
          concept: concept,
          category: category,
          amount: amount,
          payerId: payerId,
          splitType: splitType.name,
          frequency: frequency.name,
          nextDate: nextOccurrence(firstDate, frequency, firstDate.day),
          anchorDay: firstDate.day,
          sharesJson: jsonEncode([
            for (final m in memberIds) {'m': m, 'i': inputs[m]},
          ]),
        ));
  }

  Future<void> deleteRecurring(int id) =>
      (db.delete(db.recurrings)..where((r) => r.id.equals(id))).go();

  /// Crea los gastos recurrentes que ya vencieron. Devuelve cuántos creó.
  Future<int> runRecurring(DateTime now) async {
    final all = await db.select(db.recurrings).get();
    var created = 0;
    for (final r in all) {
      final freq = Frequency.parse(r.frequency);
      final dates = dueDates(r.nextDate, freq, r.anchorDay, now);
      if (dates.isEmpty) continue;
      final members = await (db.select(db.members)..where((m) => m.groupId.equals(r.groupId))).get();
      final existing = members.map((m) => m.id).toSet();
      final raw = (jsonDecode(r.sharesJson) as List).cast<Map<String, dynamic>>();
      final ids = [for (final s in raw) if (existing.contains(s['m'])) s['m'] as int];
      final inputs = {for (final s in raw) if (s['i'] != null) s['m'] as int: s['i'] as int};
      final type = SplitType.parse(r.splitType);
      final split = computeShares(amount: r.amount, type: type, memberIds: ids, inputs: inputs);
      final group = await (db.select(db.expenseGroups)..where((g) => g.id.equals(r.groupId)))
          .getSingleOrNull();
      if (!split.ok || group == null || !existing.contains(r.payerId)) continue;
      for (final d in dates) {
        await saveExpense(
          groupId: r.groupId,
          concept: r.concept,
          category: r.category,
          amount: r.amount,
          payerId: r.payerId,
          date: d,
          splitType: type,
          shares: split.shares,
          inputs: inputs,
          recurringId: r.id,
        );
        created++;
      }
      final next = nextOccurrence(dates.last, freq, r.anchorDay);
      await (db.update(db.recurrings)..where((x) => x.id.equals(r.id)))
          .write(RecurringsCompanion(nextDate: Value(next)));
      final c = currencyOf(group.currency);
      await addNotice(
        groupId: r.groupId,
        kind: 'recurrente',
        title: 'Gasto recurrente registrado',
        body: dates.length == 1
            ? '${r.concept} por ${formatMoney(r.amount, c)} en ${group.name}.'
            : '${r.concept} se registró ${dates.length} veces en ${group.name}.',
      );
    }
    return created;
  }

  // ---------------------------------------------------------------- Pagos

  Future<void> recordPayment({
    required int groupId,
    required int fromId,
    required int toId,
    required int amount,
  }) async {
    await db.into(db.payments).insert(PaymentsCompanion.insert(
          groupId: groupId,
          fromId: fromId,
          toId: toId,
          amount: amount,
          date: DateTime.now(),
        ));
    final d = await groupDetail(groupId);
    if (d == null) return;
    final from = d.member(fromId), to = d.member(toId);
    final money = formatMoney(amount, d.currency);
    final body = from?.isMe == true
        ? 'Le pagaste $money a ${to?.name} en ${d.group.name}.'
        : to?.isMe == true
            ? '${from?.name} te pagó $money en ${d.group.name}.'
            : '${from?.name} le pagó $money a ${to?.name} en ${d.group.name}.';
    await addNotice(groupId: groupId, kind: 'pago', title: 'Pago registrado', body: body);
  }

  // ---------------------------------------------------------------- Avisos

  Stream<List<AppNotice>> watchNotices() => (db.select(db.appNotices)
        ..orderBy([(n) => OrderingTerm.desc(n.createdAt), (n) => OrderingTerm.desc(n.id)]))
      .watch();

  Future<void> addNotice({
    int? groupId,
    required String kind,
    required String title,
    required String body,
  }) =>
      db.into(db.appNotices).insert(AppNoticesCompanion.insert(
            groupId: Value(groupId),
            kind: kind,
            title: title,
            body: body,
            createdAt: DateTime.now(),
          ));

  Future<void> markNoticesRead() =>
      db.update(db.appNotices).write(const AppNoticesCompanion(read: Value(true)));

  /// Una vez al día avisa de lo que te deben en cada grupo.
  Future<void> dailyChecks(DateTime now) async {
    final today = dateOnly(now);
    for (final g in await groupsOverview()) {
      if (g.myBalance <= 0) continue;
      final already = await (db.select(db.appNotices)
            ..where((n) =>
                n.kind.equals('cobro') &
                n.groupId.equals(g.group.id) &
                n.createdAt.isBiggerOrEqualValue(today)))
          .get();
      if (already.isNotEmpty) continue;
      await addNotice(
        groupId: g.group.id,
        kind: 'cobro',
        title: 'Tienes ${formatMoney(g.myBalance, g.currency)} por cobrar',
        body: 'En ${g.group.name}. Desde Saldar puedes enviar el recordatorio.',
      );
    }
  }

  // ---------------------------------------------------------------- Datos

  Future<void> wipeAll() => db.transaction(() async {
        await db.delete(db.appNotices).go();
        await db.delete(db.payments).go();
        await db.delete(db.expenseShares).go();
        await db.delete(db.expenses).go();
        await db.delete(db.recurrings).go();
        await db.delete(db.members).go();
        await db.delete(db.expenseGroups).go();
        await db.delete(db.profiles).go();
      });
}
