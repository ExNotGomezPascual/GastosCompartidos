import 'package:flutter_test/flutter_test.dart';
import 'package:gastos_compartidos/voice/gemini_extractor.dart';
import 'package:gastos_compartidos/voice/parsed_expense.dart';
import 'package:gastos_compartidos/voice/rule_parser.dart';

void main() {
  const members = [
    VoiceMember(1, 'Sofía', isMe: true),
    VoiceMember(2, 'Mateo'),
    VoiceMember(3, 'Valentina'),
    VoiceMember(4, 'Juan'),
  ];
  final parser = RuleParser();
  ParsedExpense p(String s) => parser.parse(s, members, 1);

  test('frase del mockup', () {
    final r = p('Pagué 28.000 de gas para todos en el apto');
    expect(r.amount, 28000);
    expect(r.concept, 'Gas');
    expect(r.category, 'Servicios');
    expect(r.payerId, 1);
    expect(r.participantIds, [1, 2, 3, 4]);
  });

  test('"mil" y número de personas', () {
    final r = p('pagué 120 mil de mercado entre los cuatro');
    expect(r.amount, 120000);
    expect(r.concept, 'Mercado');
    expect(r.category, 'Mercado');
    expect(r.splitCount, 4);
    expect(r.participantIds, [1, 2, 3, 4]);
  });

  test('otro integrante pagó, con "lucas"', () {
    final r = p('Juan pagó 50 lucas del internet');
    expect(r.amount, 50000);
    expect(r.payerId, 4);
    expect(r.concept, 'Internet');
  });

  test('nombres de participantes con "con"', () {
    final r = p('Pagué el almuerzo, 45.000, con Mateo');
    expect(r.amount, 45000);
    expect(r.concept, 'Almuerzo');
    expect(r.category, 'Comida');
    expect(r.participantIds, [1, 2]);
  });

  test('números en letras', () {
    expect(p('pagué ciento veinte mil pesos de arriendo').amount, 120000);
    expect(p('Mateo pagó un millón doscientos mil del hotel').amount, 1200000);
    expect(p('compré veintiocho mil quinientos de aseo').amount, 28500);
  });

  test('formatos que devuelve el dictado de Android', () {
    expect(p(r'pagué $28,000 de gas').amount, 28000);
    expect(p('pagué 28 000 de gas').amount, 28000);
  });

  test('menos personas que el grupo', () {
    final r = p('pagué 30 mil de taxi entre dos');
    expect(r.splitCount, 2);
    expect(r.participantIds!.length, 2);
    expect(r.participantIds!.first, 1);
  });

  test('sin monto deja el campo vacío', () {
    final r = p('pagué el mercado');
    expect(r.amount, isNull);
    expect(r.concept, 'Mercado');
  });

  test('respuesta JSON de Gemini se mapea a integrantes', () {
    final r = GeminiExtractor.fromJson({
      'monto': 62000,
      'concepto': 'Aseo y cocina',
      'categoria': 'Aseo',
      'pagador': 'Juan',
      'participantes': ['Tú', 'Juan'],
      'todos': false,
      'personas': null,
    }, members, 1);
    expect(r.amount, 62000);
    expect(r.payerId, 4);
    expect(r.participantIds, [1, 4]);
    expect(r.source, ParseSource.gemini);
  });
}
