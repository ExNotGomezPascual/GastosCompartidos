import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/config.dart';
import '../state/app_cubits.dart';
import '../ui/icons.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _edit(BuildContext context) async {
    final cubit = context.read<AppCubit>();
    final p = cubit.state.profile;
    final name = TextEditingController(text: p?.name ?? '');
    final phone = TextEditingController(text: (p?.phone ?? '').replaceFirst('+57 ', ''));
    final ok = await showAppSheet<bool>(
      context,
      title: 'Editar perfil',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Nombre', style: sans(14, color: AppColors.muted)),
        const SizedBox(height: 8),
        TextField(controller: name, textCapitalization: TextCapitalization.words, style: bold(17)),
        const SizedBox(height: 14),
        Text('Celular (opcional)', style: sans(14, color: AppColors.muted)),
        const SizedBox(height: 8),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d ]'))],
          style: sans(17),
          decoration: const InputDecoration(prefixText: '+57  '),
        ),
        const SizedBox(height: 18),
        AppButton('Guardar', onTap: () => Navigator.pop(ctx, true)),
      ]),
    );
    if (ok == true && name.text.trim().isNotEmpty) {
      final d = phone.text.replaceAll(RegExp(r'\D'), '');
      await cubit.updateProfile(name.text.trim(), d.isEmpty ? null : '+57 $d');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.select((AppCubit c) => c.state.profile);
    final cubit = context.read<AppCubit>();

    Widget section(String title, List<Widget> children) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MonoLabel(title),
            const SizedBox(height: 10),
            Box(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4), child: Column(children: children)),
            const SizedBox(height: 22),
          ],
        );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        children: [
          Text('Perfil', style: bold(28)),
          const SizedBox(height: 20),
          Box(
            onTap: () => _edit(context),
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Avatar(name: p?.name ?? '', color: AppColors.accent, size: 56),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(p?.name ?? '', style: bold(19)),
                  const SizedBox(height: 4),
                  Text(p?.phone ?? 'Sin celular', style: sans(14, color: AppColors.muted)),
                ]),
              ),
              const Ico(AppIcon.pencil, size: 18, color: AppColors.muted),
            ]),
          ),
          const SizedBox(height: 22),
          section('Asistente de voz', [
            SheetOption(
              icon: AppIcon.sparkle,
              color: AppColors.violet,
              title: AppConfig.hasGemini ? 'Lectura con IA activa' : 'IA sin configurar',
              subtitle: AppConfig.hasGemini
                  ? 'Gemini (${AppConfig.geminiModel}) entiende las frases. Sin internet se usan reglas locales.'
                  : 'Falta la clave de Gemini en env.json. Mientras tanto se usan reglas locales para leer la frase.',
              onTap: () {},
            ),
          ]),
          section('Datos', [
            SheetOption(
              icon: AppIcon.database,
              title: 'Cargar datos de ejemplo',
              subtitle: 'Agrega “Apto Laureles” y “Viaje a Guatapé” para probar la app.',
              onTap: () async {
                if (await confirm(context,
                    title: 'Cargar datos de ejemplo',
                    body: 'Se agregarán dos grupos de ejemplo. Tus grupos actuales no se modifican.',
                    ok: 'Cargar')) {
                  await cubit.loadSample();
                  if (context.mounted) toast(context, 'Datos de ejemplo cargados');
                }
              },
            ),
            SheetOption(
              icon: AppIcon.trash,
              color: AppColors.coral,
              title: 'Borrar todos los datos',
              subtitle: 'Elimina grupos, gastos, pagos y tu perfil de este teléfono.',
              onTap: () async {
                final tabs = context.read<TabCubit>();
                if (await confirm(context,
                    title: '¿Borrar todo?',
                    body: 'Esta acción no se puede deshacer.',
                    ok: 'Borrar',
                    danger: true)) {
                  tabs.go(0);
                  await cubit.wipe();
                }
              },
            ),
          ]),
          Center(child: Text('Gastos Compartidos · v1.0.0', style: mono(11))),
          const SizedBox(height: 4),
          Center(child: Text('Tus datos se guardan solo en este teléfono.', style: sans(12, color: AppColors.muted))),
        ],
      ),
    );
  }
}
