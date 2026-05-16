import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/page_result.dart';
import '../../../auth/data/auth_models.dart';
import '../data/users_repository.dart';

class UsersListController extends AsyncNotifier<PageResult<AuthUser>> {
  String? _search;
  UserRole? _role;
  bool? _isActive;
  int _page = 1;
  final int _pageSize = 50;

  @override
  Future<PageResult<AuthUser>> build() {
    final repo = ref.read(usersRepositoryProvider);
    return repo.list(
      page: _page,
      pageSize: _pageSize,
      search: _search,
      role: _role,
      isActive: _isActive,
    );
  }

  Future<void> setSearch(String? value) async {
    _search = (value == null || value.trim().isEmpty) ? null : value.trim();
    _page = 1;
    ref.invalidateSelf();
    await future;
  }

  Future<void> setRoleFilter(UserRole? role) async {
    _role = role;
    _page = 1;
    ref.invalidateSelf();
    await future;
  }

  Future<void> setActiveFilter(bool? active) async {
    _isActive = active;
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

final usersListControllerProvider =
    AsyncNotifierProvider<UsersListController, PageResult<AuthUser>>(
        UsersListController.new);
