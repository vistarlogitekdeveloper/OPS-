import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import 'dashboard_models.dart';

class DashboardsRepository {
  DashboardsRepository(this._dio);
  final Dio _dio;

  Future<ProjectScoresPage> projectScores({required String month}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/dashboards/projects-scores',
      queryParameters: {'month': month},
    );
    return ProjectScoresPage.fromJson(res.data!);
  }

  Future<MonthlyTrend> monthlyTrend({String? projectId, int months = 12}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/dashboards/monthly-trend',
      queryParameters: {
        'projectId': ?projectId,
        'months': months,
      },
    );
    return MonthlyTrend.fromJson(res.data!);
  }

  Future<ComplianceGrid> compliance({required String from, required String to}) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/dashboards/compliance',
      queryParameters: {'from': from, 'to': to},
    );
    return ComplianceGrid.fromJson(res.data!);
  }

  Future<Scorecard> me() async {
    final res = await _dio.get<Map<String, dynamic>>('/dashboards/me');
    return Scorecard.fromJson(res.data!);
  }
}

final dashboardsRepositoryProvider = Provider<DashboardsRepository>((ref) {
  return DashboardsRepository(ref.watch(apiClientProvider));
});

// ─── Future providers (auto-disposed when screens leave) ────────────────────

final projectScoresProvider =
    FutureProvider.autoDispose.family<ProjectScoresPage, String>((ref, month) {
  return ref.watch(dashboardsRepositoryProvider).projectScores(month: month);
});

final monthlyTrendProvider =
    FutureProvider.autoDispose.family<MonthlyTrend, String?>((ref, projectId) {
  return ref.watch(dashboardsRepositoryProvider).monthlyTrend(projectId: projectId);
});

class ComplianceRange {
  const ComplianceRange({required this.from, required this.to});
  final String from;
  final String to;

  @override
  bool operator ==(Object other) =>
      other is ComplianceRange && other.from == from && other.to == to;

  @override
  int get hashCode => Object.hash(from, to);
}

final complianceProvider =
    FutureProvider.autoDispose.family<ComplianceGrid, ComplianceRange>((ref, r) {
  return ref.watch(dashboardsRepositoryProvider).compliance(from: r.from, to: r.to);
});

final scorecardProvider = FutureProvider.autoDispose<Scorecard>((ref) {
  return ref.watch(dashboardsRepositoryProvider).me();
});
