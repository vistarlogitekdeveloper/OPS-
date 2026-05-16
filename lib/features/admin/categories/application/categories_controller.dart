import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../categories/data/categories_repository.dart';
import '../../../categories/data/category_model.dart';

class CategoriesListController extends AsyncNotifier<CategoryPage> {
  String? _search;

  @override
  Future<CategoryPage> build() {
    final repo = ref.read(categoriesRepositoryProvider);
    return repo.list(search: _search);
  }

  Future<void> setSearch(String? value) async {
    _search = (value == null || value.trim().isEmpty) ? null : value.trim();
    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final categoriesListControllerProvider =
    AsyncNotifierProvider<CategoriesListController, CategoryPage>(
        CategoriesListController.new);
