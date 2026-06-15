import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/vistar.dart';
import '../../../../core/vistar/widgets.dart';
import '../../../../core/widgets/async_value_view.dart';
import '../application/audit_controller.dart';
import '../data/audit_repository.dart';

class AuditListScreen extends ConsumerStatefulWidget {
  const AuditListScreen({super.key});

  @override
  ConsumerState<AuditListScreen> createState() => _AuditListScreenState();
}

class _AuditListScreenState extends ConsumerState<AuditListScreen> {
  final _actionCtrl = TextEditingController();
  final _entityTypeCtrl = TextEditingController();
  final _userIdCtrl = TextEditingController();

  @override
  void dispose() {
    _actionCtrl.dispose();
    _entityTypeCtrl.dispose();
    _userIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(auditListControllerProvider);
    final controller = ref.read(auditListControllerProvider.notifier);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _FilterBar(
            actionCtrl: _actionCtrl,
            entityTypeCtrl: _entityTypeCtrl,
            userIdCtrl: _userIdCtrl,
            onApply: () => controller.setFilters(AuditFilters(
              action: _actionCtrl.text.trim().isEmpty
                  ? null
                  : _actionCtrl.text.trim(),
              entityType: _entityTypeCtrl.text.trim().isEmpty
                  ? null
                  : _entityTypeCtrl.text.trim(),
              userId: _userIdCtrl.text.trim().isEmpty
                  ? null
                  : _userIdCtrl.text.trim(),
            )),
            onClear: () {
              _actionCtrl.clear();
              _entityTypeCtrl.clear();
              _userIdCtrl.clear();
              controller.setFilters(const AuditFilters());
            },
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
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) =>
                            _AuditRow(entry: page.items[i]),
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
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.actionCtrl,
    required this.entityTypeCtrl,
    required this.userIdCtrl,
    required this.onApply,
    required this.onClear,
  });
  final TextEditingController actionCtrl;
  final TextEditingController entityTypeCtrl;
  final TextEditingController userIdCtrl;
  final VoidCallback onApply;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 200,
          child: TextField(
            controller: actionCtrl,
            decoration: const InputDecoration(
              labelText: 'Action contains',
              isDense: true,
            ),
            onSubmitted: (_) => onApply(),
          ),
        ),
        SizedBox(
          width: 180,
          child: TextField(
            controller: entityTypeCtrl,
            decoration: const InputDecoration(
              labelText: 'Entity type',
              isDense: true,
            ),
            onSubmitted: (_) => onApply(),
          ),
        ),
        SizedBox(
          width: 220,
          child: TextField(
            controller: userIdCtrl,
            decoration: const InputDecoration(
              labelText: 'User ID',
              isDense: true,
            ),
            onSubmitted: (_) => onApply(),
          ),
        ),
        RibbonButton(
          small: true,
          onPressed: onApply,
          icon: Icons.filter_alt_outlined,
          label: 'Apply',
        ),
        OutlinedButton(onPressed: onClear, child: const Text('Clear')),
      ],
    );
  }
}

class _AuditRow extends StatelessWidget {
  const _AuditRow({required this.entry});
  final AuditEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final fmt = DateFormat('yyyy-MM-dd HH:mm:ss');
    final status = entry.metadata?['status'];
    final isError = entry.action.toLowerCase().contains('error') ||
        entry.action.toLowerCase().contains('failure') ||
        (status is String && status.toLowerCase() == 'error');

    return VistarCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: (isError ? Vistar.bad : Vistar.violet).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isError ? Icons.error_outline : Icons.history,
              size: 18,
              color: isError ? Vistar.bad : Vistar.violet,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  entry.action,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontFamily: 'monospace',
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    fmt.format(entry.timestamp.toLocal()),
                    if (entry.username != null) 'by ${entry.username}',
                    'type: ${entry.entityType}',
                    if (status != null) 'status: $status',
                    if (entry.ipAddress != null) 'ip: ${entry.ipAddress}',
                  ].join(' · '),
                  style: TextStyle(
                    color: theme.colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
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
            Icon(Icons.history_outlined, size: 36, color: theme.hintColor),
            const SizedBox(height: 12),
            Text(
              'No audit entries match the filters.',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
              textAlign: TextAlign.center,
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
