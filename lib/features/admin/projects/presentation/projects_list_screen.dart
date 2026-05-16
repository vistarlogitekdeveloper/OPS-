import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../projects/data/project_model.dart';
import '../../../projects/data/projects_repository.dart';
import '../application/projects_controller.dart';
import 'project_form_dialog.dart';

class ProjectsListScreen extends ConsumerWidget {
  const ProjectsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(projectsListControllerProvider);
    final controller = ref.read(projectsListControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Search by name, code, or location',
                    isDense: true,
                  ),
                  onSubmitted: controller.setSearch,
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () => _openCreate(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('New project'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Expanded(
            child: AsyncValueView(
              value: async,
              onRetry: controller.refresh,
              data: (page) => RefreshIndicator(
                onRefresh: controller.refresh,
                child: page.items.isEmpty
                    ? const _Empty()
                    : ListView.separated(
                        itemCount: page.items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) => _ProjectRow(
                          project: page.items[i],
                          onEdit: () => _openEdit(context, ref, page.items[i]),
                          onDeactivate: () => _deactivate(context, ref, page.items[i]),
                        ),
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
      builder: (ctx) => const ProjectFormDialog(),
    );
    if (created == true) {
      await ref.read(projectsListControllerProvider.notifier).refresh();
    }
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref, Project p) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => ProjectFormDialog(initial: p),
    );
    if (updated == true) {
      await ref.read(projectsListControllerProvider.notifier).refresh();
    }
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref, Project p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Deactivate project?',
      message: '"${p.name}" (${p.code}) will be hidden from new submissions. History is preserved.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(projectsRepositoryProvider).deactivate(p.id);
      await ref.read(projectsListControllerProvider.notifier).refresh();
      messenger.showSnackBar(SnackBar(content: Text('${p.code} deactivated.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
    }
  }
}

class _ProjectRow extends StatelessWidget {
  const _ProjectRow({required this.project, required this.onEdit, required this.onDeactivate});
  final Project project;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: project.isActive
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Icon(
          project.isActive ? Icons.business : Icons.block,
          color: project.isActive
              ? theme.colorScheme.onPrimaryContainer
              : theme.colorScheme.onSurfaceVariant,
        ),
      ),
      title: Text(project.name),
      subtitle: Text([project.code, if (project.location != null) project.location].join(' · ')),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!project.isActive)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Inactive'),
                visualDensity: VisualDensity.compact,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
              ),
            ),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
          if (project.isActive)
            IconButton(
              icon: const Icon(Icons.delete_outline),
              color: theme.colorScheme.error,
              onPressed: onDeactivate,
            ),
        ],
      ),
      onTap: onEdit,
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No projects yet. Tap "New project" to add one.'));
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
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('$total total · page $page / $pageCount'),
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
