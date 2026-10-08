import 'package:equatable/equatable.dart';
import 'package:field_notes/data/repositories/settings_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsState extends Equatable {
  const SettingsState(this.defaultStatus);
  final String defaultStatus;
  @override
  List<Object?> get props => [defaultStatus];
}

abstract class SettingsEvent extends Equatable {
  const SettingsEvent();
  @override
  List<Object?> get props => [];
}

class SettingsStarted extends SettingsEvent {
  const SettingsStarted();
}

class DefaultStatusChanged extends SettingsEvent {
  const DefaultStatusChanged(this.status);
  final String status;
  @override
  List<Object?> get props => [status];
}

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc(this._repository)
    : super(SettingsState(_repository.defaultStatus())) {
    on<SettingsStarted>(
      (event, emit) => emit(SettingsState(_repository.defaultStatus())),
    );
    on<DefaultStatusChanged>((event, emit) async {
      await _repository.setDefaultStatus(event.status);
      emit(SettingsState(event.status));
    });
  }

  final SettingsRepository _repository;
}
