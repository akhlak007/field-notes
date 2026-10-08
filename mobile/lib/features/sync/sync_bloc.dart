import 'dart:async';
import 'dart:math';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:field_notes/data/local/app_database.dart';
import 'package:field_notes/sync/local_change_bus.dart';
import 'package:field_notes/sync/sync_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SyncState extends Equatable {
  const SyncState({
    this.online = true,
    this.syncing = false,
    this.pending = 0,
    this.error,
  });

  final bool online;
  final bool syncing;
  final int pending;
  final String? error;

  String get label {
    if (!online) return 'Offline';
    if (syncing) return 'Syncing';
    if (pending > 0) return '$pending pending';
    return 'Synced';
  }

  SyncState copyWith({
    bool? online,
    bool? syncing,
    int? pending,
    String? error,
    bool clearError = false,
  }) {
    return SyncState(
      online: online ?? this.online,
      syncing: syncing ?? this.syncing,
      pending: pending ?? this.pending,
      error: clearError ? null : error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [online, syncing, pending, error];
}

abstract class SyncEvent extends Equatable {
  const SyncEvent();
  @override
  List<Object?> get props => [];
}

class SyncStarted extends SyncEvent {
  const SyncStarted(this.userId);
  final int userId;
  @override
  List<Object?> get props => [userId];
}

class SyncStopped extends SyncEvent {
  const SyncStopped();
}

class SyncRequested extends SyncEvent {
  const SyncRequested();
}

class ConnectivityChanged extends SyncEvent {
  const ConnectivityChanged(this.online);
  final bool online;
  @override
  List<Object?> get props => [online];
}

class SyncBloc extends Bloc<SyncEvent, SyncState> {
  SyncBloc({
    required SyncService syncService,
    required AppDatabase database,
    required LocalChangeBus changes,
    required Connectivity connectivity,
  }) : _syncService = syncService,
       _database = database,
       _connectivity = connectivity,
       super(const SyncState()) {
    on<SyncStarted>(_onStarted);
    on<SyncStopped>(_onStopped);
    on<SyncRequested>(_onRequested);
    on<ConnectivityChanged>(_onConnectivity);
    _changesSub = changes.changes.listen((_) => add(const SyncRequested()));
    _connectivitySub = connectivity.onConnectivityChanged.listen((results) {
      add(ConnectivityChanged(_isOnline(results)));
    });
  }

  final SyncService _syncService;
  final AppDatabase _database;
  final Connectivity _connectivity;
  StreamSubscription<void>? _changesSub;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _retry;
  int _attempt = 0;
  int? _userId;

  Future<void> _onStarted(SyncStarted event, Emitter<SyncState> emit) async {
    _retry?.cancel();
    _attempt = 0;
    _userId = event.userId;
    final results = await _connectivity.checkConnectivity();
    final online = _isOnline(results);
    final pending = await _database.pendingCount(event.userId);
    if (_userId != event.userId) return;
    emit(
      state.copyWith(
        online: online,
        pending: pending,
        syncing: false,
        clearError: true,
      ),
    );
    if (online) add(const SyncRequested());
  }

  void _onStopped(SyncStopped event, Emitter<SyncState> emit) {
    _retry?.cancel();
    _attempt = 0;
    _userId = null;
    emit(SyncState(online: state.online));
  }

  Future<void> _onConnectivity(
    ConnectivityChanged event,
    Emitter<SyncState> emit,
  ) async {
    emit(state.copyWith(online: event.online));
    if (event.online) add(const SyncRequested());
  }

  Future<void> _onRequested(
    SyncRequested event,
    Emitter<SyncState> emit,
  ) async {
    final userId = _userId;
    if (userId == null || state.syncing || !state.online) {
      if (userId != null) {
        final pending = await _database.pendingCount(userId);
        if (_userId == userId) {
          emit(state.copyWith(pending: pending));
        }
      }
      return;
    }
    emit(state.copyWith(syncing: true, clearError: true));
    try {
      await _syncService.sync();
      if (_userId != userId) return;
      _attempt = 0;
      _retry?.cancel();
    } catch (error) {
      if (_userId != userId) return;
      _scheduleRetry();
      emit(
        state.copyWith(
          error: error is SyncException
              ? error.message
              : 'Could not sync. Your changes are safe on this device.',
        ),
      );
    }
    final pending = await _database.pendingCount(userId);
    if (_userId != userId) return;
    emit(state.copyWith(syncing: false, pending: pending));
  }

  void _scheduleRetry() {
    _retry?.cancel();
    final seconds = min(60, 1 << min(_attempt, 6));
    _attempt += 1;
    _retry = Timer(
      Duration(seconds: seconds),
      () => add(const SyncRequested()),
    );
  }

  bool _isOnline(List<ConnectivityResult> results) {
    return results.any((result) => result != ConnectivityResult.none);
  }

  @override
  Future<void> close() {
    _retry?.cancel();
    _changesSub?.cancel();
    _connectivitySub?.cancel();
    return super.close();
  }
}
