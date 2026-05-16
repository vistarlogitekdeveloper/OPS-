import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/widgets/async_value_view.dart';
import '../../auth/application/auth_controller.dart';
import '../../auth/data/auth_models.dart';
import '../../projects/data/project_model.dart';
import '../../projects/data/projects_repository.dart';
import '../application/cycle_controller.dart';

final _siteProjectsProvider = FutureProvider<List<Project>>((ref) async {
  final user = ref.watch(authControllerProvider).user;
  final all = await ref.watch(projectsRepositoryProvider).list(pageSize: 200);
  if (user == null) return const [];
  if (user.role == UserRole.admin || user.role == UserRole.opsExcellence) {
    return all.items.where((p) => p.isActive).toList();
  }
  final assigned = user.assignedProjectIds.toSet();
  return all.items.where((p) => p.isActive && assigned.contains(p.id)).toList();
});

class CyclePickerScreen extends ConsumerStatefulWidget {
  const CyclePickerScreen({super.key});

  @override
  ConsumerState<CyclePickerScreen> createState() => _CyclePickerScreenState();
}

class _CyclePickerScreenState extends ConsumerState<CyclePickerScreen> {
  String? _projectId;
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final projectsAsync = ref.watch(_siteProjectsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('New / open submission'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: AsyncValueView(
              value: projectsAsync,
              data: (projects) {
                if (projects.isEmpty) {
                  return Center(
                    child: Text(
                      'No projects assigned. Ask an admin to assign you a site.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                if (_projectId == null && projects.length == 1) {
                  _projectId = projects.first.id;
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text('Choose a project and month',
                            style: theme.textTheme.titleMedium),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<String>(
                          initialValue: _projectId,
                          decoration: const InputDecoration(labelText: 'Project'),
                          items: [
                            for (final p in projects)
                              DropdownMenuItem(
                                value: p.id,
                                child: Text('${p.code} — ${p.name}'),
                              ),
                          ],
                          onChanged: (v) => setState(() => _projectId = v),
                        ),
                        const SizedBox(height: 16),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Month'),
                          subtitle: Text(DateFormat.yMMMM().format(_month)),
                          trailing: const Icon(Icons.calendar_today_outlined),
                          onTap: _pickMonth,
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _projectId == null ? null : _open,
                          child: const Text('Open'),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickMonth() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _month,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 2, 12),
      initialDatePickerMode: DatePickerMode.year,
      helpText: 'Select reporting month',
    );
    if (picked != null) {
      setState(() => _month = DateTime(picked.year, picked.month));
    }
  }

  void _open() {
    final monthStr = '${_month.year.toString().padLeft(4, '0')}-'
        '${_month.month.toString().padLeft(2, '0')}';
    ref.read(cycleSelectionProvider.notifier).state =
        CycleSelection(projectId: _projectId!, month: monthStr);
    context.go('/submission');
  }
}
