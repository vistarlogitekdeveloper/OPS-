import '../../submissions/data/submission_models.dart';

/// Payload of `GET /dashboards/ops-summary?month=YYYY-MM`.
///
/// One month of the Ops Excellence cycle review, shaped as a matrix: every
/// active site is a row, every report category a column. It carries both
/// views the team used to keep in separate spreadsheets — the awarded marks
/// with their remarks, and the plain "did the file arrive" grid — so the
/// screen can switch between them without refetching.
class OpsSummaryCategory {
  const OpsSummaryCategory({
    required this.id,
    required this.name,
    required this.maxMarks,
    required this.displayOrder,
  });

  final String id;
  final String name;
  final int maxMarks;
  final int displayOrder;

  factory OpsSummaryCategory.fromJson(Map<String, dynamic> j) => OpsSummaryCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        maxMarks: j['maxMarks'] as int? ?? 0,
        displayOrder: j['displayOrder'] as int? ?? 0,
      );

  /// Categories arrive named like "1) Monthly PPT" — the leading number is
  /// redundant once the column is in position, and it costs header width.
  String get shortName {
    final m = RegExp(r'^\s*\d+\s*[).:-]\s*').firstMatch(name);
    return m == null ? name : name.substring(m.end);
  }
}

/// One (site, category) intersection.
class OpsSummaryCell {
  const OpsSummaryCell({
    required this.categoryId,
    required this.maxMarks,
    required this.uploaded,
    required this.status,
    required this.awardedMarks,
    required this.remark,
    this.fileName,
    this.uploadedAt,
  });

  final String categoryId;
  final int maxMarks;

  /// False when the site never uploaded anything for this category — the "N"
  /// of the old review grid.
  final bool uploaded;
  final SubmissionItemStatus? status;
  final int? awardedMarks;

  /// Ops Excellence's note, falling back to the manager's review comment
  /// while marks are still outstanding.
  final String? remark;
  final String? fileName;
  final DateTime? uploadedAt;

  factory OpsSummaryCell.fromJson(Map<String, dynamic> j) => OpsSummaryCell(
        categoryId: j['categoryId'] as String,
        maxMarks: j['maxMarks'] as int? ?? 0,
        uploaded: j['uploaded'] as bool? ?? false,
        status: j['status'] == null
            ? null
            : itemStatusFromWire(j['status'] as String),
        awardedMarks: j['awardedMarks'] as int?,
        remark: j['remark'] as String?,
        fileName: j['fileName'] as String?,
        uploadedAt: j['uploadedAt'] == null
            ? null
            : DateTime.tryParse(j['uploadedAt'] as String),
      );

  /// Share of the category ceiling this site earned, or null when unmarked.
  double? get attainment =>
      awardedMarks == null || maxMarks <= 0 ? null : awardedMarks! / maxMarks;
}

/// One site's line in the review.
class OpsSummaryRow {
  const OpsSummaryRow({
    required this.projectId,
    required this.code,
    required this.name,
    required this.submitted,
    required this.status,
    required this.totalScore,
    required this.uploadedCount,
    required this.scoredCount,
    required this.cells,
    this.location,
    this.evaluator,
    this.submittedBy,
    this.submittedByEmail,
    this.submittedAt,
    this.reviewedAt,
    this.comments,
  });

  final String projectId;
  final String code;
  final String name;
  final String? location;

  /// Whether a cycle exists for this site in the month at all.
  final bool submitted;
  final SubmissionStatus? status;

  /// Who allocated the marks; null until the cycle has been reviewed.
  final String? evaluator;
  final String? submittedBy;
  final String? submittedByEmail;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? comments;

  /// Null when the site never submitted — distinct from a genuine zero.
  final int? totalScore;
  final int uploadedCount;
  final int scoredCount;
  final List<OpsSummaryCell> cells;

  factory OpsSummaryRow.fromJson(Map<String, dynamic> j) => OpsSummaryRow(
        projectId: j['projectId'] as String,
        code: j['code'] as String,
        name: j['name'] as String,
        location: j['location'] as String?,
        submitted: j['submitted'] as bool? ?? false,
        status: j['status'] == null
            ? null
            : submissionStatusFromWire(j['status'] as String),
        evaluator: j['evaluator'] as String?,
        submittedBy: j['submittedBy'] as String?,
        submittedByEmail: j['submittedByEmail'] as String?,
        submittedAt: j['submittedAt'] == null
            ? null
            : DateTime.tryParse(j['submittedAt'] as String),
        reviewedAt: j['reviewedAt'] == null
            ? null
            : DateTime.tryParse(j['reviewedAt'] as String),
        comments: j['comments'] as String?,
        totalScore: j['totalScore'] as int?,
        uploadedCount: j['uploadedCount'] as int? ?? 0,
        scoredCount: j['scoredCount'] as int? ?? 0,
        cells: (j['cells'] as List<dynamic>? ?? const [])
            .map((e) => OpsSummaryCell.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  /// True once every category has a mark — the row is finished.
  bool get fullyScored => submitted && scoredCount == cells.length && cells.isNotEmpty;
}

/// Fleet-wide performance of a single report category.
class OpsCategoryStat {
  const OpsCategoryStat({
    required this.categoryId,
    required this.name,
    required this.maxMarks,
    required this.average,
    required this.max,
    required this.min,
    required this.scoredCount,
    required this.attainmentPercent,
    required this.skippedCount,
  });

  final String categoryId;
  final String name;
  final int maxMarks;
  final double? average;
  final int? max;
  final int? min;
  final int scoredCount;

  /// Average as a percentage of [maxMarks] — how much of the ceiling the
  /// fleet is earning. This is what ranks the weakest reporting areas.
  final double? attainmentPercent;

  /// Sites that filed a cycle but left this report out. Sites that filed
  /// nothing at all are counted once in [OpsSummaryStats.missingCount] rather
  /// than against every category.
  final int skippedCount;

  factory OpsCategoryStat.fromJson(Map<String, dynamic> j) => OpsCategoryStat(
        categoryId: j['categoryId'] as String,
        name: j['name'] as String,
        maxMarks: j['maxMarks'] as int? ?? 0,
        average: (j['average'] as num?)?.toDouble(),
        max: j['max'] as int?,
        min: j['min'] as int?,
        scoredCount: j['scoredCount'] as int? ?? 0,
        attainmentPercent: (j['attainmentPercent'] as num?)?.toDouble(),
        skippedCount: j['skippedCount'] as int? ?? 0,
      );
}

/// Average / maximum / minimum over the cycles that exist.
class OpsSpread {
  const OpsSpread({required this.average, required this.max, required this.min});
  final double? average;
  final int? max;
  final int? min;

  factory OpsSpread.fromJson(Map<String, dynamic> j) => OpsSpread(
        average: (j['average'] as num?)?.toDouble(),
        max: j['max'] as int?,
        min: j['min'] as int?,
      );
}

class OpsSummaryStats {
  const OpsSummaryStats({
    required this.projectCount,
    required this.submittedCount,
    required this.missingCount,
    required this.scoredCount,
    required this.awaitingMarksCount,
    required this.total,
    required this.categories,
  });

  final int projectCount;
  final int submittedCount;

  /// Sites with no cycle at all this month.
  final int missingCount;

  /// Sites whose marks are at least partly allocated.
  final int scoredCount;

  /// Submitted but not marked yet — the Ops Excellence work queue.
  final int awaitingMarksCount;
  final OpsSpread total;
  final List<OpsCategoryStat> categories;

  factory OpsSummaryStats.fromJson(Map<String, dynamic> j) => OpsSummaryStats(
        projectCount: j['projectCount'] as int? ?? 0,
        submittedCount: j['submittedCount'] as int? ?? 0,
        missingCount: j['missingCount'] as int? ?? 0,
        scoredCount: j['scoredCount'] as int? ?? 0,
        awaitingMarksCount: j['awaitingMarksCount'] as int? ?? 0,
        total: OpsSpread.fromJson(
            (j['total'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
        categories: (j['categories'] as List<dynamic>? ?? const [])
            .map((e) => OpsCategoryStat.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );

  /// Submission rate for the month, 0–1.
  double get submissionRate =>
      projectCount == 0 ? 0 : submittedCount / projectCount;
}

class OpsSummary {
  const OpsSummary({
    required this.month,
    required this.maxTotal,
    required this.categories,
    required this.rows,
    required this.stats,
  });

  final String month;

  /// Sum of every active category's ceiling — the denominator for a total.
  final int maxTotal;
  final List<OpsSummaryCategory> categories;
  final List<OpsSummaryRow> rows;
  final OpsSummaryStats stats;

  factory OpsSummary.fromJson(Map<String, dynamic> j) => OpsSummary(
        month: j['month'] as String,
        maxTotal: j['maxTotal'] as int? ?? 0,
        categories: (j['categories'] as List<dynamic>? ?? const [])
            .map((e) => OpsSummaryCategory.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        rows: (j['rows'] as List<dynamic>? ?? const [])
            .map((e) => OpsSummaryRow.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        stats: OpsSummaryStats.fromJson(
            (j['stats'] as Map<String, dynamic>?) ?? const <String, dynamic>{}),
      );

  /// Every row, best total first. Sites that filed nothing sort last rather
  /// than as zeroes — a blank and a genuine zero are different findings.
  List<OpsSummaryRow> get ranked {
    final out = [...rows];
    out.sort((a, b) {
      final av = a.totalScore;
      final bv = b.totalScore;
      if (av == null && bv == null) return a.name.compareTo(b.name);
      if (av == null) return 1;
      if (bv == null) return -1;
      return bv.compareTo(av);
    });
    return out;
  }

  /// Sites with nothing filed this month — the chase list.
  List<OpsSummaryRow> get notSubmitted =>
      rows.where((r) => !r.submitted).toList(growable: false);
}
