import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

/// Deja solo dígitos y antepone 57 a celulares colombianos de 10 dígitos.
String? waNumber(String? phone) {
  if (phone == null) return null;
  var d = phone.replaceAll(RegExp(r'\D'), '');
  if (d.isEmpty) return null;
  if (d.startsWith('00')) d = d.substring(2);
  if (d.length == 10 && d.startsWith('3')) d = '57$d';
  return d.length >= 8 ? d : null;
}

/// Abre WhatsApp con el mensaje listo si hay número; si no (o falla),
/// abre el menú de compartir de Android. Devuelve true si se abrió algo.
Future<bool> sendMessage({String? phone, required String text, String? subject}) async {
  final n = waNumber(phone);
  if (n != null) {
    final uri = Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(text)}');
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return true;
    } catch (_) {
      // Sigue con el menú de compartir.
    }
  }
  final r = await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  return r.status != ShareResultStatus.unavailable;
}

Future<void> shareText(String text, {String? subject}) =>
    SharePlus.instance.share(ShareParams(text: text, subject: subject));
