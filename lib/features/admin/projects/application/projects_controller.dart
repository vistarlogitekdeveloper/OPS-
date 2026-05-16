import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/page_result.dart';
import '../../../projects/data/project_model.dart';
import '../../../projects/data/projects_repository.dart';

class ProjectsListController extends AsyncNotifier<PageResult<Project>> {
  String? _search;
  int _page = 1;
  final int _pageSize = 50;

  @override
  Future<PageResult<Project>> build() {
    final repo = ref.read(projectsRepositoryProvider);
    return repo.list(page: _page, pageSize: _pageSize, search: _search);
  }

  Future<void> setSearch(String? value) async {
    _search = (value == null || value.trim().isEmpty) ? null : value.trim();
    _page = 1;
    ref.invalidateSelf();
    await future;
  }

  Future<void> setPage(int page) async {
    _page = page;
    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final projectsListControllerProvider =
    AsyncNotifierProvider<ProjectsListController, PageResult<Project>>(
        ProjectsListController.new);
