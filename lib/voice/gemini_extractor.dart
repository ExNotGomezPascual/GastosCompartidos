import 'dart:convert';

import 'package:http/http.dart' as http;

import '../domain/categories.dart';
import 'parsed_expense.dart';

/// Envía solo el texto transcrito a Gemini y pide los campos del gasto en JSON.
class GeminiExtractor {
  GeminiExtractor({
    required this.apiKey,
    required this.model,
    http.Client? client,
    this.timeout = const Duration(seconds: 10),
  }) : _client = client ?? http.Client();

  final String apiKey;
  final String model;
  final Duration timeout;
  final http.Client _client;

  Future<ParsedExpense?> extract({
    required String text,
    required List<VoiceMember> members,
    required String currencyName,
    required int currencyFactor,
  }) async {
    final names = members.map((m) => m.isMe ? 'Tú (${m.name})' : m.name).join(', ');
    final prompt = '''
Eres un asistente que registra gastos compartidos de un grupo en Colombia.
Extrae los datos de la frase dictada por el usuario (quien habla es "Tú").
Integrantes del grupo: $names.
Moneda del grupo: $currencyName. Interpreta "mil", "lucas" (= mil) y "palos" (= millón) como en Colombia.
Reglas:
- "monto": número en la moneda del grupo, sin símbolos (ej. 28000). null si no se dijo.
- "concepto": 1 a 3 palabras que describan el gasto (ej. "Gas", "Mercado D1").
- "categoria": una de: ${categories.join(', ')}.
- "pagador": nombre exacto de la lista, o "Tú" si habla el usuario ("pagué", "compré").
- "participantes": nombres exactos de quienes comparten el gasto; usa "Tú" para el usuario. Lista vacía si se dijo "todos" o no se dijo.
- "todos": true si el gasto es para todo el grupo.
- "personas": cuántas personas se dijo (ej. "entre los cuatro" = 4), o null.
Frase: "$text"''';

    final body = {
      'contents': [
        {
          'role': 'user',
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'temperature': 0,
        'responseMimeType': 'application/json',
        'responseSchema': {
          'type': 'OBJECT',
          'properties': {
            'monto': {'type': 'NUMBER', 'nullable': true},
            'concepto': {'type': 'STRING'},
            'categoria': {'type': 'STRING', 'enum': categories},
            'pagador': {'type': 'STRING'},
            'participantes': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
            'todos': {'type': 'BOOLEAN'},
            'personas': {'type': 'INTEGER', 'nullable': true},
          },
          'required': ['concepto', 'categoria', 'pagador', 'participantes', 'todos'],
        },
      },
    };

    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
    );
    final res = await _client
        .post(
          uri,
          headers: {'Content-Type': 'application/json', 'x-goog-api-key': apiKey},
          body: jsonEncode(body),
        )
        .timeout(timeout);
    if (res.statusCode != 200) {
      throw GeminiException('Gemini respondió ${res.statusCode}');
    }
    final decoded = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final textOut = (((decoded['candidates'] as List?)?.firstOrNull
            as Map?)?['content']?['parts'] as List?)
        ?.firstOrNull?['text'] as String?;
    if (textOut == null) throw GeminiException('Respuesta vacía de Gemini');
    return fromJson(jsonDecode(textOut) as Map<String, dynamic>, members, currencyFactor);
  }

  /// Convierte la respuesta JSON de Gemini en un [ParsedExpense].
  static ParsedExpense fromJson(
      Map<String, dynamic> j, List<VoiceMember> members, int currencyFactor) {
    int? idFor(String? name) {
      if (name == null) return null;
      final n = normalize(name.trim());
      if (n.isEmpty) return null;
      if (n == 'tu' || n == 'yo' || n.startsWith('tu (')) {
        return members.where((m) => m.isMe).firstOrNull?.id;
      }
      for (final m in members) {
        final mn = normalize(m.name);
        if (mn == n || mn.split(' ').first == n.split(' ').first) return m.id;
      }
      return null;
    }

    final monto = j['monto'];
    final amount = monto is num && monto > 0 ? (monto * currencyFactor).round() : null;
    final all = j['todos'] == true;
    final parts = <int>{
      for (final p in (j['participantes'] as List? ?? const []))
        ?idFor(p?.toString()),
    }.toList();
    final personas = j['personas'] is num ? (j['personas'] as num).toInt() : null;
    final cat = j['categoria'] as String?;
    final concept = (j['concepto'] as String?)?.trim();
    return ParsedExpense(
      amount: amount,
      concept: (concept == null || concept.isEmpty) ? null : concept,
      category: categories.contains(cat) ? cat : null,
      payerId: idFor(j['pagador']?.toString()),
      participantIds: all || parts.isEmpty
          ? (personas != null && personas < members.length ? null : members.map((m) => m.id).toList())
          : parts,
      splitCount: personas,
      source: ParseSource.gemini,
    );
  }
}

class GeminiException implements Exception {
  GeminiException(this.message);
  final String message;
  @override
  String toString() => message;
}
