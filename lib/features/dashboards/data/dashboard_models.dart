import '../../projects/data/project_model.dart';
import '../../submissions/data/submission_models.dart';

/// Per-site dashboard payload (`GET /dashboards/site/:projectId`).
class SiteTrendPoint {
  const SiteTrendPoint({required this.month, required this.totalScore, this.status});
  final String month;
  final int totalScore;
  final SubmissionStatus? status;

  factory SiteTrendPoint.fromJson(Map<String, dynamic> j) => SiteTrendPoint(
        month: j['month'] as String,
        totalScore: j['totalScore'] as int? ?? 0,
        status: j['status'] == null ? null : submissionStatusFromWire(j['status'] as String),
      );
}

class SiteCompliancePoint {
  const SiteCompliancePoint({required this.month, required this.percent});
  final String month;
  final int? percent;

  factory SiteCompliancePoint.fromJson(Map<String, dynamic> j) => SiteCompliancePoint(
        month: j['month'] as String,
        percent: j['percent'] as int?,
      );
}

class SiteCategoryMark {
  const SiteCategoryMark({
    required this.categoryName,
    required this.maxMarks,
    required this.awardedMarks,
    required this.status,
  });
  final String categoryName;
  final int maxMarks;
  final int? awardedMarks;
  final SubmissionItemStatus status;

  factory SiteCategoryMark.fromJson(Map<String, dynamic> j) => SiteCategoryMark(
        categoryName: j['categoryName'] as String,
        maxMarks: j['maxMarks'] as int? ?? 0,
        awardedMarks: j['awardedMarks'] as int?,
        status: itemStatusFromWire(j['status'] as String),
      );
}

class SiteDashboard {
  const SiteDashboard({
    required this.project,
    required this.latestMonth,
    required this.latestStatus,
    required this.latestScore,
    required this.trend,
    required this.compliance,
    required this.breakdown,
  });

  final Project project;
  final String? latestMonth;
  final SubmissionStatus? latestStatus;
  final int? latestScore;
  final List<SiteTrendPoint> trend;
  final List<SiteCompliancePoint> compliance;
  final List<SiteCategoryMark> breakdown;

  factory SiteDashboard.fromJson(Map<String, dynamic> j) {
    final latest = j['latest'] as Map<String, dynamic>?;
    return SiteDashboard(
      project: Project.fromJson(j['project'] as Map<String, dynamic>),
      latestMonth: latest?['month'] as String?,
      latestStatus: latest?['status'] == null
          ? null
          : submissionStatusFromWire(latest!['status'] as String),
      latestScore: latest?['totalScore'] as int?,
      trend: (j['trend'] as List<dynamic>? ?? [])
          .map((e) => SiteTrendPoint.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      compliance: (j['compliance'] as List<dynamic>? ?? [])
          .map((e) => SiteCompliancePoint.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
      breakdown: (j['categoryBreakdown'] as List<dynamic>? ?? [])
          .map((e) => SiteCategoryMark.fromJson(e as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}

class ProjectScoreRow {
  const ProjectScoreRow({
    required this.projectId,
    required this.code,
    required this.name,
    required this.totalScore,
    required this.status,
  });

  final String projectId;
  final String code;
  final String name;
  final int totalScore;

  /// Wire string: `DRAFT`, `SUBMITTED`, `APPROVED`, `REJECTED`, or `NONE`.
  final String status;

  factory ProjectScoreRow.fromJson(Map<String, dynamic> j) => ProjectScoreRow(
        projectId: j['projectId'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        totalScore: j['totalScore'] as int? ?? 0,
        status: (j['status'] as String?) ?? 'NONE',
      );
}

class ProjectScoresPage {
  const ProjectScoresPage({required this.month, required this.items});
  final String month;
  final List<ProjectScoreRow> items;

  factory ProjectScoresPage.fromJson(Map<String, dynamic> j) => ProjectScoresPage(
        month: j['month'] as String,
        items: (j['items'] as List<dynamic>)
            .map((e) => ProjectScoreRow.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class TrendPoint {
  const TrendPoint({
    required this.month,
    required this.averageScore,
    required this.sampleSize,
  });
  final String month;
  final double averageScore;
  final int sampleSize;

  factory TrendPoint.fromJson(Map<String, dynamic> j) => TrendPoint(
        month: j['month'] as String,
        averageScore: (j['averageScore'] as num).toDouble(),
        sampleSize: j['sampleSize'] as int? ?? 0,
      );
}

class MonthlyTrend {
  const MonthlyTrend({required this.projectId, required this.points});
  final String? projectId;
  final List<TrendPoint> points;

  factory MonthlyTrend.fromJson(Map<String, dynamic> j) => MonthlyTrend(
        projectId: j['projectId'] as String?,
        points: (j['points'] as List<dynamic>)
            .map((e) => TrendPoint.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class ComplianceCell {
  const ComplianceCell({required this.month, required this.percent, required this.status});
  final String month;
  final int? percent;
  final String? status;

  factory ComplianceCell.fromJson(Map<String, dynamic> j) => ComplianceCell(
        month: j['month'] as String,
        percent: j['percent'] as int?,
        status: j['status'] as String?,
      );
}

class ComplianceRow {
  const ComplianceRow({
    required this.projectId,
    required this.code,
    required this.name,
    required this.cells,
  });
  final String projectId;
  final String code;
  final String name;
  final List<ComplianceCell> cells;

  factory ComplianceRow.fromJson(Map<String, dynamic> j) => ComplianceRow(
        projectId: j['projectId'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        cells: (j['cells'] as List<dynamic>)
            .map((e) => ComplianceCell.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class ComplianceGrid {
  const ComplianceGrid({required this.months, required this.projects});
  final List<String> months;
  final List<ComplianceRow> projects;

  factory ComplianceGrid.fromJson(Map<String, dynamic> j) => ComplianceGrid(
        months: (j['months'] as List<dynamic>).cast<String>(),
        projects: (j['projects'] as List<dynamic>)
            .map((e) => ComplianceRow.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class ScorecardMonth {
  const ScorecardMonth({required this.month, required this.status, required this.totalScore});
  final String month;
  final SubmissionStatus? status;
  final int? totalScore;

  factory ScorecardMonth.fromJson(Map<String, dynamic> j) => ScorecardMonth(
        month: j['month'] as String,
        status: j['status'] == null ? null : submissionStatusFromWire(j['status'] as String),
        totalScore: j['totalScore'] as int?,
      );
}

class ScorecardCycle {
  const ScorecardCycle({
    required this.projectId,
    required this.code,
    required this.name,
    required this.months,
  });
  final String projectId;
  final String code;
  final String name;
  final List<ScorecardMonth> months;

  factory ScorecardCycle.fromJson(Map<String, dynamic> j) => ScorecardCycle(
        projectId: j['projectId'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        months: (j['months'] as List<dynamic>)
            .map((e) => ScorecardMonth.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class Scorecard {
  const Scorecard({required this.months, required this.cycles});
  final List<String> months;
  final List<ScorecardCycle> cycles;

  factory Scorecard.fromJson(Map<String, dynamic> j) => Scorecard(
        months: (j['months'] as List<dynamic>).cast<String>(),
        cycles: (j['cycles'] as List<dynamic>)
            .map((e) => ScorecardCycle.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}
