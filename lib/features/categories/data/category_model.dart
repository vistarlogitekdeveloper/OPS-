enum FileTypeCode { pdf, ppt, excel, jpeg }

FileTypeCode fileTypeFromWire(String raw) {
  switch (raw) {
    case 'PDF':
      return FileTypeCode.pdf;
    case 'PPT':
      return FileTypeCode.ppt;
    case 'EXCEL':
      return FileTypeCode.excel;
    case 'JPEG':
      return FileTypeCode.jpeg;
    default:
      throw ArgumentError('Unknown FileTypeCode: $raw');
  }
}

String fileTypeToWire(FileTypeCode t) => switch (t) {
      FileTypeCode.pdf => 'PDF',
      FileTypeCode.ppt => 'PPT',
      FileTypeCode.excel => 'EXCEL',
      FileTypeCode.jpeg => 'JPEG',
    };

String fileTypeLabel(FileTypeCode t) => switch (t) {
      FileTypeCode.pdf => 'PDF',
      FileTypeCode.ppt => 'PowerPoint',
      FileTypeCode.excel => 'Excel',
      FileTypeCode.jpeg => 'JPEG',
    };

class ReportCategory {
  const ReportCategory({
    required this.id,
    required this.name,
    required this.maxMarks,
    required this.allowedFileTypes,
    required this.displayOrder,
    required this.isActive,
  });

  final String id;
  final String name;
  final int maxMarks;
  final List<FileTypeCode> allowedFileTypes;
  final int displayOrder;
  final bool isActive;

  factory ReportCategory.fromJson(Map<String, dynamic> j) => ReportCategory(
        id: j['id'] as String,
        name: j['name'] as String,
        maxMarks: j['maxMarks'] as int,
        allowedFileTypes: (j['allowedFileTypes'] as List<dynamic>)
            .map((e) => fileTypeFromWire(e as String))
            .toList(growable: false),
        displayOrder: j['displayOrder'] as int,
        isActive: j['isActive'] as bool? ?? true,
      );
}

class CategoryPage {
  const CategoryPage({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.pageCount,
    required this.activeMarksSum,
    required this.maxTotalMarks,
  });

  final List<ReportCategory> items;
  final int total;
  final int page;
  final int pageSize;
  final int pageCount;
  final int activeMarksSum;
  final int maxTotalMarks;

  factory CategoryPage.fromJson(Map<String, dynamic> j) => CategoryPage(
        items: (j['items'] as List<dynamic>)
            .map((e) => ReportCategory.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        total: j['total'] as int? ?? 0,
        page: j['page'] as int? ?? 1,
        pageSize: j['pageSize'] as int? ?? 0,
        pageCount: j['pageCount'] as int? ?? 1,
        activeMarksSum: j['activeMarksSum'] as int? ?? 0,
        maxTotalMarks: j['maxTotalMarks'] as int? ?? 100,
      );
}
