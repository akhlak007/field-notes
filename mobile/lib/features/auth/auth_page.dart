import 'package:field_notes/core/theme/app_theme.dart';
import 'package:field_notes/features/auth/auth_bloc.dart';
import 'package:field_notes/shared/widgets/common.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _register = false;
  bool _showPassword = false;
  bool _showConfirm = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: BlocBuilder<AuthBloc, AuthState>(
          builder: (context, state) {
            return LayoutBuilder(
              builder: (context, constraints) {
                final topPadding = (constraints.maxHeight * 0.14).clamp(
                  32.0,
                  150.0,
                );
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(24, topPadding, 24, 32),
                  child: Align(
                    alignment: Alignment.topCenter,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 390),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: AppLogo(size: 52),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'Field Notes',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.2,
                                ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Capture site visits anywhere. Syncs when you are back online.',
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  color: Colors.white,
                                  fontSize: 15,
                                  height: 1.2,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 28),
                          _AuthCard(
                            register: _register,
                            state: state,
                            email: _email,
                            password: _password,
                            confirm: _confirm,
                            showPassword: _showPassword,
                            showConfirm: _showConfirm,
                            onModeChanged: (register) {
                              if (state.submitting || register == _register) {
                                return;
                              }
                              context.read<AuthBloc>().add(
                                const AuthErrorCleared(),
                              );
                              setState(() => _register = register);
                            },
                            onTogglePassword: () =>
                                setState(() => _showPassword = !_showPassword),
                            onToggleConfirm: () =>
                                setState(() => _showConfirm = !_showConfirm),
                            onSubmit: _submit,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _submit() {
    if (_register) {
      context.read<AuthBloc>().add(
        RegisterRequested(
          email: _email.text,
          password: _password.text,
          confirmPassword: _confirm.text,
        ),
      );
    } else {
      context.read<AuthBloc>().add(
        LoginRequested(email: _email.text, password: _password.text),
      );
    }
  }
}

class _AuthCard extends StatelessWidget {
  const _AuthCard({
    required this.register,
    required this.state,
    required this.email,
    required this.password,
    required this.confirm,
    required this.showPassword,
    required this.showConfirm,
    required this.onModeChanged,
    required this.onTogglePassword,
    required this.onToggleConfirm,
    required this.onSubmit,
  });

  final bool register;
  final AuthState state;
  final TextEditingController email;
  final TextEditingController password;
  final TextEditingController confirm;
  final bool showPassword;
  final bool showConfirm;
  final ValueChanged<bool> onModeChanged;
  final VoidCallback onTogglePassword;
  final VoidCallback onToggleConfirm;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 21),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _ModeToggle(register: register, onChanged: onModeChanged),
          const SizedBox(height: 17),
          const _AuthFieldLabel('Email'),
          Semantics(
            label: 'Email',
            child: TextField(
              controller: email,
              keyboardType: TextInputType.emailAddress,
              autofillHints: const [AutofillHints.email],
              textInputAction: TextInputAction.next,
              autocorrect: false,
              decoration: _inputDecoration('worker@company.com'),
            ),
          ),
          const SizedBox(height: 13),
          const _AuthFieldLabel('Password'),
          Semantics(
            label: 'Password',
            child: TextField(
              controller: password,
              obscureText: !showPassword,
              autofillHints: [
                register ? AutofillHints.newPassword : AutofillHints.password,
              ],
              enableSuggestions: false,
              autocorrect: false,
              textInputAction: register
                  ? TextInputAction.next
                  : TextInputAction.done,
              onSubmitted: state.submitting || register
                  ? null
                  : (_) => onSubmit(),
              decoration: _inputDecoration(
                'Password',
                suffixIcon: IconButton(
                  tooltip: showPassword ? 'Hide password' : 'Show password',
                  onPressed: onTogglePassword,
                  icon: Icon(
                    showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 20,
                  ),
                ),
              ),
            ),
          ),
          if (register) ...[
            const SizedBox(height: 13),
            const _AuthFieldLabel('Confirm password'),
            Semantics(
              label: 'Confirm password',
              child: TextField(
                controller: confirm,
                obscureText: !showConfirm,
                autofillHints: const [AutofillHints.newPassword],
                enableSuggestions: false,
                autocorrect: false,
                textInputAction: TextInputAction.done,
                onSubmitted: state.submitting ? null : (_) => onSubmit(),
                decoration: _inputDecoration(
                  'Confirm password',
                  suffixIcon: IconButton(
                    tooltip: showConfirm ? 'Hide password' : 'Show password',
                    onPressed: onToggleConfirm,
                    icon: Icon(
                      showConfirm
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (state.error != null) ...[
            const SizedBox(height: 12),
            Semantics(
              liveRegion: true,
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  state.error!,
                  style: TextStyle(color: scheme.onErrorContainer),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            height: 48,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              onPressed: state.submitting ? null : onSubmit,
              child: state.submitting
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Text(register ? 'Create account' : 'Sign in'),
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _inputDecoration(String hint, {Widget? suffixIcon}) {
    return InputDecoration(
      hintText: hint,
      suffixIcon: suffixIcon,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      border: _inputBorder(AppColors.line),
      enabledBorder: _inputBorder(AppColors.line),
      focusedBorder: _inputBorder(AppColors.primary, width: 1.5),
    );
  }

  OutlineInputBorder _inputBorder(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(13),
      borderSide: BorderSide(color: color, width: width),
    );
  }
}

class _ModeToggle extends StatelessWidget {
  const _ModeToggle({required this.register, required this.onChanged});

  final bool register;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 8,
      children: [
        _ModeButton(
          label: 'Sign in',
          selected: !register,
          onTap: () => onChanged(false),
        ),
        _ModeButton(
          label: 'Register',
          selected: register,
          onTap: () => onChanged(true),
        ),
      ],
    );
  }
}

class _ModeButton extends StatelessWidget {
  const _ModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: ExcludeSemantics(
        child: Material(
          color: selected ? AppColors.primary : Colors.white,
          shape: StadiumBorder(
            side: BorderSide(color: selected ? AppColors.primary : AppColors.line),
          ),
          child: InkWell(
            onTap: onTap,
            customBorder: const StadiumBorder(),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 15),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: TextStyle(
                      color: selected ? Colors.white : AppColors.ink,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthFieldLabel extends StatelessWidget {
  const _AuthFieldLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(
          color: Color(0xFF536F6A),
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
