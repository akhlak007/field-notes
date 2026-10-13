import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/features/auth/auth_bloc.dart';
import 'package:field_notes/features/auth/auth_page.dart';
import 'package:field_notes/features/customers/customer_bloc.dart';
import 'package:field_notes/features/customers/customer_pages.dart';
import 'package:field_notes/features/notes/note_bloc.dart';
import 'package:field_notes/features/notes/note_pages.dart';
import 'package:field_notes/features/settings/settings_bloc.dart';
import 'package:field_notes/features/settings/settings_page.dart';
import 'package:field_notes/features/sites/site_bloc.dart';
import 'package:field_notes/features/sync/sync_bloc.dart';
import 'package:field_notes/shared/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class FieldNotesApp extends StatelessWidget {
  const FieldNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Field Notes',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      themeMode: ThemeMode.light,
      home: BlocListener<AuthBloc, AuthState>(
        listenWhen: (previous, current) =>
            previous.status != current.status ||
            previous.userId != current.userId,
        listener: (context, state) {
          if (state.status == AuthStatus.authenticated &&
              state.userId != null) {
            context.read<CustomerBloc>().add(CustomersWatch(state.userId!));
            context.read<SiteBloc>().add(SitesWatch(state.userId!));
            context.read<NoteBloc>().add(NotesWatch(state.userId!));
            context.read<SettingsBloc>().add(const SettingsStarted());
            context.read<SyncBloc>().add(SyncStarted(state.userId!));
          } else if (state.status == AuthStatus.unauthenticated) {
            context.read<SyncBloc>().add(const SyncStopped());
            context.read<CustomerBloc>().add(const CustomersStopped());
            context.read<SiteBloc>().add(const SitesStopped());
            context.read<NoteBloc>().add(const NotesStopped());
          }
        },
        child: const AuthGate(),
      ),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        switch (state.status) {
          case AuthStatus.unknown:
            return const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppLogo(size: 96),
                    SizedBox(height: 24),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            );
          case AuthStatus.unauthenticated:
            return const AuthPage();
          case AuthStatus.authenticated:
            return const HomeShell();
        }
      },
    );
  }
}

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;
  final _keys = List.generate(3, (_) => GlobalKey<NavigatorState>());

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        final navigator = _keys[_index].currentState;
        if (navigator != null && navigator.canPop()) navigator.pop();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _index,
          children: [
            _tab(0, const NotesPage()),
            _tab(1, const CustomersPage()),
            _tab(2, const SettingsPage()),
          ],
        ),
        bottomNavigationBar: HomeTabBar(
          index: _index,
          onChanged: (index) => setState(() => _index = index),
        ),
      ),
    );
  }

  Widget _tab(int index, Widget page) {
    return Navigator(
      key: _keys[index],
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => page),
    );
  }
}
