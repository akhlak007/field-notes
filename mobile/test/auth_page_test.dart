import 'dart:async';

import 'package:dio/dio.dart';
import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/data/remote/field_notes_api.dart';
import 'package:field_notes/data/remote/token_storage.dart';
import 'package:field_notes/data/repositories/auth_repository.dart';
import 'package:field_notes/features/auth/auth_bloc.dart';
import 'package:field_notes/features/auth/auth_page.dart';
import 'package:field_notes/shared/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the reference-style sign-in layout', (tester) async {
    await _pumpAuthPage(tester);

    expect(find.byType(AppLogo), findsOneWidget);
    expect(find.text('Field Notes'), findsOneWidget);
    expect(
      find.text(
        'Capture site visits anywhere. Syncs when you are back online.',
      ),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsNWidgets(2));
    expect(find.text('Register'), findsOneWidget);
    expect(find.text('Confirm password'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sign-in submits entered credentials and reports API errors', (
    tester,
  ) async {
    final repository = _FakeAuthRepository()
      ..loginError = DioException(
        requestOptions: RequestOptions(path: '/api/auth/login'),
        type: DioExceptionType.connectionError,
      );
    await _pumpAuthPage(tester, repository: repository);

    await tester.enterText(find.byType(TextField).at(0), 'worker@company.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(repository.loginEmail, 'worker@company.com');
    expect(repository.loginPassword, 'password123');
    expect(find.textContaining('waking up or unreachable'), findsOneWidget);

    await tester.tap(find.text('Register'));
    await tester.pumpAndSettle();
    expect(find.textContaining('waking up or unreachable'), findsNothing);
  });

  testWidgets('register tab validates and submits registration fields', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _pumpAuthPage(tester, repository: repository);

    await tester.tap(find.text('Register'));
    await tester.pump();

    expect(find.text('Confirm password'), findsNWidgets(2));
    expect(find.text('Create account'), findsOneWidget);

    await tester.tap(find.text('Create account'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a valid email.'), findsOneWidget);

    await tester.enterText(find.byType(TextField).at(0), 'new@company.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    await tester.enterText(find.byType(TextField).at(2), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();

    expect(repository.registerEmail, 'new@company.com');
    expect(repository.registerPassword, 'password123');
    expect(tester.takeException(), isNull);
  });

  testWidgets('loading state disables submission and narrow layouts scroll', (
    tester,
  ) async {
    final pendingLogin = Completer<Session>();
    final repository = _FakeAuthRepository()..loginCompleter = pendingLogin;
    await _pumpAuthPage(
      tester,
      repository: repository,
      size: const Size(300, 480),
      textScaler: const TextScaler.linear(1.4),
    );

    await tester.enterText(find.byType(TextField).at(0), 'user@company.com');
    await tester.enterText(find.byType(TextField).at(1), 'password123');
    final submit = find.widgetWithText(FilledButton, 'Sign in');
    await tester.ensureVisible(submit);
    await tester.tap(submit);
    await tester.pump();

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.takeException(), isNull);

    pendingLogin.complete(const Session(userId: 1, email: 'user@company.com'));
    await tester.pumpAndSettle();
  });
}

Future<void> _pumpAuthPage(
  WidgetTester tester, {
  _FakeAuthRepository? repository,
  Size size = const Size(390, 844),
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final bloc = AuthBloc(repository ?? _FakeAuthRepository());
  addTearDown(bloc.close);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: textScaler),
        child: child!,
      ),
      home: BlocProvider<AuthBloc>.value(value: bloc, child: const AuthPage()),
    ),
  );
}

class _FakeAuthRepository extends AuthRepository {
  _FakeAuthRepository()
    : super(api: FieldNotesApi(Dio()), tokens: TokenStorage());

  String? loginEmail;
  String? loginPassword;
  String? registerEmail;
  String? registerPassword;
  DioException? loginError;
  Completer<Session>? loginCompleter;

  @override
  Future<Session> login({required String email, required String password}) {
    loginEmail = email;
    loginPassword = password;
    if (loginError case final error?) return Future.error(error);
    return loginCompleter?.future ??
        Future.value(Session(userId: 1, email: email));
  }

  @override
  Future<Session> registerAndLogin({
    required String email,
    required String password,
  }) {
    registerEmail = email;
    registerPassword = password;
    return Future.value(Session(userId: 2, email: email));
  }
}
