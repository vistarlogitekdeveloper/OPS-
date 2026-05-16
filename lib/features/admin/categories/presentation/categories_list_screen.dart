import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../categories/data/categories_repository.dart';
import '../../../categories/data/category_model.dart';
import '../application/categories_controller.dart';
import 'category_form_dialog.dart';

class CategoriesListScreen extends ConsumerWidget {
  const CategoriesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(categoriesListControllerProvider);
    final controller = ref.read(categoriesListControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (async.hasValue) _MarksBanner(page: async.value!),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(child: SizedBox.shrink()),
              FilledButton.icon(
                onPressed: () => _openCreate(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('New category'),
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
                    ? const Center(child: Text('No categories.'))
                    : ListView.separated(
                        itemCount: page.items.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) => _CategoryRow(
                          category: page.items[i],
                          onEdit: () => _openEdit(context, ref, page.items[i]),
                          onDeactivate: () => _deactivate(context, ref, page.items[i]),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final created = await showDialog<bool>(
      context: context,
      builder: (ctx) => const CategoryFormDialog(),
    );
    if (created == true) {
      await ref.read(categoriesListControllerProvider.notifier).refresh();
    }
  }

  Future<void> _openEdit(BuildContext context, WidgetRef ref, ReportCategory c) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => CategoryFormDialog(initial: c),
    );
    if (updated == true) {
      await ref.read(categoriesListControllerProvider.notifier).refresh();
    }
  }

  Future<void> _deactivate(BuildContext context, WidgetRef ref, ReportCategory c) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Deactivate category?',
      message: '"${c.name}" will be hidden from new submissions. Past submissions keep their scores.',
      confirmLabel: 'Deactivate',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(categoriesRepositoryProvider).deactivate(c.id);
      await ref.read(categoriesListControllerProvider.notifier).refresh();
      messenger.showSnackBar(SnackBar(content: Text('${c.name} deactivated.')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
    }
  }
}

class _MarksBanner extends StatelessWidget {
  const _MarksBanner({required this.page});
  final CategoryPage page;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final remaining = page.maxTotalMarks - page.activeMarksSum;
    final atCap = page.activeMarksSum >= page.maxTotalMarks;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: atCap
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(atCap ? Icons.check_circle_outline : Icons.info_outline,
              color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Active marks total: ${page.activeMarksSum} / ${page.maxTotalMarks}'
              '${remaining == 0 ? "" : " (room for $remaining more)"}',
              style: TextStyle(color: theme.colorScheme.onPrimaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.category, required this.onEdit, required this.onDeactivate});
  final ReportCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allowed = category.allowedFileTypes.map(fileTypeLabel).join(', ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: category.isActive
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest,
        child: Text(category.maxMarks.toString(),
            style: TextStyle(
              color: category.isActive
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            )),
      ),
      title: Text(category.name),
      subtitle: Text('$allowed · order ${category.displayOrder}'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!category.isActive)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: const Text('Inactive'),
                visualDensity: VisualDensity.compact,
                backgroundColor: theme.colorScheme.surfaceContainerHigh,
              ),
            ),
          IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
          if (category.isActive)
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
