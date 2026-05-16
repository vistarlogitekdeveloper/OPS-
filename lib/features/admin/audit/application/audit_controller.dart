import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/page_result.dart';
import '../data/audit_repository.dart';

class AuditListController extends AsyncNotifier<PageResult<AuditEntry>> {
  AuditFilters _filters = const AuditFilters();
  int _page = 1;
  final int _pageSize = 50;

  @override
  Future<PageResult<AuditEntry>> build() {
    return ref.read(auditRepositoryProvider).list(
          page: _page,
          pageSize: _pageSize,
          filters: _filters,
        );
  }

  Future<void> setFilters(AuditFilters f) async {
    _filters = f;
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

final auditListControllerProvider =
    AsyncNotifierProvider<AuditListController, PageResult<AuditEntry>>(
        AuditListController.new);
