import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

part 'database.g.dart';

/// Perfil del único usuario local (fila con id = 1).
class Profiles extends Table {
  IntColumn get id => integer()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ExpenseGroups extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();

  /// piso | viaje | evento
  TextColumn get type => text()();

  /// Código ISO de la moneda (COP, USD...).
  TextColumn get currency => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class Members extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId =>
      integer().references(ExpenseGroups, #id, onDelete: KeyAction.cascade)();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
  BoolColumn get isMe => boolean().withDefault(const Constant(false))();
  IntColumn get colorIndex => integer()();
  BoolColumn get invited => boolean().withDefault(const Constant(false))();
}

class Expenses extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId =>
      integer().references(ExpenseGroups, #id, onDelete: KeyAction.cascade)();
  TextColumn get concept => text()();
  TextColumn get category => text()();

  /// Monto en unidades mínimas de la moneda (centavos o pesos).
  IntColumn get amount => integer()();
  IntColumn get payerId => integer().references(Members, #id)();
  DateTimeColumn get date => dateTime()();

  /// equal | exact | percent
  TextColumn get splitType => text()();
  BoolColumn get byVoice => boolean().withDefault(const Constant(false))();
  IntColumn get recurringId => integer().nullable()();
  DateTimeColumn get createdAt => dateTime()();
}

class ExpenseShares extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get expenseId =>
      integer().references(Expenses, #id, onDelete: KeyAction.cascade)();
  IntColumn get memberId => integer().references(Members, #id)();

  /// Parte que le toca al integrante, en unidades mínimas.
  IntColumn get amount => integer()();

  /// Valor que escribió el usuario: monto exacto o porcentaje en puntos
  /// básicos (100 % = 10000). Nulo en partes iguales.
  IntColumn get input => integer().nullable()();
}

class Recurrings extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId =>
      integer().references(ExpenseGroups, #id, onDelete: KeyAction.cascade)();
  TextColumn get concept => text()();
  TextColumn get category => text()();
  IntColumn get amount => integer()();
  IntColumn get payerId => integer()();
  TextColumn get splitType => text()();

  /// weekly | biweekly | monthly | yearly
  TextColumn get frequency => text()();
  DateTimeColumn get nextDate => dateTime()();

  /// Día del mes original, para que los mensuales no se corran (31 → 28 → 28).
  IntColumn get anchorDay => integer()();

  /// JSON: [{"m": memberId, "i": input|null}]
  TextColumn get sharesJson => text()();
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId =>
      integer().references(ExpenseGroups, #id, onDelete: KeyAction.cascade)();
  IntColumn get fromId => integer().references(Members, #id)();
  IntColumn get toId => integer().references(Members, #id)();
  IntColumn get amount => integer()();
  DateTimeColumn get date => dateTime()();
}

class AppNotices extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get groupId => integer().nullable()();
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get body => text()();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get read => boolean().withDefault(const Constant(false))();
}

@DriftDatabase(tables: [
  Profiles,
  ExpenseGroups,
  Members,
  Expenses,
  ExpenseShares,
  Recurrings,
  Payments,
  AppNotices,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor])
      : super(executor ?? driftDatabase(name: 'gastos_compartidos'));

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );
}
