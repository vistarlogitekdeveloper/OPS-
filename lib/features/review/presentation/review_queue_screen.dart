import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/async_value_view.dart';
import '../../submissions/data/submission_models.dart';
import '../application/review_controllers.dart';

class ReviewQueueScreen extends ConsumerWidget {
  const ReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(reviewQueueProvider);
    final controller = ref.read(reviewQueueProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review queue'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: AsyncValueView(
        value: async,
        onRetry: controller.refresh,
        data: (page) => RefreshIndicator(
          onRefresh: controller.refresh,
          child: page.items.isEmpty
              ? const _Empty()
              : ListView.separated(
                  itemCount: page.items.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, i) => _QueueRow(
                    submission: page.items[i],
                    onOpen: () => context.go('/review/${page.items[i].id}'),
                  ),
                ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        const SizedBox(height: 80),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              'Nothing awaiting review.',
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ],
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({required this.submission, required this.onOpen});
  final Submission submission;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final project = submission.project;
    final title = project == null
        ? submission.month
        : '${project.code} — ${submission.month}';
    final subtitle = [
      project?.name ?? '',
      'Items: ${submission.items.length}',
      if (submission.submittedAt != null)
        'Submitted: ${submission.submittedAt!.toLocal().toString().split('.').first}',
    ].where((s) => s.isNotEmpty).join(' · ');

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: theme.colorScheme.secondaryContainer,
        child: Icon(Icons.inbox_outlined, color: theme.colorScheme.onSecondaryContainer),
      ),
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onOpen,
    );
  }
}
