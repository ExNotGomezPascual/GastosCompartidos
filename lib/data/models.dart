import '../core/money.dart';
import '../domain/settlement.dart';
import 'database.dart';

enum GroupType {
  piso('Piso', 'Piso compartido'),
  viaje('Viaje', 'Viaje'),
  evento('Evento', 'Evento');

  const GroupType(this.label, this.longLabel);
  final String label;
  final String longLabel;

  static GroupType parse(String s) =>
      GroupType.values.firstWhere((t) => t.name == s, orElse: () => GroupType.piso);

  String get note => switch (this) {
        GroupType.piso => 'Incluye gastos recurrentes del mes: alquiler, servicios y mercado.',
        GroupType.viaje => 'Pensado para compras puntuales; se cierra al terminar el viaje.',
        GroupType.evento => 'Un solo cierre de cuentas al final del evento.',
      };
}

class GroupOverview {
  const GroupOverview(this.group, this.memberCount, this.myBalance);
  final ExpenseGroup group;
  final int memberCount;
  final int myBalance;
  Currency get currency => currencyOf(group.currency);
  GroupType get type => GroupType.parse(group.type);
}

class ExpenseItem {
  const ExpenseItem(this.expense, this.shares);
  final Expense expense;
  final List<ExpenseShare> shares;
}

class GroupDetail {
  GroupDetail({
    required this.group,
    required this.members,
    required this.expenses,
    required this.payments,
    required this.recurrings,
    required this.balances,
    required this.transfers,
    required this.naiveCount,
  });

  final ExpenseGroup group;
  final List<Member> members;
  final List<ExpenseItem> expenses;
  final List<Payment> payments;
  final List<Recurring> recurrings;
  final Map<int, int> balances;
  final List<Transfer> transfers;
  final int naiveCount;

  Currency get currency => currencyOf(group.currency);
  GroupType get type => GroupType.parse(group.type);
  Member get me => members.firstWhere((m) => m.isMe, orElse: () => members.first);
  int get myBalance => balances[me.id] ?? 0;

  Member? member(int id) => members.where((m) => m.id == id).firstOrNull;

  /// "Tú" para el usuario, el nombre para los demás.
  String nameOf(int id) {
    final m = member(id);
    if (m == null) return 'Alguien';
    return m.isMe ? 'Tú' : m.name;
  }

  int monthTotal(DateTime now) => expenses
      .where((e) => e.expense.date.year == now.year && e.expense.date.month == now.month)
      .fold(0, (s, e) => s + e.expense.amount);

  /// Integrantes que tienen gastos, partes o pagos (no se pueden eliminar).
  Set<int> get involvedMemberIds => {
        for (final e in expenses) ...[e.expense.payerId, ...e.shares.map((s) => s.memberId)],
        for (final p in payments) ...[p.fromId, p.toId],
        for (final r in recurrings) r.payerId,
      };
}

class MemberDraft {
  const MemberDraft({this.id, required this.name, this.phone, this.isMe = false, this.invited = false, this.colorIndex});
  final int? id;
  final String name;
  final String? phone;
  final bool isMe;
  final bool invited;
  final int? colorIndex;

  MemberDraft copyWith({String? name, String? phone, bool? invited}) => MemberDraft(
        id: id,
        name: name ?? this.name,
        phone: phone ?? this.phone,
        isMe: isMe,
        invited: invited ?? this.invited,
        colorIndex: colorIndex,
      );
}
