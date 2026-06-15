import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../core/vistar/widgets.dart';
import '../data/users_repository.dart';

class SetPasswordDialog extends ConsumerStatefulWidget {
  const SetPasswordDialog({super.key, required this.userId, required this.username});
  final String userId;
  final String username;

  @override
  ConsumerState<SetPasswordDialog> createState() => _SetPasswordDialogState();
}

class _SetPasswordDialogState extends ConsumerState<SetPasswordDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Set password — ${widget.username}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 280),
        child: FormBuilder(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderTextField(
                name: 'newPassword',
                decoration: const InputDecoration(
                  labelText: 'New password',
                  helperText: 'Sessions will be invalidated.',
                ),
                obscureText: true,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.minLength(8),
                ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 8),
                Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        RibbonButton(
          small: true,
          onPressed: _busy ? null : _submit,
          icon: _busy ? null : Icons.key,
          label: _busy ? 'Saving…' : 'Set password',
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final navigator = Navigator.of(context);
    try {
      await ref.read(usersRepositoryProvider).setPassword(
            widget.userId,
            form.value['newPassword'] as String,
          );
      navigator.pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = ApiError.from(e).message;
      });
    }
  }
}
