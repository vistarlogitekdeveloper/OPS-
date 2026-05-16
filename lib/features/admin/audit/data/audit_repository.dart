import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/models/page_result.dart';
import '../../../../core/network/api_client.dart';

class AuditEntry {
  const AuditEntry({
    required this.id,
    required this.userId,
    required this.username,
    required this.action,
    required this.entityType,
    required this.entityId,
    required this.ipAddress,
    required this.timestamp,
    required this.metadata,
  });

  final String id;
  final String? userId;
  final String? username;
  final String action;
  final String entityType;
  final String? entityId;
  final String? ipAddress;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  factory AuditEntry.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>?;
    return AuditEntry(
      id: j['id'] as String,
      userId: j['userId'] as String?,
      username: user?['username'] as String?,
      action: j['action'] as String,
      entityType: j['entityType'] as String,
      entityId: j['entityId'] as String?,
      ipAddress: j['ipAddress'] as String?,
      timestamp: DateTime.parse(j['timestamp'] as String),
      metadata: (j['metadata'] as Map?)?.cast<String, dynamic>(),
    );
  }
}

class AuditFilters {
  const AuditFilters({this.action, this.entityType, this.userId});
  final String? action;
  final String? entityType;
  final String? userId;

  @override
  bool operator ==(Object other) =>
      other is AuditFilters &&
      other.action == action &&
      other.entityType == entityType &&
      other.userId == userId;

  @override
  int get hashCode => Object.hash(action, entityType, userId);
}

class AuditRepository {
  AuditRepository(this._dio);
  final Dio _dio;

  Future<PageResult<AuditEntry>> list({
    int page = 1,
    int pageSize = 50,
    AuditFilters filters = const AuditFilters(),
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/audit',
      queryParameters: {
        'page': page,
        'pageSize': pageSize,
        'action': ?filters.action,
        'entityType': ?filters.entityType,
        'userId': ?filters.userId,
      },
    );
    return PageResult.fromJson<AuditEntry>(res.data!, AuditEntry.fromJson);
  }
}

final auditRepositoryProvider = Provider<AuditRepository>((ref) {
  return AuditRepository(ref.watch(apiClientProvider));
});
