import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_native_contact_picker/flutter_native_contact_picker.dart';

import '../core/money.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../state/app_cubits.dart';
import '../state/group_form_cubit.dart';
import '../ui/icons.dart';
import '../ui/messaging.dart';
import '../ui/theme.dart';
import '../ui/widgets.dart';
import 'group_detail_screen.dart';

/// Pantalla 3 del recorrido: Nuevo grupo (y edición de un grupo existente).
class GroupFormScreen extends StatelessWidget {
  const GroupFormScreen({super.key, this.groupId});
  final int? groupId;

  @override
  Widget build(BuildContext context) {
    final p = context.read<AppCubit>().state.profile;
    return BlocProvider(
      create: (_) => GroupFormCubit(
        context.read<Repository>(),
        groupId: groupId,
        myName: p?.name ?? 'Yo',
        myPhone: p?.phone,
      ),
      child: const _GroupFormView(),
    );
  }
}

class _GroupFormView extends StatefulWidget {
  const _GroupFormView();

  @override
  State<_GroupFormView> createState() => _GroupFormViewState();
}

class _GroupFormViewState extends State<_GroupFormView> {
  final _name = TextEditingController();
  bool _filled = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  GroupFormCubit get _cubit => context.read<GroupFormCubit>();

  String _inviteText(String name, String group) =>
      '¡Hola $name! Te agregué al grupo “$group” en Gastos Compartidos para llevar las cuentas claras. '
      'Yo voy registrando los gastos y te aviso cuánto te toca y a quién pagarle.';

  Future<void> _invite(int index) async {
    final s = _cubit.state;
    final m = s.members[index];
    final group = s.name.trim().isEmpty ? 'nuestro grupo' : s.name.trim();
    final opened = await sendMessage(phone: m.phone, text: _inviteText(m.name.split(' ').first, group));
    if (opened) await _cubit.markInvited(index);
  }

  Future<void> _pickContact() async {
    try {
      final c = await FlutterNativeContactPicker().selectPhoneNumber();
      if (c == null) return;
      final name = (c.fullName ?? '').trim();
      final phone = c.selectedPhoneNumber ?? c.phoneNumbers?.firstOrNull;
      final err = _cubit.addMember(name.isEmpty ? (phone ?? 'Contacto') : name, phone);
      if (err != null && mounted) toast(context, err);
    } catch (_) {
      if (mounted) toast(context, 'No se pudo abrir los contactos');
    }
  }

  Future<void> _manualMember({int? index}) async {
    final existing = index == null ? null : _cubit.state.members[index];
    final name = TextEditingController(text: existing?.name ?? '');
    final phone = TextEditingController(text: existing?.phone ?? '');
    final ok = await showAppSheet<bool>(
      context,
      title: index == null ? 'Agregar integrante' : 'Editar integrante',
      builder: (ctx) => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Nombre', style: sans(14, color: AppColors.muted)),
        const SizedBox(height: 8),
        TextField(controller: name, autofocus: true, textCapitalization: TextCapitalization.words, style: bold(17)),
        const SizedBox(height: 14),
        Text('Celular para WhatsApp (opcional)', style: sans(14, color: AppColors.muted)),
        const SizedBox(height: 8),
        TextField(
          controller: phone,
          keyboardType: TextInputType.phone,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d +]'))],
          style: sans(17),
          decoration: const InputDecoration(hintText: '300 123 4567'),
        ),
        const SizedBox(height: 18),
        AppButton(index == null ? 'Agregar' : 'Guardar', onTap: () => Navigator.pop(ctx, true)),
      ]),
    );
    if (ok != true) return;
    final ph = phone.text.trim().isEmpty ? null : phone.text.trim();
    if (index == null) {
      final err = _cubit.addMember(name.text, ph);
      if (err != null && mounted) toast(context, err);
    } else if (name.text.trim().isNotEmpty) {
      _cubit.updateMember(index, name.text, ph);
    }
  }

  Future<void> _inviteSheet() async {
    await showAppSheet<void>(
      context,
      title: 'Invitar integrantes',
      builder: (ctx) => Column(children: [
        SheetOption(
          icon: AppIcon.contact,
          title: 'Elegir de mis contactos',
          subtitle: 'Se agrega con su celular para escribirle por WhatsApp.',
          onTap: () {
            Navigator.pop(ctx);
            _pickContact();
          },
        ),
        SheetOption(
          icon: AppIcon.keyboard,
          color: AppColors.violet,
          title: 'Escribir nombre',
          subtitle: 'Agrega a alguien a mano, con o sin celular.',
          onTap: () {
            Navigator.pop(ctx);
            _manualMember();
          },
        ),
        SheetOption(
          icon: AppIcon.share,
          color: AppColors.amber,
          title: 'Compartir invitación',
          subtitle: 'Envía el mensaje al chat del grupo en WhatsApp u otra app.',
          onTap: () async {
            Navigator.pop(ctx);
            final s = _cubit.state;
            final group = s.name.trim().isEmpty ? 'nuestro grupo' : s.name.trim();
            await shareText(
              '¡Hola! Creé el grupo “$group” en Gastos Compartidos para llevar las cuentas claras. '
              'Yo registro los gastos y les aviso cuánto le toca a cada uno.',
              subject: 'Gastos Compartidos',
            );
            _cubit.markAllInvited();
          },
        ),
      ]),
    );
  }

  Future<void> _pickCurrency() async {
    final s = _cubit.state;
    if (s.currencyLocked) {
      toast(context, 'La moneda no se puede cambiar porque el grupo ya tiene gastos.');
      return;
    }
    final code = await showAppSheet<String>(
      context,
      title: 'Moneda del grupo',
      builder: (ctx) => Column(children: [
        for (final c in currencies)
          Tap(
            onTap: () => Navigator.pop(ctx, c.code),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Row(children: [
                SizedBox(width: 56, child: Text(c.code, style: mono(14, color: AppColors.text))),
                Expanded(child: Text(c.name, style: sans(15))),
                if (c.code == s.currency) const Ico(AppIcon.check, size: 18, color: AppColors.accent),
              ]),
            ),
          ),
      ]),
    );
    if (code != null) _cubit.setCurrency(code);
  }

  Future<void> _save() async {
    final id = await _cubit.save();
    if (id == null || !mounted) return;
    if (_cubit.editing) {
      Navigator.pop(context);
    } else {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => GroupDetailScreen(groupId: id)));
    }
  }

  Future<void> _delete() async {
    final repo = context.read<Repository>();
    final nav = Navigator.of(context);
    if (await confirm(context,
        title: '¿Eliminar grupo?',
        body: 'Se borrarán sus gastos, pagos y gastos recurrentes. No se puede deshacer.',
        ok: 'Eliminar',
        danger: true)) {
      await repo.deleteGroup(_cubit.groupId!);
      nav.popUntil((r) => r.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GroupFormCubit, GroupFormState>(
      listenWhen: (a, b) => a.error != b.error && b.error != null,
      listener: (context, s) => toast(context, s.error!),
      builder: (context, s) {
        if (!_filled && !s.loading) {
          _name.text = s.name;
          _filled = true;
        }
        final editing = _cubit.editing;
        final cur = currencyOf(s.currency);
        return Screen(
          bottom: AppButton(editing ? 'Guardar cambios' : 'Crear grupo',
              onTap: _save, enabled: s.valid && !s.saving),
          child: s.loading
              ? const SizedBox.shrink()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    ScreenHeader(
                      title: editing ? 'Editar grupo' : 'Nuevo grupo',
                      trailing: editing ? SquareButton(icon: AppIcon.trash, onTap: _delete) : null,
                    ),
                    const SizedBox(height: 18),
                    Text('Nombre del grupo', style: sans(14, color: AppColors.muted)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _name,
                      onChanged: _cubit.setName,
                      textCapitalization: TextCapitalization.sentences,
                      style: bold(17),
                      decoration: const InputDecoration(hintText: 'Ej. Apto Laureles'),
                    ),
                    const SizedBox(height: 18),
                    Text('Tipo de grupo', style: sans(14, color: AppColors.muted)),
                    const SizedBox(height: 8),
                    Segmented<GroupType>(
                      options: GroupType.values,
                      value: s.type,
                      onChanged: _cubit.setType,
                      label: (t) => t.label,
                    ),
                    const SizedBox(height: 8),
                    Text(s.type.note, style: sans(13, color: AppColors.muted, height: 1.4)),
                    const SizedBox(height: 18),
                    Box(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: DetailRow(
                        label: 'Moneda',
                        value: '${cur.code} · ${cur.name}',
                        divider: false,
                        onTap: _pickCurrency,
                        valueColor: s.currencyLocked ? AppColors.muted : AppColors.text,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Text('Integrantes', style: bold(16)),
                    const SizedBox(height: 6),
                    for (var i = 0; i < s.members.length; i++) _memberRow(s, i),
                    const SizedBox(height: 8),
                    AppButton('Invitar por WhatsApp o enlace',
                        icon: AppIcon.plus, kind: ButtonKind.dashed, height: 48, onTap: _inviteSheet),
                    if (s.members.length < 2) ...[
                      const SizedBox(height: 10),
                      Text('Agrega al menos a otra persona para crear el grupo.',
                          style: sans(13, color: AppColors.muted), textAlign: TextAlign.center),
                    ],
                  ],
                ),
        );
      },
    );
  }

  Widget _memberRow(GroupFormState s, int i) {
    final m = s.members[i];
    final locked = m.id != null && s.lockedMemberIds.contains(m.id);
    final (status, color) = m.isMe
        ? ('Administrador(a)', AppColors.muted)
        : m.invited
            ? ('Invitación enviada', AppColors.amber)
            : ('Sin invitar', AppColors.muted);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Avatar(name: m.name, color: AppColors.avatar(m.colorIndex ?? i), size: 38),
        const SizedBox(width: 12),
        Expanded(
          child: Tap(
            radius: 8,
            onTap: m.isMe ? null : () => _manualMember(index: i),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(m.isMe ? 'Tú' : m.name, style: bold(15), overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(m.phone == null || m.isMe ? status : '$status · ${m.phone}',
                  style: sans(13, color: color), overflow: TextOverflow.ellipsis),
            ]),
          ),
        ),
        if (!m.isMe) ...[
          IconButton(
            tooltip: m.phone == null ? 'Compartir invitación' : 'Invitar por WhatsApp',
            onPressed: () => _invite(i),
            icon: Ico(m.phone == null ? AppIcon.share : AppIcon.message, size: 20, color: AppColors.accent),
          ),
          if (!locked)
            IconButton(
              tooltip: 'Quitar',
              onPressed: () => _cubit.removeMember(i),
              icon: const Ico(AppIcon.close, size: 18, color: AppColors.muted),
            ),
        ],
      ]),
    );
  }
}
