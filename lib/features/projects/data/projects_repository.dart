import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/page_result.dart';
import '../../../core/network/api_client.dart';
import 'project_model.dart';

class ProjectsRepository {
  ProjectsRepository(this._dio);
  final Dio _dio;

  Future<PageResult<Project>> list({
    int page = 1,
    int pageSize = 50,
    String? search,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/projects',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
      },
    );
    return PageResult.fromJson<Project>(res.data!, Project.fromJson);
  }

  Future<Project> create({
    required String name,
    required String code,
    String? location,
    String? inchargeName,
    String? inchargeEmail,
    String? inchargePhone,
    bool isActive = true,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/projects', data: {
      'name': name,
      'code': code,
      if (location != null && location.isNotEmpty) 'location': location,
      if (inchargeName != null && inchargeName.isNotEmpty) 'inchargeName': inchargeName,
      if (inchargeEmail != null && inchargeEmail.isNotEmpty) 'inchargeEmail': inchargeEmail,
      if (inchargePhone != null && inchargePhone.isNotEmpty) 'inchargePhone': inchargePhone,
      'isActive': isActive,
    });
    return Project.fromJson(res.data!['project'] as Map<String, dynamic>);
  }

  Future<Project> update(
    String id, {
    String? name,
    String? code,
    String? location,
    String? inchargeName,
    String? inchargeEmail,
    String? inchargePhone,
    bool? isActive,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>('/projects/$id', data: {
      'name': ?name,
      'code': ?code,
      'location': ?location,
      'inchargeName': ?inchargeName,
      'inchargeEmail': ?inchargeEmail,
      'inchargePhone': ?inchargePhone,
      'isActive': ?isActive,
    });
    return Project.fromJson(res.data!['project'] as Map<String, dynamic>);
  }

  Future<Project> deactivate(String id) async {
    final res = await _dio.delete<Map<String, dynamic>>('/projects/$id');
    return Project.fromJson(res.data!['project'] as Map<String, dynamic>);
  }
}

final projectsRepositoryProvider = Provider<ProjectsRepository>((ref) {
  return ProjectsRepository(ref.watch(apiClientProvider));
});
