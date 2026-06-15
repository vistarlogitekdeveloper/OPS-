import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/theme/vistar.dart';
import '../../../core/vistar/widgets.dart';
import '../../submissions/data/submission_models.dart';
import '../../submissions/data/submissions_repository.dart';

class DecisionDialog extends ConsumerStatefulWidget {
  const DecisionDialog({
    super.key,
    required this.submission,
    required this.approve,
  });
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
                    ? 'All items will be marked Approved. The Ops Excellence team can then allocate marks.'
                    : 'All items will be marked Rejected. The site user can re-upload and resubmit.',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 14),
              FormBuilderTextField(
                name: 'comment',
                maxLines: 3,
                decoration: InputDecoration(
                  labelText:
                      approve ? 'Comment (optional)' : 'Reason for rejection',
                ),
                validator: approve
                    ? FormBuilderValidators.maxLength(2000)
                    : FormBuilderValidators.compose([
                        FormBuilderValidators.required(),
                        FormBuilderValidators.maxLength(2000),
                      ]),
              ),
              if (_error != null) ...[
                const SizedBox(height: 10),
                _ErrorChip(message: _error!),
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
        if (approve)
          RibbonButton(
            small: true,
            onPressed: _busy ? null : _submit,
            icon: _busy ? null : Icons.check,
            label: _busy ? 'Approving…' : 'Approve',
          )
        else
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Vistar.bad,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            ),
            onPressed: _busy ? null : _submit,
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.close),
            label: Text(_busy ? 'Rejecting…' : 'Reject'),
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

class _ErrorChip extends StatelessWidget {
  const _ErrorChip({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Vistar.bad.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Vistar.rSm),
        border: Border.all(color: Vistar.bad.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Vistar.bad, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Vistar.bad,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
