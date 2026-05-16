import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../core/errors/api_error.dart';
import '../../submissions/data/submission_models.dart';
import '../../submissions/data/submissions_repository.dart';

class ScoreItemDialog extends ConsumerStatefulWidget {
  const ScoreItemDialog({super.key, required this.submissionId, required this.item});
  final String submissionId;
  final SubmissionItem item;

  @override
  ConsumerState<ScoreItemDialog> createState() => _ScoreItemDialogState();
}

class _ScoreItemDialogState extends ConsumerState<ScoreItemDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final cat = widget.item.category;
    final max = cat?.maxMarks ?? 100;
    return AlertDialog(
      title: Text('Allocate marks — ${cat?.name ?? 'item'}'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420, minWidth: 280),
        child: FormBuilder(
          key: _formKey,
          initialValue: {
            'awardedMarks': (widget.item.awardedMarks ?? 0).toString(),
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Category max: $max'),
              const SizedBox(height: 8),
              FormBuilderTextField(
                name: 'awardedMarks',
                decoration: const InputDecoration(labelText: 'Awarded marks'),
                keyboardType: TextInputType.number,
                autofocus: true,
                validator: FormBuilderValidators.compose([
                  FormBuilderValidators.required(),
                  FormBuilderValidators.integer(),
                  FormBuilderValidators.min(0),
                  FormBuilderValidators.max(max),
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
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Text('Save'),
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
    final marks = int.parse(form.value['awardedMarks'] as String);
    try {
      await ref.read(submissionsRepositoryProvider).scoreItem(
            submissionId: widget.submissionId,
            itemId: widget.item.id,
            awardedMarks: marks,
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
