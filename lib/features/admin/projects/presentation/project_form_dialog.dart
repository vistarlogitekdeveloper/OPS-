import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../core/vistar/widgets.dart';
import '../../../projects/data/project_model.dart';
import '../../../projects/data/projects_repository.dart';

class ProjectFormDialog extends ConsumerStatefulWidget {
  const ProjectFormDialog({super.key, this.initial});
  final Project? initial;

  @override
  ConsumerState<ProjectFormDialog> createState() => _ProjectFormDialogState();
}

class _ProjectFormDialogState extends ConsumerState<ProjectFormDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _busy = false;
  String? _error;

  bool get _editing => widget.initial != null;

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    return AlertDialog(
      title: Text(_editing ? 'Edit project' : 'New project'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 320),
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'name': initial?.name ?? '',
            'code': initial?.code ?? '',
            'location': initial?.location ?? '',
            'isActive': initial?.isActive ?? true,
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FormBuilderTextField(
                name: 'name',
                decoration: const InputDecoration(labelText: 'Name'),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.maxLength(128),
                ]),
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'code',
                enabled: !_editing, // codes are stable identifiers in practice
                decoration: const InputDecoration(
                  labelText: 'Code',
                  helperText: 'Uppercase letters, digits, _ or - (2–32 chars)',
                ),
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.match(
                    RegExp(r'^[A-Z0-9][A-Z0-9_-]{1,31}$'),
                    errorText: 'Invalid code format',
                  ),
                ]),
                textCapitalization: TextCapitalization.characters,
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'location',
                decoration: const InputDecoration(labelText: 'Location (optional)'),
                validator: FormBuilderValidators.maxLength(128),
              ),
              const SizedBox(height: 8),
              FormBuilderSwitch(
                name: 'isActive',
                title: const Text('Active'),
                initialValue: initial?.isActive ?? true,
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
          icon: _busy ? null : Icons.check,
          label: _busy ? 'Saving…' : (_editing ? 'Save' : 'Create'),
        ),
      ],
    );
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.saveAndValidate()) return;
    final v = form.value;
    setState(() {
      _busy = true;
      _error = null;
    });

    final navigator = Navigator.of(context);
    final repo = ref.read(projectsRepositoryProvider);
    final name = (v['name'] as String).trim();
    final code = (v['code'] as String).trim().toUpperCase();
    final location = (v['location'] as String).trim();
    final isActive = v['isActive'] as bool? ?? true;

    try {
      if (_editing) {
        await repo.update(
          widget.initial!.id,
          name: name,
          location: location,
          isActive: isActive,
        );
      } else {
        await repo.create(
          name: name,
          code: code,
          location: location.isEmpty ? null : location,
          isActive: isActive,
        );
      }
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
