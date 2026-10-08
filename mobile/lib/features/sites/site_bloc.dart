import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:field_notes/data/repositories/site_repository.dart';
import 'package:field_notes/shared/models/models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SiteState extends Equatable {
  const SiteState({
    this.sites = const [],
    this.loading = true,
    this.error,
    this.saveTick = 0,
  });

  final List<Site> sites;
  final bool loading;
  final String? error;
  final int saveTick;

  SiteState copyWith({
    List<Site>? sites,
    bool? loading,
    String? error,
    bool clearError = false,
    int? saveTick,
  }) {
    return SiteState(
      sites: sites ?? this.sites,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      saveTick: saveTick ?? this.saveTick,
    );
  }

  @override
  List<Object?> get props => [sites, loading, error, saveTick];
}

abstract class SiteEvent extends Equatable {
  const SiteEvent();
  @override
  List<Object?> get props => [];
}

class SitesWatch extends SiteEvent {
  const SitesWatch(this.userId);
  final int userId;
  @override
  List<Object?> get props => [userId];
}

class SitesUpdated extends SiteEvent {
  const SitesUpdated(this.userId, this.sites);
  final int userId;
  final List<Site> sites;
  @override
  List<Object?> get props => [userId, sites];
}

class SitesStopped extends SiteEvent {
  const SitesStopped();
}

class SiteSubmitted extends SiteEvent {
  const SiteSubmitted({
    this.id,
    required this.userId,
    required this.customerId,
    required this.siteName,
    this.address,
  });
  final String? id;
  final int userId;
  final String customerId;
  final String siteName;
  final String? address;
  @override
  List<Object?> get props => [id, userId, customerId, siteName, address];
}

class SiteDeleted extends SiteEvent {
  const SiteDeleted(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class SiteBloc extends Bloc<SiteEvent, SiteState> {
  SiteBloc(this._repository) : super(const SiteState()) {
    on<SitesWatch>(_onWatch);
    on<SitesUpdated>((event, emit) {
      if (_userId == event.userId) {
        emit(state.copyWith(sites: event.sites, loading: false));
      }
    });
    on<SitesStopped>(_onStopped);
    on<SiteSubmitted>(_onSubmit);
    on<SiteDeleted>((event, emit) {
      final userId = _userId;
      if (userId != null) return _repository.delete(userId, event.id);
    });
  }

  final SiteRepository _repository;
  StreamSubscription<List<Site>>? _sub;
  int? _userId;

  Future<void> _onWatch(SitesWatch event, Emitter<SiteState> emit) async {
    _userId = event.userId;
    await _sub?.cancel();
    emit(SiteState(sites: const [], loading: true, saveTick: state.saveTick));
    _sub = _repository
        .watch(event.userId)
        .listen((rows) => add(SitesUpdated(event.userId, rows)));
  }

  Future<void> _onStopped(SitesStopped event, Emitter<SiteState> emit) async {
    _userId = null;
    await _sub?.cancel();
    _sub = null;
    emit(const SiteState(sites: [], loading: false));
  }

  Future<void> _onSubmit(SiteSubmitted event, Emitter<SiteState> emit) async {
    if (event.customerId.isEmpty) {
      emit(state.copyWith(error: 'Choose a customer.'));
      return;
    }
    if (event.siteName.trim().isEmpty) {
      emit(state.copyWith(error: 'Site name is required.'));
      return;
    }
    await _repository.save(
      id: event.id,
      userId: event.userId,
      customerId: event.customerId,
      siteName: event.siteName,
      address: event.address,
    );
    emit(state.copyWith(clearError: true, saveTick: state.saveTick + 1));
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
