class PageResult<T> {
  const PageResult({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
    required this.pageCount,
  });

  final List<T> items;
  final int total;
  final int page;
  final int pageSize;
  final int pageCount;

  static PageResult<T> fromJson<T>(
    Map<String, dynamic> json,
    T Function(Map<String, dynamic>) parseItem,
  ) {
    final raw = (json['items'] as List<dynamic>? ?? const []);
    return PageResult<T>(
      items: raw.map((e) => parseItem(e as Map<String, dynamic>)).toList(growable: false),
      total: json['total'] as int? ?? 0,
      page: json['page'] as int? ?? 1,
      pageSize: json['pageSize'] as int? ?? raw.length,
      pageCount: json['pageCount'] as int? ?? 1,
    );
  }
}
