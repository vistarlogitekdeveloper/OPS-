import 'package:flutter/material.dart';
import 'package:flutter_form_builder/flutter_form_builder.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:form_builder_validators/form_builder_validators.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../core/vistar/widgets.dart';
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
  /// Every role this employee holds, in pick order. The first is the primary
  /// one (what the server stores in `role` and what a single-role view shows),
  /// so order is preserved rather than using a Set.
  late List<UserRole> _roles;
  late Set<String> _assignedProjectIds;

  bool get _editing => widget.initial != null;

  /// The roles that work on assigned sites. Shown so the project list explains
  /// itself for whichever of the user's hats actually needs it.
  static const _siteRoles = [
    UserRole.siteUser,
    UserRole.manager,
    UserRole.clusterManager,
  ];

  @override
  void initState() {
    super.initState();
    final u = widget.initial;
    _roles = u == null ? [UserRole.siteUser] : List.of(u.roles);
    if (_roles.isEmpty) _roles = [UserRole.siteUser];
    _assignedProjectIds = (u?.assignedProjectIds ?? const []).toSet();
  }

  /// Toggles a hat. The last one cannot be removed — a user with no role could
  /// sign in and do nothing, and the server rejects an empty list anyway.
  void _toggleRole(UserRole r, bool selected) {
    setState(() {
      if (selected) {
        if (!_roles.contains(r)) _roles.add(r);
      } else if (_roles.length > 1) {
        _roles.remove(r);
      }
    });
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
                Text('Roles', style: theme.textTheme.labelLarge),
                Text(
                  _roles.length > 1
                      ? 'This employee holds ${_roles.length} roles and can do everything all of them allow. '
                          '${roleLabel(_roles.first)} is their primary role.'
                      : 'Pick one or more. An employee holding several roles can do everything all of them allow.',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final r in const [
                      UserRole.admin,
                      UserRole.manager,
                      UserRole.clusterManager,
                      UserRole.siteUser,
                      UserRole.opsExcellence,
                    ])
                      FilterChip(
                        label: Text(roleLabel(r)),
                        selected: _roles.contains(r),
                        // The last remaining role cannot be unpicked.
                        onSelected: _roles.length == 1 && _roles.contains(r)
                            ? null
                            : (sel) => _toggleRole(r, sel),
                      ),
                  ],
                ),
                // Someone who both files reports and approves them cannot
                // approve their OWN — the server refuses it — so say so here
                // rather than letting an admin build a combination that
                // silently does less than they expect.
                if (_roles.contains(UserRole.clusterManager) &&
                    _roles.any((r) =>
                        r == UserRole.manager || r == UserRole.siteUser)) ...[
                  const SizedBox(height: 8),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, size: 15, color: theme.hintColor),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'This user both files and approves reports. They will not be able '
                          'to approve reports they filed themselves — another cluster manager '
                          'on the site must.',
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Text('Assigned projects', style: theme.textTheme.labelLarge),
                Text(
                  switch (_roles.where(_siteRoles.contains).toList()) {
                    [] => 'Admins and Ops Excellence see all projects regardless.',
                    final site => 'Pick the sites this user works on as '
                        '${site.map(roleLabel).join(' and ')}.',
                  },
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
          roles: _roles,
          assignedProjectIds: assigned,
          isActive: isActive,
        );
      } else {
        await repo.create(
          name: name,
          email: email,
          username: (v['username'] as String).trim(),
          password: v['password'] as String,
          roles: _roles,
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
