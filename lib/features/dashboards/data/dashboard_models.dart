import '../../submissions/data/submission_models.dart';

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
