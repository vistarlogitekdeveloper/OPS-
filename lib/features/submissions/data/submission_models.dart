import '../../categories/data/category_model.dart';

enum SubmissionStatus { draft, submitted, managerApproved, approved, rejected, unknown }

SubmissionStatus submissionStatusFromWire(String s) => switch (s) {
      'DRAFT' => SubmissionStatus.draft,
      'SUBMITTED' => SubmissionStatus.submitted,
      'MANAGER_APPROVED' => SubmissionStatus.managerApproved,
      'APPROVED' => SubmissionStatus.approved,
      'REJECTED' => SubmissionStatus.rejected,
      _ => SubmissionStatus.unknown,
    };

String submissionStatusLabel(SubmissionStatus s) => switch (s) {
      SubmissionStatus.draft => 'Draft',
      SubmissionStatus.submitted => 'Awaiting Cluster Manager',
      // Retired middle state of the old two-stage flow. Any row still carrying
      // it is waiting on the same person, so it reads the same.
      SubmissionStatus.managerApproved => 'Awaiting Cluster Manager',
      SubmissionStatus.approved => 'Approved',
      SubmissionStatus.rejected => 'Rejected',
      SubmissionStatus.unknown => 'Unknown',
    };

/// Whether a cycle is filed and waiting on the cluster manager's decision.
///
/// [SubmissionStatus.managerApproved] counts: nothing writes it any more, but
/// the backfill that clears it is applied by hand, so a cycle left mid-chain
/// must still show up as pending rather than vanishing from the queue.
bool isAwaitingApproval(SubmissionStatus s) =>
    s == SubmissionStatus.submitted || s == SubmissionStatus.managerApproved;

/// Whether whoever files the cycle may still change its files.
///
/// A cycle is either the filer's or the approver's, never both: it is editable
/// while it is a fresh draft or one the cluster manager sent back, and frozen
/// from the moment it is filed. With a single approval stage that freeze is
/// the only thing guaranteeing the approver decided on the files they actually
/// saw. The backend enforces the same rule on /submissions/upload.
bool isEditableByFiler(SubmissionStatus s) =>
    s == SubmissionStatus.draft || s == SubmissionStatus.rejected;

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

/// One file attached to a point. A point holds several (backend: the item's
/// attached FileVersions, sent as `files`).
class ItemFile {
  const ItemFile({
    required this.id,
    required this.fileName,
    required this.fileType,
    required this.fileSize,
    this.uploadedAt,
    this.uploaderName,
  });

  /// Null only for the stand-in built from a backend that predates multiple
  /// files; such a file downloads through its item instead.
  final String? id;
  final String fileName;
  final FileTypeCode fileType;
  final int fileSize;
  final DateTime? uploadedAt;
  final String? uploaderName;

  factory ItemFile.fromJson(Map<String, dynamic> j) => ItemFile(
        id: j['id'] as String,
        fileName: j['fileName'] as String,
        // Null on rows from before multiple files; the name still tells.
        fileType: j['fileType'] != null
            ? fileTypeFromWire(j['fileType'] as String)
            : fileTypeFromName(j['fileName'] as String),
        fileSize: j['fileSize'] as int,
        uploadedAt: j['uploadedAt'] != null ? DateTime.parse(j['uploadedAt'] as String) : null,
        uploaderName: (j['uploader'] as Map<String, dynamic>?)?['name'] as String?,
      );
}

FileTypeCode fileTypeFromName(String name) {
  final ext = name.contains('.') ? name.split('.').last.toLowerCase() : '';
  return switch (ext) {
    'pdf' => FileTypeCode.pdf,
    'ppt' || 'pptx' => FileTypeCode.ppt,
    'xls' || 'xlsx' => FileTypeCode.excel,
    'jpg' || 'jpeg' => FileTypeCode.jpeg,
    'doc' || 'docx' => FileTypeCode.word,
    _ => FileTypeCode.unknown,
  };
}

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
    this.files = const [],
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

  /// Every file attached to the point, oldest first. fileName / fileType /
  /// fileSize above describe the newest of them.
  final List<ItemFile> files;

  factory SubmissionItem.fromJson(Map<String, dynamic> j) {
    final fileName = j['fileName'] as String;
    final fileType = fileTypeFromWire(j['fileType'] as String);
    final fileSize = j['fileSize'] as int;
    final uploadedAt =
        j['uploadedAt'] != null ? DateTime.parse(j['uploadedAt'] as String) : null;
    final rawFiles = j['files'] as List?;
    return SubmissionItem(
      id: j['id'] as String,
      submissionId: j['submissionId'] as String,
      categoryId: j['categoryId'] as String,
      fileName: fileName,
      fileType: fileType,
      fileSize: fileSize,
      status: itemStatusFromWire(j['status'] as String),
      awardedMarks: j['awardedMarks'] as int?,
      reviewerComment: j['reviewerComment'] as String?,
      opsRemark: j['opsRemark'] as String?,
      uploadedAt: uploadedAt,
      category: j['category'] != null
          ? ReportCategory.fromJson(j['category'] as Map<String, dynamic>)
          : null,
      // A backend from before multiple files sends no `files`: its one file
      // is the item's own.
      files: rawFiles != null
          ? [for (final f in rawFiles) ItemFile.fromJson(f as Map<String, dynamic>)]
          : [
              ItemFile(
                id: null,
                fileName: fileName,
                fileType: fileType,
                fileSize: fileSize,
                uploadedAt: uploadedAt,
              ),
            ],
    );
  }
}

/// One recorded decision in the approval chain.
class SubmissionApproval {
  const SubmissionApproval({
    required this.stage,
    required this.decision,
    required this.deciderName,
    required this.deciderRole,
    required this.createdAt,
    this.comment,
  });

  /// 'MANAGER' or 'CLUSTER'.
  final String stage;

  /// 'APPROVE' or 'REJECT'.
  final String decision;
  final String deciderName;
  final String deciderRole;
  final DateTime createdAt;
  final String? comment;

  bool get approved => decision == 'APPROVE';

  /// 'REGIONAL' is the pre-rename wire value; historical approval rows and a
  /// not-yet-redeployed backend both still send it.
  bool get _isClusterStage => stage == 'CLUSTER' || stage == 'REGIONAL';

  /// MANAGER only appears on rows from the retired two-stage flow, where the
  /// project manager took a first approval.
  String get stageLabel => _isClusterStage ? 'Cluster Manager' : 'Project Manager';

  /// One decision settles a cycle now, so a rejection is always outright — the
  /// send-back to the project manager no longer exists.
  String get actionLabel => approved ? 'Approved' : 'Rejected';

  factory SubmissionApproval.fromJson(Map<String, dynamic> j) {
    final decider = j['decider'] as Map<String, dynamic>?;
    return SubmissionApproval(
      stage: j['stage'] as String? ?? 'MANAGER',
      decision: j['decision'] as String? ?? 'APPROVE',
      deciderName: decider?['name'] as String? ?? 'Unknown',
      deciderRole: decider?['role'] as String? ?? '',
      comment: j['comment'] as String?,
      createdAt: DateTime.parse(j['createdAt'] as String),
    );
  }
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
    this.approvals = const [],
    this.submittedAt,
    this.reviewedAt,
    this.comments,
    this.submittedById,
  });

  final String id;
  final String projectId;
  final String month;
  final SubmissionStatus status;
  final int totalScore;
  final List<SubmissionItem> items;
  final SubmissionProject? project;

  /// Decisions taken so far, oldest first.
  final List<SubmissionApproval> approvals;
  final DateTime? submittedAt;
  final DateTime? reviewedAt;
  final String? comments;

  /// Who filed this cycle. Nobody approves their own report — the server
  /// refuses it — so the review screen hides the decision panel from them
  /// rather than offering a button that always 403s. Null only when talking to
  /// a backend old enough not to send it, where the server check still applies.
  final String? submittedById;

  /// Whether [userId] filed this report, and so cannot decide on it.
  ///
  /// An absent or empty id on either side means "not known to be the same
  /// person" rather than a match — two blanks are not evidence of anything.
  bool wasFiledBy(String? userId) {
    final filer = submittedById;
    if (userId == null || userId.isEmpty) return false;
    if (filer == null || filer.isEmpty) return false;
    return filer == userId;
  }

  factory Submission.fromJson(Map<String, dynamic> j) => Submission(
        id: j['id'] as String,
        projectId: j['projectId'] as String,
        month: j['month'] as String,
        status: submissionStatusFromWire(j['status'] as String),
        totalScore: j['totalScore'] as int? ?? 0,
        comments: j['comments'] as String?,
        submittedById: j['submittedBy'] as String?,
        submittedAt: j['submittedAt'] != null ? DateTime.parse(j['submittedAt'] as String) : null,
        reviewedAt: j['reviewedAt'] != null ? DateTime.parse(j['reviewedAt'] as String) : null,
        project: j['project'] != null
            ? SubmissionProject.fromJson(j['project'] as Map<String, dynamic>)
            : null,
        items: (j['items'] as List<dynamic>? ?? const [])
            .map((e) => SubmissionItem.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        approvals: (j['approvals'] as List<dynamic>? ?? const [])
            .map((e) => SubmissionApproval.fromJson(e as Map<String, dynamic>))
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

/// How many submissions currently need the signed-in user's attention in the
/// review section, and what kind of work that is. Drives the review badge.
class PendingReviewCount {
  const PendingReviewCount({required this.count, required this.kind});

  final int count;

  /// 'awaiting_approval' (managers/admin), 'awaiting_marks' (Ops Excellence),
  /// or 'none' for roles without a review section.
  final String kind;

  static const empty = PendingReviewCount(count: 0, kind: 'none');

  /// Short label for the queue header, e.g. "3 awaiting marks".
  String? get label {
    if (count <= 0) return null;
    return switch (kind) {
      'awaiting_marks' => '$count awaiting marks',
      'awaiting_approval' => '$count awaiting approval',
      _ => null,
    };
  }

  factory PendingReviewCount.fromJson(Map<String, dynamic> j) =>
      PendingReviewCount(
        count: (j['count'] as num?)?.toInt() ?? 0,
        kind: j['kind'] as String? ?? 'none',
      );
}
