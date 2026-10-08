import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:field_notes/data/repositories/note_repository.dart';
import 'package:field_notes/shared/models/models.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

String? locationValidationMessage(double? latitude, double? longitude) {
  if (latitude == null && longitude == null) return null;
  if (latitude == null || longitude == null) {
    return 'Enter both latitude and longitude, or leave both empty.';
  }
  if (!latitude.isFinite || !longitude.isFinite) {
    return 'Location coordinates must be finite numbers.';
  }
  if (latitude < -90 || latitude > 90) {
    return 'Latitude must be between -90 and 90.';
  }
  if (longitude < -180 || longitude > 180) {
    return 'Longitude must be between -180 and 180.';
  }
  return null;
}

class NoteState extends Equatable {
  const NoteState({
    this.userId,
    this.notes = const [],
    this.loading = true,
    this.query = '',
    this.status,
    this.siteId,
    this.error,
    this.saveTick = 0,
    this.permissionMessage,
    this.openSettings = false,
    this.pickedPhotoPath,
    this.latitude,
    this.longitude,
    this.locationTick = 0,
    this.photoTick = 0,
  });

  final int? userId;
  final List<FieldNote> notes;
  final bool loading;
  final String query;
  final String? status;
  final String? siteId;
  final String? error;
  final int saveTick;
  final String? permissionMessage;
  final bool openSettings;
  final String? pickedPhotoPath;
  final double? latitude;
  final double? longitude;
  final int locationTick;
  final int photoTick;

  NoteState copyWith({
    int? userId,
    List<FieldNote>? notes,
    bool? loading,
    String? query,
    String? status,
    String? siteId,
    bool clearStatus = false,
    bool clearSite = false,
    String? error,
    bool clearError = false,
    int? saveTick,
    String? permissionMessage,
    bool clearPermission = false,
    bool? openSettings,
    String? pickedPhotoPath,
    double? latitude,
    double? longitude,
    int? locationTick,
    int? photoTick,
  }) {
    return NoteState(
      userId: userId ?? this.userId,
      notes: notes ?? this.notes,
      loading: loading ?? this.loading,
      query: query ?? this.query,
      status: clearStatus ? null : status ?? this.status,
      siteId: clearSite ? null : siteId ?? this.siteId,
      error: clearError ? null : error ?? this.error,
      saveTick: saveTick ?? this.saveTick,
      permissionMessage: clearPermission
          ? null
          : permissionMessage ?? this.permissionMessage,
      openSettings: openSettings ?? this.openSettings,
      pickedPhotoPath: pickedPhotoPath ?? this.pickedPhotoPath,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      locationTick: locationTick ?? this.locationTick,
      photoTick: photoTick ?? this.photoTick,
    );
  }

  @override
  List<Object?> get props => [
    userId,
    notes,
    loading,
    query,
    status,
    siteId,
    error,
    saveTick,
    permissionMessage,
    openSettings,
    pickedPhotoPath,
    latitude,
    longitude,
    locationTick,
    photoTick,
  ];
}

abstract class NoteEvent extends Equatable {
  const NoteEvent();
  @override
  List<Object?> get props => [];
}

class NotesWatch extends NoteEvent {
  const NotesWatch(this.userId);
  final int userId;
  @override
  List<Object?> get props => [userId];
}

class NotesUpdated extends NoteEvent {
  const NotesUpdated(this.userId, this.notes);
  final int userId;
  final List<FieldNote> notes;
  @override
  List<Object?> get props => [userId, notes];
}

class NotesStopped extends NoteEvent {
  const NotesStopped();
}

class NotesQueryChanged extends NoteEvent {
  const NotesQueryChanged(this.query);
  final String query;
  @override
  List<Object?> get props => [query];
}

class NotesStatusFilterChanged extends NoteEvent {
  const NotesStatusFilterChanged(this.status);
  final String? status;
  @override
  List<Object?> get props => [status];
}

class NotesSiteFilterChanged extends NoteEvent {
  const NotesSiteFilterChanged(this.siteId);
  final String? siteId;
  @override
  List<Object?> get props => [siteId];
}

class NoteSubmitted extends NoteEvent {
  const NoteSubmitted(this.draft);
  final NoteDraft draft;
  @override
  List<Object?> get props => [
    draft.id,
    draft.title,
    draft.siteId,
    draft.status,
    draft.notedAt,
    draft.newPhotoPath,
  ];
}

class NoteDeleted extends NoteEvent {
  const NoteDeleted(this.id);
  final String id;
  @override
  List<Object?> get props => [id];
}

class NoteLocationRequested extends NoteEvent {
  const NoteLocationRequested();
}

class NotePhotoRequested extends NoteEvent {
  const NotePhotoRequested(this.source);
  final ImageSource source;
  @override
  List<Object?> get props => [source];
}

class NoteBloc extends Bloc<NoteEvent, NoteState> {
  NoteBloc(this._repository, {ImagePicker? picker})
    : _picker = picker ?? ImagePicker(),
      super(const NoteState()) {
    on<NotesWatch>(_onWatch);
    on<NotesUpdated>((event, emit) {
      if (_userId == event.userId) {
        emit(state.copyWith(notes: event.notes, loading: false));
      }
    });
    on<NotesStopped>(_onStopped);
    on<NotesQueryChanged>(_onQuery);
    on<NotesStatusFilterChanged>(_onStatus);
    on<NotesSiteFilterChanged>(_onSite);
    on<NoteSubmitted>(_onSubmit);
    on<NoteDeleted>((event, emit) {
      final userId = _userId;
      if (userId != null) return _repository.delete(userId, event.id);
    });
    on<NoteLocationRequested>(_onLocation);
    on<NotePhotoRequested>(_onPhoto);
  }

  final NoteRepository _repository;
  final ImagePicker _picker;
  StreamSubscription<List<FieldNote>>? _sub;
  int? _userId;
  String _query = '';
  String? _status;
  String? _siteId;

  Future<void> _onWatch(NotesWatch event, Emitter<NoteState> emit) async {
    _userId = event.userId;
    _query = '';
    _status = null;
    _siteId = null;
    await _sub?.cancel();
    emit(
      NoteState(
        userId: event.userId,
        notes: const [],
        loading: true,
        saveTick: state.saveTick,
      ),
    );
    await _listen();
  }

  Future<void> _onStopped(NotesStopped event, Emitter<NoteState> emit) async {
    _userId = null;
    _query = '';
    _status = null;
    _siteId = null;
    await _sub?.cancel();
    _sub = null;
    emit(const NoteState(notes: [], loading: false));
  }

  Future<void> _onQuery(
    NotesQueryChanged event,
    Emitter<NoteState> emit,
  ) async {
    _query = event.query;
    emit(state.copyWith(query: event.query));
    await _listen();
  }

  Future<void> _onStatus(
    NotesStatusFilterChanged event,
    Emitter<NoteState> emit,
  ) async {
    _status = event.status;
    emit(
      state.copyWith(status: event.status, clearStatus: event.status == null),
    );
    await _listen();
  }

  Future<void> _onSite(
    NotesSiteFilterChanged event,
    Emitter<NoteState> emit,
  ) async {
    _siteId = event.siteId;
    emit(state.copyWith(siteId: event.siteId, clearSite: event.siteId == null));
    await _listen();
  }

  Future<void> _listen() async {
    final userId = _userId;
    if (userId == null) return;
    await _sub?.cancel();
    _sub = _repository
        .watch(userId: userId, status: _status, siteId: _siteId, query: _query)
        .listen((rows) => add(NotesUpdated(userId, rows)));
  }

  Future<void> _onSubmit(NoteSubmitted event, Emitter<NoteState> emit) async {
    final userId = _userId;
    if (userId == null) return;
    if (event.draft.siteId.isEmpty) {
      emit(state.copyWith(error: 'Choose a site.'));
      return;
    }
    if (event.draft.title.trim().isEmpty) {
      emit(state.copyWith(error: 'Title is required.'));
      return;
    }
    final locationError = locationValidationMessage(
      event.draft.latitude,
      event.draft.longitude,
    );
    if (locationError != null) {
      emit(state.copyWith(error: locationError));
      return;
    }
    await _repository.save(userId: userId, draft: event.draft);
    emit(state.copyWith(clearError: true, saveTick: state.saveTick + 1));
  }

  Future<void> _onLocation(
    NoteLocationRequested event,
    Emitter<NoteState> emit,
  ) async {
    final permission = await _request(Permission.locationWhenInUse, 'location');
    if (permission != null) {
      emit(
        state.copyWith(
          permissionMessage: permission.message,
          openSettings: permission.openSettings,
          clearError: true,
        ),
      );
      return;
    }
    try {
      final position = await Geolocator.getCurrentPosition();
      emit(
        state.copyWith(
          latitude: position.latitude,
          longitude: position.longitude,
          locationTick: state.locationTick + 1,
          clearPermission: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          permissionMessage: 'Location is unavailable. You can still save the note without it.',
          openSettings: false,
        ),
      );
    }
  }

  Future<void> _onPhoto(
    NotePhotoRequested event,
    Emitter<NoteState> emit,
  ) async {
    final permission = event.source == ImageSource.camera
        ? await _request(Permission.camera, 'camera')
        : await _request(Permission.photos, 'photo library');
    if (permission != null) {
      emit(
        state.copyWith(
          permissionMessage: permission.message,
          openSettings: permission.openSettings,
        ),
      );
      return;
    }
    final XFile? file;
    try {
      file = await _picker.pickImage(source: event.source, imageQuality: 85);
    } catch (_) {
      emit(
        state.copyWith(
          permissionMessage: event.source == ImageSource.camera
              ? 'Camera capture is not available on this computer. Choose a photo from files instead. You can still save the note.'
              : 'Could not open the photo picker. You can still save the note without a photo.',
          openSettings: false,
        ),
      );
      return;
    }
    if (file == null) return;
    emit(
      state.copyWith(
        pickedPhotoPath: file.path,
        photoTick: state.photoTick + 1,
        clearPermission: true,
      ),
    );
  }

  Future<_PermissionOutcome?> _request(
    Permission permission,
    String label,
  ) async {
    try {
      var status = await permission.status;
      if (!status.isGranted && !status.isLimited) {
        status = await permission.request();
      }
      if (status.isGranted || status.isLimited) return null;
      if (status.isPermanentlyDenied || status.isRestricted) {
        return _PermissionOutcome(
          '$label permission is turned off. Open settings to allow it. You can still save the note.',
          true,
        );
      }
      return _PermissionOutcome(
        '$label permission was denied. You can still save the note without it.',
        false,
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}

class _PermissionOutcome {
  const _PermissionOutcome(this.message, this.openSettings);
  final String message;
  final bool openSettings;
}
