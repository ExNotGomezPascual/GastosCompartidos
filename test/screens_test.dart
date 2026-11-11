import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_compartidos/data/database.dart';
import 'package:gastos_compartidos/data/repository.dart';
import 'package:gastos_compartidos/data/sample_data.dart';
import 'package:gastos_compartidos/main.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

/// Recorre las pantallas principales con los datos de ejemplo en un teléfono
/// de 390 × 844 para detectar errores de diseño (desbordes, excepciones).
void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  setUpAll(() async {
    await initializeDateFormatting('es_CO');
    Intl.defaultLocale = 'es_CO';
  });

  Future<(AppDatabase, Repository)> boot(WidgetTester t, {bool sample = true}) async {
    t.view.physicalSize = const Size(390 * 3, 844 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.reset);
    final db = AppDatabase(NativeDatabase.memory());
    final repo = Repository(db);
    if (sample) {
      await t.runAsync(() async {
        await repo.saveProfile('Sofía', '+57 300 412 8890');
        await loadSampleData(repo, myName: 'Sofía');
      });
    }
    await t.pumpWidget(GastosApp(repo: repo));
    await settle(t);
    return (db, repo);
  }

  testWidgets('bienvenida sin perfil', (t) async {
    final (db, _) = await boot(t, sample: false);
    expect(find.text('Cuentas claras en tu grupo, sin la pena de cobrar'), findsOneWidget);
    expect(find.text('Explorar con datos de ejemplo'), findsOneWidget);
    await close(t, db);
  });

  testWidgets('inicio → grupo → saldar → pago parcial', (t) async {
    final (db, _) = await boot(t);
    expect(find.text('Hola, Sofía'), findsOneWidget);
    expect(find.text('Apto Laureles'), findsOneWidget);
    expect(find.text('Registrar gasto por voz'), findsOneWidget);

    await t.tap(find.text('Apto Laureles'));
    await settle(t);
    expect(find.text('+\$124.000'), findsOneWidget);
    expect(find.text('POR VOZ'), findsWidgets);
    expect(find.text('Gastos recurrentes'), findsOneWidget);

    await t.tap(find.text('Ver quién le debe a quién'));
    await settle(t);
    expect(find.text('3 pagos saldan todo el grupo'), findsOneWidget);
    expect(find.text('Sin simplificar serían 6 transferencias cruzadas.'), findsOneWidget);
    expect(find.text('Valentina te paga'), findsOneWidget);

    await t.tap(find.text('Marcar como pagado').first);
    await settle(t);
    await t.enterText(find.byType(TextField).last, '50000');
    await t.pump();
    await t.tap(find.text('Registrar pago').last);
    await settle(t);
    expect(find.text('Pago registrado'), findsOneWidget);
    expect(find.textContaining('Valentina te pagó \$50.000.'), findsOneWidget);
    expect(find.textContaining('Aún le quedan \$40.000 pendientes.'), findsOneWidget);

    await t.tap(find.text('Volver al grupo'));
    await settle(t);
    await t.scrollUntilVisible(find.text('Pagos registrados'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Pagos registrados'), findsOneWidget);
    await close(t, db);
  });

  testWidgets('formulario de gasto: tipos de división y repetir', (t) async {
    final (db, _) = await boot(t);
    await t.tap(find.text('Apto Laureles'));
    await settle(t);
    await t.tap(find.text('+ Agregar'));
    await settle(t);
    await t.tap(find.text('Escribirlo'));
    await settle(t);
    expect(find.text('Nuevo gasto'), findsOneWidget);
    await t.enterText(find.byType(TextFormField).first, '40000');
    await t.pump();
    expect(find.text('Partes iguales · \$10.000 c/u'), findsOneWidget);

    await t.tap(find.text('Porcentaje'));
    await settle(t);
    expect(find.text('Suma 100 %'), findsOneWidget);
    await t.tap(find.text('Montos'));
    await settle(t);
    expect(find.text('Cuadra con el total'), findsOneWidget);

    await t.scrollUntilVisible(find.text('Repetir este gasto'), 200, scrollable: find.byType(Scrollable).first);
    await t.tap(find.byType(Switch));
    await settle(t);
    expect(find.text('Quincenal'), findsOneWidget);
    await close(t, db);
  });

  testWidgets('pestañas grupos, saldar, perfil y nuevo grupo', (t) async {
    final (db, _) = await boot(t);
    await t.tap(find.text('Grupos').last);
    await settle(t);
    expect(find.text('Viaje a Guatapé'), findsOneWidget);
    await t.tap(find.text('Saldar').last);
    await settle(t);
    expect(find.text('Saldar cuentas'), findsOneWidget);
    await t.tap(find.text('Perfil').last);
    await settle(t);
    expect(find.text('Cargar datos de ejemplo'), findsOneWidget);
    await t.tap(find.text('Inicio').last);
    await settle(t);
    await t.tap(find.text('+ Nuevo grupo'));
    await settle(t);
    expect(find.text('Invitar por WhatsApp o enlace'), findsOneWidget);
    expect(find.text('Administrador(a)'), findsOneWidget);
    await close(t, db);
  });

  testWidgets('pantalla de voz en reposo', (t) async {
    final (db, _) = await boot(t);
    await t.ensureVisible(find.text('Registrar gasto por voz'));
    await t.pump();
    await t.tap(find.text('Registrar gasto por voz'));
    await settle(t);
    expect(find.text('Toca el micrófono y di el gasto'), findsOneWidget);
    expect(find.text('Prefiero escribirlo'), findsOneWidget);
    await close(t, db);
  });
}

/// Deja correr las consultas de Drift (asíncronas reales) y los cuadros.
Future<void> settle(WidgetTester t) async {
  for (var i = 0; i < 6; i++) {
    await t.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 30)));
    await t.pump(const Duration(milliseconds: 100));
  }
  await t.pump(const Duration(milliseconds: 400));
}

/// Desmonta la app. La base en memoria no se cierra aquí: cerrarla mientras
/// una consulta del árbol desmontado sigue en la zona de prueba bloquea el test.
Future<void> close(WidgetTester t, AppDatabase db) async {
  await t.pumpWidget(const SizedBox());
  await settle(t);
}
