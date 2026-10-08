import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:field_notes/app.dart';
import 'package:field_notes/core/config/app_config.dart';
import 'package:field_notes/data/local/app_database.dart';
import 'package:field_notes/data/remote/auth_interceptor.dart';
import 'package:field_notes/data/remote/field_notes_api.dart';
import 'package:field_notes/data/remote/token_storage.dart';
import 'package:field_notes/data/repositories/auth_repository.dart';
import 'package:field_notes/data/repositories/customer_repository.dart';
import 'package:field_notes/data/repositories/note_repository.dart';
import 'package:field_notes/data/repositories/settings_repository.dart';
import 'package:field_notes/data/repositories/site_repository.dart';
import 'package:field_notes/features/auth/auth_bloc.dart';
import 'package:field_notes/features/customers/customer_bloc.dart';
import 'package:field_notes/features/notes/note_bloc.dart';
import 'package:field_notes/features/notes/note_pages.dart';
import 'package:field_notes/features/settings/settings_bloc.dart';
import 'package:field_notes/features/sites/site_bloc.dart';
import 'package:field_notes/features/sync/sync_bloc.dart';
import 'package:field_notes/sync/local_change_bus.dart';
import 'package:field_notes/sync/session_events.dart';
import 'package:field_notes/sync/sync_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase(
    LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      final file = File(p.join(dir.path, 'field_notes.sqlite'));
      return NativeDatabase(file);
    }),
  );
  final preferences = await SharedPreferences.getInstance();
  final tokens = TokenStorage();
  final sessionEvents = SessionEvents();
  final base = AppConfig.apiBaseUrl();
  // Render free instances can take ~30–60s to wake; keep pending local data if this fails.
  const timeouts = Duration(seconds: 90);
  final dio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: timeouts,
      receiveTimeout: timeouts,
      sendTimeout: timeouts,
    ),
  );
  final refreshDio = Dio(
    BaseOptions(
      baseUrl: base,
      connectTimeout: timeouts,
      receiveTimeout: timeouts,
      sendTimeout: timeouts,
    ),
  );
  dio.interceptors.add(
    AuthInterceptor(
      dio: dio,
      refreshDio: refreshDio,
      tokens: tokens,
      sessionEvents: sessionEvents,
    ),
  );
  final api = FieldNotesApi(dio);
  final changes = LocalChangeBus();
  final authRepository = AuthRepository(api: api, tokens: tokens);
  final noteRepository = NoteRepository(database, changes, api);
  final syncService = SyncService(
    remote: api,
    database: database,
    userId: tokens.userId,
    accessToken: tokens.accessToken,
  );

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider<NoteRepository>.value(value: noteRepository),
        RepositoryProvider<NoteRepositoryHolder>.value(
          value: NoteRepositoryHolder(noteRepository.ensurePhoto),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AuthBloc(authRepository)..add(const AuthStarted()),
          ),
          BlocProvider(
            create: (_) => CustomerBloc(CustomerRepository(database, changes)),
          ),
          BlocProvider(
            create: (_) => SiteBloc(SiteRepository(database, changes)),
          ),
          BlocProvider(create: (_) => NoteBloc(noteRepository)),
          BlocProvider(
            create: (_) => SettingsBloc(SettingsRepository(preferences)),
          ),
          BlocProvider(
            create: (_) => SyncBloc(
              syncService: syncService,
              database: database,
              changes: changes,
              connectivity: Connectivity(),
            ),
          ),
        ],
        child: BlocListener<AuthBloc, AuthState>(
          listenWhen: (previous, current) =>
              current.status == AuthStatus.unauthenticated &&
              previous.status == AuthStatus.authenticated,
          listener: (context, state) {},
          child: _SessionBinder(
            sessionEvents: sessionEvents,
            child: const FieldNotesApp(),
          ),
        ),
      ),
    ),
  );
}

class _SessionBinder extends StatefulWidget {
  const _SessionBinder({required this.sessionEvents, required this.child});

  final SessionEvents sessionEvents;
  final Widget child;

  @override
  State<_SessionBinder> createState() => _SessionBinderState();
}

class _SessionBinderState extends State<_SessionBinder> {
  @override
  void initState() {
    super.initState();
    widget.sessionEvents.expired.listen((_) {
      if (!mounted) return;
      context.read<AuthBloc>().add(const SessionExpired());
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
