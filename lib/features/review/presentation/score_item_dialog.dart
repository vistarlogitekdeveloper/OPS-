import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../core/errors/api_error.dart';
import '../../../core/theme/vistar.dart';
import '../../../core/vistar/widgets.dart';
import '../../submissions/data/submission_models.dart';
import '../../submissions/data/submissions_repository.dart';

class ScoreItemDialog extends ConsumerStatefulWidget {
  const ScoreItemDialog({
    super.key,
    required this.submissionId,
    required this.item,
  });
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
    final theme = Theme.of(context);
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
            'opsRemark': widget.item.opsRemark ?? '',
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    'CATEGORY MAX',
                    style: TextStyle(
                      color: theme.hintColor,
                      fontSize: 10.5,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 8),
                  RibbonText(
                    '$max',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                      letterSpacing: -0.4,
                      height: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
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
              const SizedBox(height: 12),
              FormBuilderTextField(
                name: 'opsRemark',
                decoration: const InputDecoration(
                  labelText: 'Remark (optional)',
                  hintText: 'Why these marks were awarded',
                  alignLabelWithHint: true,
                ),
                minLines: 2,
                maxLines: 4,
                maxLength: 2000,
                textCapitalization: TextCapitalization.sentences,
                validator: FormBuilderValidators.maxLength(2000),
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
        RibbonButton(
          small: true,
          onPressed: _busy ? null : _submit,
          icon: _busy ? null : Icons.check,
          label: _busy ? 'Saving…' : 'Save',
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
    // Always send the remark so clearing the box clears the stored note.
    final remark = ((form.value['opsRemark'] as String?) ?? '').trim();
    try {
      await ref.read(submissionsRepositoryProvider).scoreItem(
            submissionId: widget.submissionId,
            itemId: widget.item.id,
            awardedMarks: marks,
            opsRemark: remark,
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
