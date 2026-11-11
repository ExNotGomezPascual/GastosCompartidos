import '../domain/recurrence.dart';
import '../domain/split.dart';
import 'models.dart';
import 'repository.dart';

/// Carga los grupos del mockup: "Apto Laureles" (Tú, Mateo, Valentina, Juan)
/// y "Viaje a Guatapé" (6 personas, debes $46.000).
Future<void> loadSampleData(Repository repo, {required String myName, String? myPhone}) async {
  final today = dateOnly(DateTime.now());
  DateTime ago(int days) => today.subtract(Duration(days: days));

  final apto = await repo.createGroup(
    name: 'Apto Laureles',
    type: GroupType.piso,
    currency: 'COP',
    members: [
      MemberDraft(name: myName, phone: myPhone, isMe: true),
      const MemberDraft(name: 'Mateo', invited: true),
      const MemberDraft(name: 'Valentina', invited: true),
      const MemberDraft(name: 'Juan', invited: true),
    ],
  );
  final a = (await repo.groupDetail(apto))!;
  final ids = a.members.map((m) => m.id).toList();
  final me = ids[0], mateo = ids[1], vale = ids[2], juan = ids[3];

  Future<void> equal(int group, List<int> people, String concept, String cat, int amount,
      int payer, DateTime date, {bool voice = false}) async {
    final s = computeShares(amount: amount, type: SplitType.equal, memberIds: people);
    await repo.saveExpense(
      groupId: group,
      concept: concept,
      category: cat,
      amount: amount,
      payerId: payer,
      date: date,
      splitType: SplitType.equal,
      shares: s.shares,
      byVoice: voice,
    );
  }

  await equal(apto, ids, 'Servicios EPM', 'Servicios', 236000, me, ago(16));
  await equal(apto, ids, 'Internet', 'Servicios', 50000, vale, ago(13), voice: true);
  await equal(apto, ids, 'Mercado D1', 'Mercado', 184000, mateo, ago(11));
  await equal(apto, ids, 'Aseo y cocina', 'Aseo', 62000, juan, ago(9));
  await equal(apto, ids, 'Gas', 'Servicios', 28000, me, today, voice: true);
  await repo.addRecurring(
    groupId: apto,
    concept: 'Internet',
    category: 'Servicios',
    amount: 50000,
    payerId: vale,
    splitType: SplitType.equal,
    frequency: Frequency.monthly,
    firstDate: ago(13),
    memberIds: ids,
  );

  final viaje = await repo.createGroup(
    name: 'Viaje a Guatapé',
    type: GroupType.viaje,
    currency: 'COP',
    members: [
      MemberDraft(name: myName, phone: myPhone, isMe: true),
      const MemberDraft(name: 'Laura', invited: true),
      const MemberDraft(name: 'Andrés', invited: true),
      const MemberDraft(name: 'Camila', invited: true),
      const MemberDraft(name: 'Mateo', invited: true),
      const MemberDraft(name: 'Valentina'),
    ],
  );
  final v = (await repo.groupDetail(viaje))!;
  final vIds = v.members.map((m) => m.id).toList();
  await equal(viaje, vIds, 'Alojamiento', 'Alojamiento', 420000, vIds[1], ago(20));
  await equal(viaje, vIds, 'Lancha', 'Transporte', 126000, vIds[2], ago(19));
  await equal(viaje, vIds, 'Almuerzo', 'Comida', 54000, vIds[0], ago(19),
      voice: true);
}
