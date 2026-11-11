import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../data/database.dart';
import '../data/models.dart';
import '../data/repository.dart';
import '../data/sample_data.dart';

// ------------------------------------------------------------------ Perfil

class AppState extends Equatable {
  const AppState({this.loading = true, this.profile});
  final bool loading;
  final Profile? profile;

  bool get onboarded => profile != null;

  @override
  List<Object?> get props => [loading, profile];
}

class AppCubit extends Cubit<AppState> {
  AppCubit(this.repo) : super(const AppState()) {
    _sub = repo.watchProfile().listen((p) => emit(AppState(loading: false, profile: p)));
    runMaintenance();
  }

  final Repository repo;
  late final StreamSubscription<Profile?> _sub;

  /// Genera gastos recurrentes vencidos y los avisos del día.
  Future<void> runMaintenance() async {
    final now = DateTime.now();
    await repo.runRecurring(now);
    await repo.dailyChecks(now);
  }

  Future<void> completeOnboarding(String name, String? phone, {bool withSample = false}) async {
    await repo.saveProfile(name, phone);
    if (withSample) await loadSampleData(repo, myName: name, myPhone: phone);
  }

  Future<void> updateProfile(String name, String? phone) => repo.saveProfile(name, phone);

  Future<void> loadSample() async {
    final p = state.profile;
    await loadSampleData(repo, myName: p?.name ?? 'Sofía', myPhone: p?.phone);
    await repo.dailyChecks(DateTime.now());
  }

  Future<void> wipe() => repo.wipeAll();

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}

// ------------------------------------------------------------------ Grupos

class GroupsState extends Equatable {
  const GroupsState({this.loading = true, this.groups = const []});
  final bool loading;
  final List<GroupOverview> groups;

  @override
  List<Object?> get props => [loading, groups.map((g) => (g.group, g.memberCount, g.myBalance)).toList()];
}

class GroupsCubit extends Cubit<GroupsState> {
  GroupsCubit(Repository repo) : super(const GroupsState()) {
    _sub = repo.watchGroupsOverview().listen((g) => emit(GroupsState(loading: false, groups: g)));
  }

  late final StreamSubscription<List<GroupOverview>> _sub;

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}

// ------------------------------------------------------------------ Avisos

class NoticesCubit extends Cubit<List<AppNotice>> {
  NoticesCubit(this.repo) : super(const []) {
    _sub = repo.watchNotices().listen(emit);
  }

  final Repository repo;
  late final StreamSubscription<List<AppNotice>> _sub;

  int get unread => state.where((n) => !n.read).length;

  Future<void> markRead() => repo.markNoticesRead();

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}

// ------------------------------------------------------------------ Pestañas

/// Pestaña activa de la barra inferior: 0 Inicio, 1 Grupos, 2 Saldar, 3 Perfil.
class TabCubit extends Cubit<int> {
  TabCubit() : super(0);
  void go(int tab) => emit(tab);
}

// ------------------------------------------------------------------ Detalle

class GroupDetailState extends Equatable {
  const GroupDetailState({this.loading = true, this.detail});
  final bool loading;
  final GroupDetail? detail;

  @override
  List<Object?> get props => [loading, identityHashCode(detail)];
}

class GroupDetailCubit extends Cubit<GroupDetailState> {
  GroupDetailCubit(Repository repo, int groupId) : super(const GroupDetailState()) {
    _sub = repo.watchGroupDetail(groupId).listen((d) => emit(GroupDetailState(loading: false, detail: d)));
  }

  late final StreamSubscription<GroupDetail?> _sub;

  @override
  Future<void> close() {
    _sub.cancel();
    return super.close();
  }
}
