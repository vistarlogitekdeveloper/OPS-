import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../core/theme/vistar.dart';
import '../../../../core/vistar/widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../auth/application/auth_controller.dart';
import '../../../auth/data/auth_models.dart';
import '../application/users_controller.dart';
import '../data/users_repository.dart';
import 'set_password_dialog.dart';
import 'user_form_dialog.dart';

class UsersListScreen extends ConsumerWidget {
  const UsersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(usersListControllerProvider);
    final controller = ref.read(usersListControllerProvider.notifier);
    final currentUser = ref.watch(authControllerProvider).user;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search name, email, or username',
                    isDense: true,
                  ),
                  onSubmitted: controller.setSearch,
                ),
              ),
              const SizedBox(width: 12),
              _RoleFilter(onChanged: controller.setRoleFilter),
              const SizedBox(width: 12),
              RibbonButton(
                small: true,
                onPressed: () => _openCreate(context, ref),
                icon: Icons.add,
                label: 'New user',
              ),
            ],
          ),
          const SizedBox(height: 14),
          Expanded(
            child: AsyncValueView(
              value: async,
              onRetry: controller.refresh,
              data: (page) => RefreshIndicator(
                onRefresh: controller.refresh,
                child: page.items.isEmpty
                    ? const _Empty()
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: page.items.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 10),
                        itemBuilder: (context, i) {
                          final u = page.items[i];
                          final isSelf = currentUser?.id == u.id;
                          return _UserRow(
                            user: u,
                            isSelf: isSelf,
                            onEdit: () => _openEdit(context, ref, u),
                            onSetPassword: () => _setPassword(context, ref, u),
                            onDeactivate: isSelf || !u.isActive
                                ? null
                                : () => _deactivate(context, ref, u),
                          );
                        },
                      ),
              ),
            ),
          ),
          if (async.hasValue)
            _PageFooter(
              page: async.value!.page,
              pageCount: async.value!.pageCount,
              total: async.value!.total,
              onPage: controller.setPage,
            ),
        ],
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const UserFormDialog(),
    );
    if (created == true) {
      await ref.read(usersListControllerProvider.notifier).refresh();
    }
  }

  Future<void> _openEdit(
      BuildContext context, WidgetRef ref, AuthUser u) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => UserFormDialog(initial: u),
    );
    if (updated == true) {
      await ref.read(usersListControllerProvider.notifier).refresh();
    }
  }

  Future<void> _setPassword(
      BuildContext context, WidgetRef ref, AuthUser u) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => SetPasswordDialog(userId: u.id, username: u.username),
    );
    if (ok == true) {
      messenger.showSnackBar(
          SnackBar(content: Text('Password updated for ${u.username}.')));
    }
  }

  Future<void> _deactivate(
      BuildContext context, WidgetRef ref, AuthUser u) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Deactivate user?',
      message:
          '${u.name} (${u.username}) won\'t be able to log in. Existing sessions will be revoked.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(usersRepositoryProvider).deactivate(u.id);
      await ref.read(usersListControllerProvider.notifier).refresh();
      messenger.showSnackBar(SnackBar(content: Text('${u.username} deactivated.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
    }
  }
}

PillKind _pillForRole(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return PillKind.pink;
    case UserRole.manager:
      return PillKind.info;
    case UserRole.opsExcellence:
      return PillKind.violet;
    case UserRole.siteUser:
      return PillKind.amber;
    case UserRole.unknown:
      return PillKind.neutral;
  }
}

class _RoleFilter extends StatefulWidget {
  const _RoleFilter({required this.onChanged});
  final ValueChanged<UserRole?> onChanged;

  @override
  State<_RoleFilter> createState() => _RoleFilterState();
}

class _RoleFilterState extends State<_RoleFilter> {
  UserRole? _selected;

  @override
  Widget build(BuildContext context) {
    return DropdownButton<UserRole?>(
      value: _selected,
      hint: const Text('All roles'),
      items: const [
        DropdownMenuItem(value: null, child: Text('All roles')),
        DropdownMenuItem(value: UserRole.admin, child: Text('Admin')),
        DropdownMenuItem(value: UserRole.manager, child: Text('Manager')),
        DropdownMenuItem(value: UserRole.siteUser, child: Text('Site User')),
        DropdownMenuItem(
            value: UserRole.opsExcellence, child: Text('Ops Excellence')),
      ],
      onChanged: (v) {
        setState(() => _selected = v);
        widget.onChanged(v);
      },
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({
    required this.user,
    required this.isSelf,
    required this.onEdit,
    required this.onSetPassword,
    required this.onDeactivate,
  });
  final AuthUser user;
  final bool isSelf;
  final VoidCallback onEdit;
  final VoidCallback onSetPassword;
  final VoidCallback? onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VistarCard(
      onTap: onEdit,
      glow: true,
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      child: Row(
        children: [
          VistarAvatar(label: user.name, size: 44, gradient: user.isActive),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '${user.username} · ${user.email}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // Fixed-width slot for the role pill so right edges align across rows.
          SizedBox(
            width: 144,
            child: Align(
              alignment: Alignment.centerRight,
              child: RibbonPill(
                label: roleLabel(user.role).toUpperCase(),
                kind: _pillForRole(user.role),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Reserve a slot for the optional Inactive pill so the icon column stays put.
          SizedBox(
            width: 96,
            child: !user.isActive
                ? const Align(
                    alignment: Alignment.centerRight,
                    child: RibbonPill(
                        label: 'INACTIVE', kind: PillKind.neutral),
                  )
                : null,
          ),
          IconButton(
            tooltip: 'Set password',
            icon: const Icon(Icons.key_outlined),
            onPressed: onSetPassword,
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: isSelf
                ? 'You cannot deactivate your own account'
                : (user.isActive ? 'Deactivate' : 'Already inactive'),
            icon: const Icon(Icons.delete_outline),
            color: onDeactivate == null
                ? theme.colorScheme.onSurface.withValues(alpha: 0.3)
                : Vistar.bad,
            onPressed: onDeactivate,
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: VistarCard(
        cornerS: true,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.people_outline, size: 36, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              'No users match the current filters.',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _PageFooter extends StatelessWidget {
  const _PageFooter({
    required this.page,
    required this.pageCount,
    required this.total,
    required this.onPage,
  });
  final int page;
  final int pageCount;
  final int total;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            '$total total · page $page / $pageCount',
            style: TextStyle(
              color: theme.colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                onPressed: page > 1 ? () => onPage(page - 1) : null,
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                onPressed: page < pageCount ? () => onPage(page + 1) : null,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
