import '../../categories/data/category_model.dart';

enum SubmissionStatus { draft, submitted, approved, rejected, unknown }

SubmissionStatus submissionStatusFromWire(String s) => switch (s) {
      'DRAFT' => SubmissionStatus.draft,
      'SUBMITTED' => SubmissionStatus.submitted,
      'APPROVED' => SubmissionStatus.approved,
      'REJECTED' => SubmissionStatus.rejected,
      _ => SubmissionStatus.unknown,
    };

String submissionStatusLabel(SubmissionStatus s) => switch (s) {
      SubmissionStatus.draft => 'Draft',
      SubmissionStatus.submitted => 'Submitted',
      SubmissionStatus.approved => 'Approved',
      SubmissionStatus.rejected => 'Rejected',
      SubmissionStatus.unknown => 'Unknown',
    };

enum SubmissionItemStatus { pending, submitted, approved, rejected, unknown }

SubmissionItemStatus itemStatusFromWire(String s) => switch (s) {
      'PENDING' => SubmissionItemStatus.pending,
      'SUBMITTED' => SubmissionItemStatus.submitted,
      'APPROVED' => SubmissionItemStatus.approved,
      'REJECTED' => SubmissionItemStatus.rejected,
      _ => SubmissionItemStatus.unknown,
    };

String itemStatusLabel(SubmissionItemStatus s) => switch (s) {
      SubmissionItemStatus.pending => 'Pending',
      SubmissionItemStatus.submitted => 'Submitted',
      SubmissionItemStatus.approved => 'Approved',
      SubmissionItemStatus.rejected => 'Rejected',
      SubmissionItemStatus.unknown => 'Unknown',
    };

class SubmissionItem {
  const SubmissionItem({
    required this.id,
    required this.submissionId,
    required this.categoryId,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    required this.status,
    required this.awardedMarks,
    required this.reviewerComment,
    required this.category,
    this.opsRemark,
    this.uploadedAt,
  });

  final String id;
  final String submissionId;
  final String categoryId;
  final String fileName;
  final FileTypeCode fileType;
  final int fileSize;
  final SubmissionItemStatus status;
  final int? awardedMarks;
  final String? reviewerComment;

  /// Ops Excellence's note recorded alongside the mark allocation.
  final String? opsRemark;
  final DateTime? uploadedAt;
  final ReportCategory? category;

  factory SubmissionItem.fromJson(Map<String, dynamic> j) => SubmissionItem(
        id: j['id'] as String,
        submissionId: j['submissionId'] as String,
        categoryId: j['categoryId'] as String,
        fileName: j['fileName'] as String,
        fileType: fileTypeFromWire(j['fileType'] as String),
        fileSize: j['fileSize'] as int,
        status: itemStatusFromWire(j['status'] as String),
        awardedMarks: j['awardedMarks'] as int?,
        reviewerComment: j['reviewerComment'] as String?,
        opsRemark: j['opsRemark'] as String?,
        uploadedAt: j['uploadedAt'] != null ? DateTime.parse(j['uploadedAt'] as String) : null,
        category: j['category'] != null
            ? ReportCategory.fromJson(j['category'] as Map<String, dynamic>)
            : null,
      );
}

class SubmissionProject {
  const SubmissionProject({required this.id, required this.name, required this.code});
  final String id;
  final String name;
  final String code;

  factory SubmissionProject.fromJson(Map<String, dynamic> j) => SubmissionProject(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
      );
}

class Submission {
  const Submission({
    required this.id,
    required this.projectId,
    required this.month,
    required this.status,
    required this.totalScore,
    required this.items,
    required this.project,
    this.submittedAt,
    this.reviewedAt,
    this.comments,
  });

  final String id;
  final String projectId;
  final String month;
  final SubmissionStatus status;
  final int totalScore;
  final List<SubmissionItem> items;
  final SubmissionProject? project;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? comments;

  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        id: j['id'] as String,
        projectId: j['projectId'] as String,
        month: j['month'] as String,
        status: submissionStatusFromWire(j['status'] as String),
        totalScore: j['totalScore'] as int? ?? 0,
        comments: j['comments'] as String?,
        submittedAt: j['submittedAt'] != null ? DateTime.parse(j['submittedAt'] as String) : null,
        reviewedAt: j['reviewedAt'] != null ? DateTime.parse(j['reviewedAt'] as String) : null,
        project: j['project'] != null
            ? SubmissionProject.fromJson(j['project'] as Map<String, dynamic>)
            : null,
        items: (j['items'] as List<dynamic>? ?? const [])
            .map((e) => SubmissionItem.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}

class CycleSnapshot {
  const CycleSnapshot({required this.submission, required this.categories});
  final Submission? submission;
  final List<ReportCategory> categories;

  factory CycleSnapshot.fromJson(Map<String, dynamic> j) => CycleSnapshot(
        submission: j['submission'] == null
            ? null
            : Submission.fromJson(j['submission'] as Map<String, dynamic>),
        categories: (j['categories'] as List<dynamic>)
            .map((e) => ReportCategory.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
      );
}
