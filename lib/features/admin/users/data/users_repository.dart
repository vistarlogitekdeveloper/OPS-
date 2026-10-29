import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/page_result.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/data/auth_models.dart';

class UsersRepository {
  UsersRepository(this._dio);
  final Dio _dio;

  Future<PageResult<AuthUser>> list({
    int page = 1,
    int pageSize = 50,
    String? search,
    UserRole? role,
    bool? isActive,
  }) async {
    // The server matches this against every role a user holds, not just their
    // primary one, so filtering by "Cluster Manager" also finds a project
    // manager who wears that hat too.
    final roleParam = (role == null || role == UserRole.unknown) ? null : _roleWire(role);
    final res = await _dio.get<Map<String, dynamic>>(
      '/users',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        if (search != null && search.isNotEmpty) 'search': search,
        'role': ?roleParam,
        'isActive': ?(isActive == null ? null : (isActive ? 'true' : 'false')),
      },
    );
    return PageResult.fromJson<AuthUser>(res.data!, AuthUser.fromJson);
  }

  Future<AuthUser> create({
    required String name,
    required String email,
    required String username,
    required String password,
    /// Every role the employee holds, most important first. Never empty.
    required List<UserRole> roles,
    required List<String> assignedProjectIds,
    bool isActive = true,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/users', data: {
      'name': name,
      'email': email,
      'username': username,
      'password': password,
      'roles': roles.map(_roleWire).toList(),
      // `role` alongside `roles` so this build also works against a backend
      // that predates multi-role: it reads `role` and ignores the rest.
      'role': _roleWire(roles.first),
      'assignedProjectIds': assignedProjectIds,
      'isActive': isActive,
    });
    return AuthUser.fromJson(res.data!['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> update(
    String id, {
    String? name,
    String? email,
    /// The full new set of roles, or null to leave them untouched.
    List<UserRole>? roles,
    List<String>? assignedProjectIds,
    bool? isActive,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>('/users/$id', data: {
      'name': ?name,
      'email': ?email,
      'roles': ?roles?.map(_roleWire).toList(),
      // As in create: the single-role spelling for an older backend.
      'role': ?(roles == null ? null : _roleWire(roles.first)),
      'assignedProjectIds': ?assignedProjectIds,
      'isActive': ?isActive,
    });
    return AuthUser.fromJson(res.data!['user'] as Map<String, dynamic>);
  }

  Future<void> setPassword(String id, String newPassword) async {
    await _dio.post<void>(
      '/users/$id/password',
      data: {'newPassword': newPassword},
      options: Options(validateStatus: (s) => s == 204 || (s != null && s >= 200 && s < 300)),
    );
  }

  Future<AuthUser> deactivate(String id) async {
    final res = await _dio.delete<Map<String, dynamic>>('/users/$id');
    return AuthUser.fromJson(res.data!['user'] as Map<String, dynamic>);
  }

  static String _roleWire(UserRole r) => switch (r) {
        UserRole.admin => 'ADMIN',
        UserRole.manager => 'MANAGER',
        UserRole.clusterManager => 'CLUSTER_MANAGER',
        UserRole.siteUser => 'SITE_USER',
        UserRole.opsExcellence => 'OPS_EXCELLENCE',
        UserRole.unknown => throw ArgumentError('Cannot send "unknown" role'),
      };
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(apiClientProvider));
});
