import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../core/errors/api_error.dart';
import '../../submissions/data/submission_models.dart';
import '../../submissions/data/submissions_repository.dart';

class DecisionDialog extends ConsumerStatefulWidget {
  const DecisionDialog({super.key, required this.submission, required this.approve});
  final Submission submission;
  final bool approve;

  @override
  ConsumerState<DecisionDialog> createState() => _DecisionDialogState();
}

class _DecisionDialogState extends ConsumerState<DecisionDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _busy = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final approve = widget.approve;
    return AlertDialog(
      title: Text(approve ? 'Approve submission?' : 'Reject submission?'),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, minWidth: 320),
        child: FormBuilder(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                approve
                    ? 'All 10 items will be marked Approved. The Ops Excellence team can then allocate marks.'
                    : 'All items will be marked Rejected. The site user can re-upload and resubmit.',
              ),
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'comment',
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: approve ? 'Comment (optional)' : 'Reason for rejection',
                ),
                validator: approve
                    ? FormBuilderValidators.maxLength(2000)
                    : FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.maxLength(2000),
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
          style: approve
              ? null
              : FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                ),
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(approve ? 'Approve' : 'Reject'),
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
    final comment = (form.value['comment'] as String?)?.trim();
    try {
      await ref.read(submissionsRepositoryProvider).decide(
            submissionId: widget.submission.id,
            approve: widget.approve,
            comment: comment == null || comment.isEmpty ? null : comment,
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
