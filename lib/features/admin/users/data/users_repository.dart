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
    String? roleParam;
    switch (role) {
      case UserRole.admin:
        roleParam = 'ADMIN';
        break;
      case UserRole.manager:
        roleParam = 'MANAGER';
        break;
      case UserRole.siteUser:
        roleParam = 'SITE_USER';
        break;
      case UserRole.opsExcellence:
        roleParam = 'OPS_EXCELLENCE';
        break;
      case UserRole.unknown:
      case null:
        roleParam = null;
        break;
    }
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
    required UserRole role,
    required List<String> assignedProjectIds,
    bool isActive = true,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>('/users', data: {
      'name': name,
      'email': email,
      'username': username,
      'password': password,
      'role': _roleWire(role),
      'assignedProjectIds': assignedProjectIds,
      'isActive': isActive,
    });
    return AuthUser.fromJson(res.data!['user'] as Map<String, dynamic>);
  }

  Future<AuthUser> update(
    String id, {
    String? name,
    String? email,
    UserRole? role,
    List<String>? assignedProjectIds,
    bool? isActive,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>('/users/$id', data: {
      'name': ?name,
      'email': ?email,
      'role': ?(role == null ? null : _roleWire(role)),
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
        UserRole.siteUser => 'SITE_USER',
        UserRole.opsExcellence => 'OPS_EXCELLENCE',
        UserRole.unknown => throw ArgumentError('Cannot send "unknown" role'),
      };
}

final usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.watch(apiClientProvider));
});
