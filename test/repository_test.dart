import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_compartidos/data/database.dart';
import 'package:gastos_compartidos/data/models.dart';
import 'package:gastos_compartidos/data/repository.dart';
import 'package:gastos_compartidos/data/sample_data.dart';
import 'package:gastos_compartidos/domain/recurrence.dart';
import 'package:gastos_compartidos/domain/settlement.dart';
import 'package:gastos_compartidos/domain/split.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  late AppDatabase db;
  late Repository repo;

  setUpAll(() => initializeDateFormatting('es_CO'));
  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = Repository(db);
  });
  tearDown(() => db.close());

  test('datos de ejemplo reproducen la liquidación del mockup', () async {
    await repo.saveProfile('Sofía', null);
    await loadSampleData(repo, myName: 'Sofía');
    final groups = await repo.groupsOverview();
    expect(groups.map((g) => g.group.name), ['Apto Laureles', 'Viaje a Guatapé']);
    expect(groups[0].myBalance, 124000);
    expect(groups[1].myBalance, -46000);

    final d = (await repo.groupDetail(groups[0].group.id))!;
    final ids = d.members.map((m) => m.id).toList();
    expect(d.transfers, [
      Transfer(ids[2], ids[0], 90000), // Valentina → Tú
      Transfer(ids[3], ids[1], 44000), // Juan → Mateo
      Transfer(ids[3], ids[0], 34000), // Juan → Tú
    ]);
    expect(d.naiveCount, 6);
  });

  test('pago parcial actualiza saldos y crea aviso', () async {
    await repo.saveProfile('Sofía', null);
    await loadSampleData(repo, myName: 'Sofía');
    final g = (await repo.groupsOverview()).first.group.id;
    var d = (await repo.groupDetail(g))!;
    final me = d.me.id, vale = d.members[2].id;
    await repo.recordPayment(groupId: g, fromId: vale, toId: me, amount: 50000);
    d = (await repo.groupDetail(g))!;
    expect(d.balances[vale], -40000);
    expect(d.myBalance, 74000);
    final notices = await repo.watchNotices().first;
    expect(notices.first.body, contains('Valentina te pagó \$50.000'));
  });

  test('gastos recurrentes se generan una sola vez por fecha', () async {
    final g = await repo.createGroup(
      name: 'Piso',
      type: GroupType.piso,
      currency: 'COP',
      members: const [MemberDraft(name: 'Yo', isMe: true), MemberDraft(name: 'Ana')],
    );
    final d = (await repo.groupDetail(g))!;
    final ids = d.members.map((m) => m.id).toList();
    final start = DateTime(2026, 9, 5);
    await repo.addRecurring(
      groupId: g,
      concept: 'Arriendo',
      category: 'Arriendo',
      amount: 1000000,
      payerId: ids[0],
      splitType: SplitType.equal,
      frequency: Frequency.monthly,
      firstDate: start,
      memberIds: ids,
    );
    final now = DateTime(2026, 11, 10);
    expect(await repo.runRecurring(now), 2); // 5 oct y 5 nov
    expect(await repo.runRecurring(now), 0);
    final after = (await repo.groupDetail(g))!;
    expect(after.expenses.length, 2);
    expect(after.recurrings.single.nextDate, DateTime(2026, 12, 5));
    expect(after.myBalance, 1000000);
  });

  test('no se puede quitar a alguien con gastos', () async {
    final g = await repo.createGroup(
      name: 'Viaje',
      type: GroupType.viaje,
      currency: 'USD',
      members: const [MemberDraft(name: 'Yo', isMe: true), MemberDraft(name: 'Ana'), MemberDraft(name: 'Leo')],
    );
    final d = (await repo.groupDetail(g))!;
    final ids = d.members.map((m) => m.id).toList();
    await repo.saveExpense(
      groupId: g,
      concept: 'Taxi',
      category: 'Transporte',
      amount: 3000,
      payerId: ids[1],
      date: DateTime.now(),
      splitType: SplitType.exact,
      shares: {ids[0]: 1000, ids[1]: 2000},
      inputs: {ids[0]: 1000, ids[1]: 2000},
    );
    final keepMeAndLeo = [
      MemberDraft(id: ids[0], name: 'Yo', isMe: true),
      MemberDraft(id: ids[2], name: 'Leo'),
    ];
    expect(
      () => repo.updateGroup(groupId: g, name: 'Viaje', type: GroupType.viaje, currency: 'USD', members: keepMeAndLeo),
      throwsA(isA<MemberInUseException>()),
    );
    // Leo no tiene gastos: sí se puede quitar.
    await repo.updateGroup(groupId: g, name: 'Viaje', type: GroupType.viaje, currency: 'USD', members: [
      MemberDraft(id: ids[0], name: 'Yo', isMe: true),
      MemberDraft(id: ids[1], name: 'Ana'),
    ]);
    expect((await repo.groupDetail(g))!.members.length, 2);
  });

  test('editar y borrar un gasto recalcula', () async {
    final g = await repo.createGroup(
      name: 'Evento',
      type: GroupType.evento,
      currency: 'COP',
      members: const [MemberDraft(name: 'Yo', isMe: true), MemberDraft(name: 'Ana')],
    );
    final ids = (await repo.groupDetail(g))!.members.map((m) => m.id).toList();
    final id = await repo.saveExpense(
      groupId: g, concept: 'Pizza', category: 'Comida', amount: 40000, payerId: ids[0],
      date: DateTime.now(), splitType: SplitType.equal, shares: {ids[0]: 20000, ids[1]: 20000},
    );
    expect((await repo.groupDetail(g))!.myBalance, 20000);
    await repo.saveExpense(
      id: id, groupId: g, concept: 'Pizza', category: 'Comida', amount: 60000, payerId: ids[0],
      date: DateTime.now(), splitType: SplitType.percent, shares: {ids[0]: 15000, ids[1]: 45000},
      inputs: {ids[0]: 2500, ids[1]: 7500},
    );
    expect((await repo.groupDetail(g))!.myBalance, 45000);
    await repo.deleteExpense(id);
    expect((await repo.groupDetail(g))!.myBalance, 0);
  });
}
