import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../core/theme/vistar.dart';
import '../../../../core/vistar/widgets.dart';
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
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (async.hasValue) _MarksBanner(page: async.value!),
          if (async.hasValue) const SizedBox(height: 14),
          Row(
            children: [
              const Spacer(),
              RibbonButton(
                small: true,
                onPressed: () => _openCreate(context, ref),
                icon: Icons.add,
                label: 'New category',
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
                        itemBuilder: (context, i) => _CategoryRow(
                          category: page.items[i],
                          onEdit: () =>
                              _openEdit(context, ref, page.items[i]),
                          onDeactivate: () =>
                              _deactivate(context, ref, page.items[i]),
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

  Future<void> _openEdit(
      BuildContext context, WidgetRef ref, ReportCategory c) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => CategoryFormDialog(initial: c),
    );
    if (updated == true) {
      await ref.read(categoriesListControllerProvider.notifier).refresh();
    }
  }

  Future<void> _deactivate(
      BuildContext context, WidgetRef ref, ReportCategory c) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Deactivate category?',
      message:
          '"${c.name}" will be hidden from new submissions. Past submissions keep their scores.',
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

    return VistarCard(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              gradient: Vistar.ribbon,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(
              atCap ? Icons.check_circle_outline : Icons.donut_large_outlined,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    RibbonText(
                      '${page.activeMarksSum}',
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        '/ ${page.maxTotalMarks}',
                        style: TextStyle(
                          color: theme.colorScheme.onSurfaceVariant,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'ACTIVE MARKS TOTAL',
                      style: TextStyle(
                        color: theme.hintColor,
                        fontSize: 10.5,
                        letterSpacing: 1.2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  atCap
                      ? 'Rubric is at full capacity. New categories will need others to give up marks.'
                      : 'Room for $remaining more marks across categories.',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    required this.category,
    required this.onEdit,
    required this.onDeactivate,
  });
  final ReportCategory category;
  final VoidCallback onEdit;
  final VoidCallback onDeactivate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final allowed = category.allowedFileTypes.map(fileTypeLabel).join(', ');
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
              gradient: category.isActive ? Vistar.ribbon : null,
              color: category.isActive
                  ? null
                  : theme.colorScheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${category.maxMarks}',
              style: TextStyle(
                color: category.isActive
                    ? Colors.white
                    : theme.colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  category.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$allowed · order ${category.displayOrder}',
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12.5,
                  ),
                ),
              ],
            ),
          ),
          if (!category.isActive)
            const Padding(
              padding: EdgeInsets.only(right: 6),
              child: RibbonPill(label: 'INACTIVE', kind: PillKind.neutral),
            ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit_outlined),
            onPressed: onEdit,
          ),
          if (category.isActive)
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
    return Center(
      child: VistarCard(
        cornerS: true,
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.category_outlined,
                size: 36, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              'No categories.',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}
