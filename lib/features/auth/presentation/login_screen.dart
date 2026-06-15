import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../core/network/api_config.dart';
import '../../../core/theme/vistar.dart';
import '../../../core/vistar/widgets.dart';
import '../application/auth_controller.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _submitting = false;
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authControllerProvider);
    return Scaffold(
      body: AmbientBackground(
        child: LayoutBuilder(
          builder: (context, c) {
            final wide = c.maxWidth >= 920;
            final form = _FormPanel(
              formKey: _formKey,
              submitting: _submitting,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              onSubmit: _submit,
              errorMessage: auth.errorMessage,
            );

            if (!wide) {
              return SafeArea(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: form,
                    ),
                  ),
                ),
              );
            }

            final formBg =
                Theme.of(context).colorScheme.surfaceContainerLow;
            return Row(
              children: [
                const Expanded(flex: 105, child: _ArtPanel()),
                Expanded(
                  flex: 95,
                  child: Container(
                    color: formBg,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 56, vertical: 48),
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: form,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    final values = form.value;
    setState(() => _submitting = true);
    try {
      await ref.read(authControllerProvider.notifier).login(
            username: (values['username'] as String).trim(),
            password: values['password'] as String,
          );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}

class _ArtPanel extends StatelessWidget {
  const _ArtPanel();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return Stack(
      children: [
        // Huge rotated faint S behind the pitch
        Positioned.fill(
          child: IgnorePointer(
            child: Opacity(
              opacity: 0.16,
              child: Transform.rotate(
                angle: -12 * math.pi / 180,
                child: OverflowBox(
                  maxWidth: double.infinity,
                  maxHeight: double.infinity,
                  child: Image.asset(
                    Vistar.smarkAsset,
                    width: 1100,
                    height: 1100,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Image.asset(
                Vistar.wordmarkAsset,
                height: 58,
                fit: BoxFit.contain,
                alignment: Alignment.centerLeft,
              ),
              const Spacer(),
              _PitchHeadline(),
              const SizedBox(height: 20),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Text(
                  'Centralised monthly reporting and compliance — 25 project '
                  'sites, 10 mandatory report categories, scored against a '
                  '100-mark rubric and rolled up to a single source of truth.',
                  style: TextStyle(
                    fontSize: 15,
                    height: 1.55,
                    color: muted,
                  ),
                ),
              ),
              const SizedBox(height: 44),
              const Row(
                children: [
                  _Stat(label: 'Project sites', value: '25'),
                  SizedBox(width: 44),
                  _Stat(label: 'Mark rubric', value: '100'),
                  SizedBox(width: 44),
                  _Stat(label: 'Categories', value: '10'),
                ],
              ),
              const Spacer(),
              Text(
                'VISTAR LOGITEK · OPERATIONAL EXCELLENCE',
                style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 3,
                  fontWeight: FontWeight.w700,
                  color: theme.hintColor,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PitchHeadline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800,
          letterSpacing: -0.4,
          height: 1.1,
        );
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        Text('Operational ', style: base),
        RibbonText('Excellence', style: base),
        Text('.', style: base),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        RibbonText(
          value,
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            fontSize: 38,
            letterSpacing: -0.4,
            height: 1,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w700,
            color: theme.hintColor,
          ),
        ),
      ],
    );
  }
}

class _FormPanel extends StatelessWidget {
  const _FormPanel({
    required this.formKey,
    required this.submitting,
    required this.obscure,
    required this.onToggleObscure,
    required this.onSubmit,
    required this.errorMessage,
  });

  final GlobalKey<FormBuilderState> formKey;
  final bool submitting;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final VoidCallback onSubmit;
  final String? errorMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;

    return FormBuilder(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Image.asset(
              Vistar.smarkAsset,
              width: 46,
              height: 46,
              fit: BoxFit.contain,
            ),
          ),
          const SizedBox(height: 22),
          Text(
            'Welcome back',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -0.4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Sign in to continue to the Ops Excellence portal.',
            style: TextStyle(color: muted, fontSize: 14),
          ),
          const SizedBox(height: 28),
          FormBuilderTextField(
            name: 'username',
            autofocus: true,
            autofillHints: const [AutofillHints.username],
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'Username',
              prefixIcon: Icon(Icons.person_outline),
            ),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.minLength(1),
            ]),
          ),
          const SizedBox(height: 14),
          FormBuilderTextField(
            name: 'password',
            obscureText: obscure,
            autofillHints: const [AutofillHints.password],
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => onSubmit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(obscure ? Icons.visibility : Icons.visibility_off),
                onPressed: onToggleObscure,
              ),
            ),
            validator: FormBuilderValidators.compose([
              FormBuilderValidators.required(),
              FormBuilderValidators.minLength(1),
            ]),
          ),
          ?(errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: _VistarErrorBanner(message: errorMessage!),
                )
              : null),
          const SizedBox(height: 26),
          RibbonButton(
            onPressed: submitting ? null : onSubmit,
            label: submitting ? 'Signing in…' : 'Sign in',
            icon: submitting ? null : Icons.login,
            expand: true,
          ),
          const SizedBox(height: 18),
          Text(
            'API: ${ApiConfig.baseUrl}',
            style: TextStyle(color: theme.hintColor, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _VistarErrorBanner extends StatelessWidget {
  const _VistarErrorBanner({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Vistar.bad.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Vistar.rSm),
        border: Border.all(color: Vistar.bad.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Vistar.bad, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Vistar.bad,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
