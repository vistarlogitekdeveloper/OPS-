import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../../core/errors/api_error.dart';
import '../../../auth/data/auth_models.dart';
import '../../../projects/data/project_model.dart';
import '../../../projects/data/projects_repository.dart';
import '../data/users_repository.dart';

final _allProjectsProvider = FutureProvider<List<Project>>((ref) async {
  // First page is large enough to cover 25+ seeded sites; bump pageSize if needed.
  final res = await ref.watch(projectsRepositoryProvider).list(pageSize: 200);
  return res.items;
});

class UserFormDialog extends ConsumerStatefulWidget {
  const UserFormDialog({super.key, this.initial});
  final AuthUser? initial;

  @override
  ConsumerState<UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends ConsumerState<UserFormDialog> {
  final _formKey = GlobalKey<FormBuilderState>();
  bool _busy = false;
  String? _error;
  late UserRole _role;
  late Set<String> _assignedProjectIds;

  bool get _editing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final u = widget.initial;
    _role = u?.role ?? UserRole.siteUser;
    _assignedProjectIds = (u?.assignedProjectIds ?? const []).toSet();
  }

  @override
  Widget build(BuildContext context) {
    final u = widget.initial;
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(_allProjectsProvider);

    return AlertDialog(
      title: Text(_editing ? 'Edit user' : 'New user'),
      // `scrollable: true` lets the dialog scroll its own content. We MUST NOT
      // wrap the content in a SingleChildScrollView or have a fixed-height
      // ListView inside — nested scrollables make AlertDialog blow up with
      // "RenderViewport does not support returning intrinsic dimensions".
      scrollable: true,
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 540, minWidth: 320),
        child: FormBuilder(
            key: _formKey,
            initialValue: {
              'name': u?.name ?? '',
              'email': u?.email ?? '',
              'username': u?.username ?? '',
              'password': '',
              'isActive': u?.isActive ?? true,
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
                FormBuilderTextField(
                  name: 'email',
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.email(),
                  ]),
                ),
                const SizedBox(height: 12),
                FormBuilderTextField(
                  name: 'username',
                  enabled: !_editing,
                  decoration: const InputDecoration(
                    labelText: 'Username',
                    helperText: 'Letters, digits, . _ - (3–64 chars)',
                  ),
                  validator: FormBuilderValidators.compose([
                    FormBuilderValidators.required(),
                    FormBuilderValidators.match(
                      RegExp(r'^[a-zA-Z0-9._-]+$'),
                      errorText: 'Invalid username',
                    ),
                    FormBuilderValidators.minLength(3),
                    FormBuilderValidators.maxLength(64),
                  ]),
                ),
                if (!_editing) ...[
                  const SizedBox(height: 12),
                  FormBuilderTextField(
                    name: 'password',
                    decoration: const InputDecoration(labelText: 'Initial password'),
                    obscureText: true,
                    validator: FormBuilderValidators.compose([
                      FormBuilderValidators.required(),
                      FormBuilderValidators.minLength(8),
                    ]),
                  ),
                ],
                const SizedBox(height: 16),
                Text('Role', style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final r in const [
                      UserRole.admin,
                      UserRole.manager,
                      UserRole.siteUser,
                      UserRole.opsExcellence,
                    ])
                      ChoiceChip(
                        label: Text(roleLabel(r)),
                        selected: _role == r,
                        onSelected: (sel) => sel ? setState(() => _role = r) : null,
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text('Assigned projects', style: theme.textTheme.labelLarge),
                Text(
                  _role == UserRole.siteUser
                      ? 'Pick the site this user is responsible for.'
                      : _role == UserRole.manager
                          ? 'Pick the projects this manager reviews.'
                          : 'Admins and Ops Excellence see all projects regardless.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                // Inline as a Column — the dialog itself is scrollable, so we
                // mustn't add a nested viewport here. ~25 projects is fine.
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surfaceContainerLow,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: projectsAsync.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.all(24),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(child: Text('Failed to load projects: $e')),
                            TextButton(
                              onPressed: () => ref.invalidate(_allProjectsProvider),
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      ),
                      data: (projects) => Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final p in projects)
                            CheckboxListTile(
                              dense: true,
                              value: _assignedProjectIds.contains(p.id),
                              title: Text('${p.code} — ${p.name}'),
                              subtitle: p.isActive ? null : const Text('Inactive'),
                              onChanged: (v) => setState(() {
                                if (v == true) {
                                  _assignedProjectIds.add(p.id);
                                } else {
                                  _assignedProjectIds.remove(p.id);
                                }
                              }),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                FormBuilderSwitch(
                  name: 'isActive',
                  title: const Text('Active'),
                  initialValue: u?.isActive ?? true,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: TextStyle(color: theme.colorScheme.error)),
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
              : Text(_editing ? 'Save' : 'Create'),
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
    final repo = ref.read(usersRepositoryProvider);
    final assigned = _assignedProjectIds.toList();
    final name = (v['name'] as String).trim();
    final email = (v['email'] as String).trim();
    final isActive = v['isActive'] as bool? ?? true;

    try {
      if (_editing) {
        await repo.update(
          widget.initial!.id,
          name: name,
          email: email,
          role: _role,
          assignedProjectIds: assigned,
          isActive: isActive,
        );
      } else {
        await repo.create(
          name: name,
          email: email,
          username: (v['username'] as String).trim(),
          password: v['password'] as String,
          role: _role,
          assignedProjectIds: assigned,
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
