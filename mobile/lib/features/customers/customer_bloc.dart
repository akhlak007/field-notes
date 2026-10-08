import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:field_notes/data/repositories/customer_repository.dart';
import 'package:field_notes/shared/models/models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class CustomerState extends Equatable {
  const CustomerState({
    this.customers = const [],
    this.loading = true,
    this.error,
    this.saveTick = 0,
  });

  final List<Customer> customers;
  final bool loading;
  final String? error;
  final int saveTick;

  CustomerState copyWith({
    List<Customer>? customers,
    bool? loading,
    String? error,
    bool clearError = false,
    int? saveTick,
  }) {
    return CustomerState(
      customers: customers ?? this.customers,
      loading: loading ?? this.loading,
      error: clearError ? null : error ?? this.error,
      saveTick: saveTick ?? this.saveTick,
    );
  }

  @override
  List<Object?> get props => [customers, loading, error, saveTick];
}

abstract class CustomerEvent extends Equatable {
  const CustomerEvent();
  @override
  List<Object?> get props => [];
}

class CustomersWatch extends CustomerEvent {
  const CustomersWatch(this.userId);
  final int userId;
  @override
  List<Object?> get props => [userId];
}

class CustomersUpdated extends CustomerEvent {
  const CustomersUpdated(this.userId, this.customers);
  final int userId;
  final List<Customer> customers;
  @override
  List<Object?> get props => [userId, customers];
}

class CustomersStopped extends CustomerEvent {
  const CustomersStopped();
}

class CustomerSubmitted extends CustomerEvent {
  const CustomerSubmitted({
    this.id,
    required this.userId,
    required this.name,
    this.contactInfo,
  });
  final String? id;
  final int userId;
  final String name;
  final String? contactInfo;
  @override
  List<Object?> get props => [id, userId, name, contactInfo];
}

class CustomerDeleted extends CustomerEvent {
  const CustomerDeleted(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class CustomerBloc extends Bloc<CustomerEvent, CustomerState> {
  CustomerBloc(this._repository) : super(const CustomerState()) {
    on<CustomersWatch>(_onWatch);
    on<CustomersUpdated>((event, emit) {
      if (_userId == event.userId) {
        emit(state.copyWith(customers: event.customers, loading: false));
      }
    });
    on<CustomersStopped>(_onStopped);
    on<CustomerSubmitted>(_onSubmit);
    on<CustomerDeleted>(_onDelete);
  }

  final CustomerRepository _repository;
  StreamSubscription<List<Customer>>? _sub;
  int? _userId;

  Future<void> _onWatch(
    CustomersWatch event,
    Emitter<CustomerState> emit,
  ) async {
    _userId = event.userId;
    await _sub?.cancel();
    emit(
      CustomerState(
        customers: const [],
        loading: true,
        saveTick: state.saveTick,
      ),
    );
    _sub = _repository
        .watch(event.userId)
        .listen((rows) => add(CustomersUpdated(event.userId, rows)));
  }

  Future<void> _onStopped(
    CustomersStopped event,
    Emitter<CustomerState> emit,
  ) async {
    _userId = null;
    await _sub?.cancel();
    _sub = null;
    emit(const CustomerState(customers: [], loading: false));
  }

  Future<void> _onSubmit(
    CustomerSubmitted event,
    Emitter<CustomerState> emit,
  ) async {
    if (event.name.trim().isEmpty) {
      emit(state.copyWith(error: 'Name is required.'));
      return;
    }
    await _repository.save(
      id: event.id,
      userId: event.userId,
      name: event.name,
      contactInfo: event.contactInfo,
    );
    emit(state.copyWith(clearError: true, saveTick: state.saveTick + 1));
  }

  Future<void> _onDelete(CustomerDeleted event, Emitter<CustomerState> emit) {
    final userId = _userId;
    if (userId == null) return Future.value();
    return _repository.delete(userId, event.id);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
