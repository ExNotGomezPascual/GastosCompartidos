import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/models.dart';
import '../data/repository.dart';

class GroupFormState extends Equatable {
  const GroupFormState({
    this.loading = false,
    this.name = '',
    this.type = GroupType.piso,
    this.currency = 'COP',
    this.members = const [],
    this.currencyLocked = false,
    this.lockedMemberIds = const {},
    this.saving = false,
    this.error,
  });

  final bool loading;
  final String name;
  final GroupType type;
  final String currency;
  final List<MemberDraft> members;

  /// La moneda no se cambia si el grupo ya tiene gastos.
  final bool currencyLocked;

  /// Integrantes con gastos o pagos: no se pueden quitar.
  final Set<int> lockedMemberIds;
  final bool saving;
  final String? error;

  bool get valid => name.trim().isNotEmpty && members.length >= 2;

  GroupFormState copyWith({
    bool? loading,
    String? name,
    GroupType? type,
    String? currency,
    List<MemberDraft>? members,
    bool? currencyLocked,
    Set<int>? lockedMemberIds,
    bool? saving,
    String? error,
    bool clearError = false,
  }) =>
      GroupFormState(
        loading: loading ?? this.loading,
        name: name ?? this.name,
        type: type ?? this.type,
        currency: currency ?? this.currency,
        members: members ?? this.members,
        currencyLocked: currencyLocked ?? this.currencyLocked,
        lockedMemberIds: lockedMemberIds ?? this.lockedMemberIds,
        saving: saving ?? this.saving,
        error: clearError ? null : (error ?? this.error),
      );

  @override
  List<Object?> get props => [
        loading, name, type, currency, currencyLocked, lockedMemberIds, saving, error,
        members.map((m) => (m.id, m.name, m.phone, m.invited)).toList(),
      ];
}

class GroupFormCubit extends Cubit<GroupFormState> {
  GroupFormCubit(this.repo, {this.groupId, required String myName, String? myPhone})
      : super(GroupFormState(
          loading: groupId != null,
          members: [MemberDraft(name: myName, phone: myPhone, isMe: true, colorIndex: 0)],
        )) {
    if (groupId != null) _load();
  }

  final Repository repo;
  final int? groupId;
  bool get editing => groupId != null;

  Future<void> _load() async {
    final d = await repo.groupDetail(groupId!);
    if (d == null) return;
    emit(state.copyWith(
      loading: false,
      name: d.group.name,
      type: d.type,
      currency: d.group.currency,
      currencyLocked: d.expenses.isNotEmpty || d.payments.isNotEmpty,
      lockedMemberIds: d.involvedMemberIds,
      members: [
        for (final m in d.members)
          MemberDraft(id: m.id, name: m.name, phone: m.phone, isMe: m.isMe, invited: m.invited, colorIndex: m.colorIndex),
      ],
    ));
  }

  void setName(String v) => emit(state.copyWith(name: v, clearError: true));
  void setType(GroupType t) => emit(state.copyWith(type: t));
  void setCurrency(String c) {
    if (!state.currencyLocked) emit(state.copyWith(currency: c));
  }

  /// Devuelve un error si el integrante ya existe.
  String? addMember(String name, String? phone) {
    final n = name.trim();
    if (n.isEmpty) return 'Escribe un nombre';
    if (state.members.any((m) => m.name.toLowerCase() == n.toLowerCase())) {
      return '$n ya está en el grupo';
    }
    final used = state.members.map((m) => m.colorIndex ?? 0).toSet();
    var color = 1;
    while (used.contains(color)) {
      color++;
    }
    emit(state.copyWith(
      members: [...state.members, MemberDraft(name: n, phone: phone, colorIndex: color)],
      clearError: true,
    ));
    return null;
  }

  void updateMember(int index, String name, String? phone) {
    final list = [...state.members];
    list[index] = list[index].copyWith(name: name.trim(), phone: phone);
    emit(state.copyWith(members: list));
  }

  void removeMember(int index) {
    final m = state.members[index];
    if (m.isMe || (m.id != null && state.lockedMemberIds.contains(m.id))) return;
    emit(state.copyWith(members: [...state.members]..removeAt(index)));
  }

  Future<void> markInvited(int index) async {
    final list = [...state.members];
    list[index] = list[index].copyWith(invited: true);
    emit(state.copyWith(members: list));
    final id = list[index].id;
    if (id != null) await repo.markInvited(id);
  }

  void markAllInvited() => emit(state.copyWith(
        members: [for (final m in state.members) m.isMe ? m : m.copyWith(invited: true)],
      ));

  /// Guarda y devuelve el id del grupo, o null si hubo error.
  Future<int?> save() async {
    if (!state.valid) {
      emit(state.copyWith(
          error: state.name.trim().isEmpty ? 'Ponle un nombre al grupo' : 'Agrega al menos a otra persona'));
      return null;
    }
    emit(state.copyWith(saving: true, clearError: true));
    try {
      if (editing) {
        await repo.updateGroup(
          groupId: groupId!,
          name: state.name.trim(),
          type: state.type,
          currency: state.currency,
          members: state.members,
        );
        return groupId;
      }
      return await repo.createGroup(
        name: state.name.trim(),
        type: state.type,
        currency: state.currency,
        members: state.members,
      );
    } on MemberInUseException catch (e) {
      emit(state.copyWith(saving: false, error: e.toString()));
      return null;
    }
  }
}
