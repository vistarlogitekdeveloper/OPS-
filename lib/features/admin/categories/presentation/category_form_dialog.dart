import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../core/vistar/widgets.dart';
import '../../../categories/data/categories_repository.dart';
import '../../../categories/data/category_model.dart';

class CategoryFormDialog extends ConsumerStatefulWidget {
  const CategoryFormDialog({super.key, this.initial});
  final ReportCategory? initial;

  @override
  ConsumerState<CategoryFormDialog> createState() => _CategoryFormDialogState();
}

class _CategoryFormDialogState extends ConsumerState<CategoryFormDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _busy = false;
  String? _error;
  late Set<FileTypeCode> _types;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    _types = widget.initial?.allowedFileTypes.toSet() ?? <FileTypeCode>{FileTypeCode.pdf};
  }

  @override
  Widget build(BuildContext context) {
    final initial = widget.initial;
    return AlertDialog(
      title: Text(_editing ? 'Edit category' : 'New category'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 320),
        child: SingleChildScrollView(
          child: FormBuilder(
            key: _formKey,
            initialValue: {
              'name': initial?.name ?? '',
              'maxMarks': (initial?.maxMarks ?? 0).toString(),
              'displayOrder': (initial?.displayOrder ?? 99).toString(),
              'isActive': initial?.isActive ?? true,
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
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
                Row(
                  children: [
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'maxMarks',
                        decoration: const InputDecoration(
                          labelText: 'Max marks',
                          helperText: '0–100',
                        ),
                        keyboardType: TextInputType.number,
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.integer(),
                          FormBuilderValidators.min(0),
                          FormBuilderValidators.max(100),
                        ]),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FormBuilderTextField(
                        name: 'displayOrder',
                        decoration: const InputDecoration(labelText: 'Display order'),
                        keyboardType: TextInputType.number,
                        validator: FormBuilderValidators.compose([
                          FormBuilderValidators.required(),
                          FormBuilderValidators.integer(),
                          FormBuilderValidators.min(0),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Allowed file types', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final t in FileTypeCode.values)
                      FilterChip(
                        label: Text(fileTypeLabel(t)),
                        selected: _types.contains(t),
                        onSelected: (sel) => setState(() {
                          if (sel) {
                            _types.add(t);
                          } else if (_types.length > 1) {
                            _types.remove(t);
                          }
                        }),
                      ),
                  ],
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
    final repo = ref.read(categoriesRepositoryProvider);
    final name = (v['name'] as String).trim();
    final maxMarks = int.parse(v['maxMarks'] as String);
    final displayOrder = int.parse(v['displayOrder'] as String);
    final isActive = v['isActive'] as bool? ?? true;
    final types = _types.toList();

    try {
      if (_editing) {
        await repo.update(
          widget.initial!.id,
          name: name,
          maxMarks: maxMarks,
          allowedFileTypes: types,
          displayOrder: displayOrder,
          isActive: isActive,
        );
      } else {
        await repo.create(
          name: name,
          maxMarks: maxMarks,
          allowedFileTypes: types,
          displayOrder: displayOrder,
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
