import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'category_model.dart';

class CategoriesRepository {
  CategoriesRepository(this._dio);
  final Dio _dio;

  Future<CategoryPage> list({int page = 1, int pageSize = 100, String? search}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/categories',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return CategoryPage.fromJson(res.data!);
  }

  Future<ReportCategory> create({
    required String name,
    required int maxMarks,
    required List<FileTypeCode> allowedFileTypes,
    required int displayOrder,
    bool isActive = true,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/categories', data: {
      'name': name,
      'maxMarks': maxMarks,
      'allowedFileTypes': allowedFileTypes.map(fileTypeToWire).toList(),
      'displayOrder': displayOrder,
      'isActive': isActive,
    });
    return ReportCategory.fromJson(res.data!['category'] as Map<String, dynamic>);
  }

  Future<ReportCategory> update(
    String id, {
    String? name,
    int? maxMarks,
    List<FileTypeCode>? allowedFileTypes,
    int? displayOrder,
    bool? isActive,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>('/categories/$id', data: {
      'name': ?name,
      'maxMarks': ?maxMarks,
      if (allowedFileTypes != null)
        'allowedFileTypes': allowedFileTypes.map(fileTypeToWire).toList(),
      'displayOrder': ?displayOrder,
      'isActive': ?isActive,
    });
    return ReportCategory.fromJson(res.data!['category'] as Map<String, dynamic>);
  }

  Future<ReportCategory> deactivate(String id) async {
    final res = await _dio.delete<Map<String, dynamic>>('/categories/$id');
    return ReportCategory.fromJson(res.data!['category'] as Map<String, dynamic>);
  }
}

final categoriesRepositoryProvider = Provider<CategoriesRepository>((ref) {
  return CategoriesRepository(ref.watch(apiClientProvider));
});
