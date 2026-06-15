import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../core/theme/vistar.dart';
import '../../../../core/vistar/widgets.dart';
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
                    hintText: 'Search by name, code, or location',
                    isDense: true,
                  ),
                  onSubmitted: controller.setSearch,
                ),
              ),
              const SizedBox(width: 12),
              RibbonButton(
                small: true,
                onPressed: () => _openCreate(context, ref),
                icon: Icons.add,
                label: 'New project',
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
                        itemBuilder: (context, i) => _ProjectRow(
                          project: page.items[i],
                          onEdit: () =>
                              _openEdit(context, ref, page.items[i]),
                          onDeactivate: () =>
                              _deactivate(context, ref, page.items[i]),
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

  Future<void> _openEdit(
      BuildContext context, WidgetRef ref, Project p) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => ProjectFormDialog(initial: p),
    );
    if (updated == true) {
      await ref.read(projectsListControllerProvider.notifier).refresh();
    }
  }

  Future<void> _deactivate(
      BuildContext context, WidgetRef ref, Project p) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Deactivate project?',
      message:
          '"${p.name}" (${p.code}) will be hidden from new submissions. History is preserved.',
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
  const _ProjectRow({
    required this.project,
    required this.onEdit,
    required this.onDeactivate,
  });
  final Project project;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return VistarCard(
      onTap: onEdit,
      glow: true,
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: project.isActive ? Vistar.ribbon : null,
              color: project.isActive
                  ? null
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              project.isActive ? Icons.business : Icons.block,
              size: 20,
              color: project.isActive
                  ? Colors.white
                  : theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  project.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [project.code, if (project.location != null) project.location]
                      .join(' · '),
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
          if (!project.isActive)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: RibbonPill(label: 'INACTIVE', kind: PillKind.neutral),
            ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          if (project.isActive)
            IconButton(
              tooltip: 'Deactivate',
              icon: const Icon(Icons.delete_outline, color: Vistar.bad),
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
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 40),
        Center(
          child: VistarCard(
            cornerS: true,
            padding:
                const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business_outlined,
                    size: 36, color: theme.hintColor),
                const SizedBox(height: 12),
                Text(
                  'No projects yet.',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  'Tap "New project" to add one.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
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
