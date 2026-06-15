class Project {
  const Project({
    required this.id,
    required this.name,
    required this.code,
    required this.location,
    required this.inchargeName,
    required this.inchargeEmail,
    required this.inchargePhone,
    required this.isActive,
  });

  final String id;
  final String name;
  final String code;
  final String? location;
  final String? inchargeName;
  final String? inchargeEmail;
  final String? inchargePhone;
  final bool isActive;

  factory Project.fromJson(Map<String, dynamic> j) => Project(
        id: j['id'] as String,
        name: j['name'] as String,
        code: j['code'] as String,
        location: j['location'] as String?,
        inchargeName: j['inchargeName'] as String?,
        inchargeEmail: j['inchargeEmail'] as String?,
        inchargePhone: j['inchargePhone'] as String?,
        isActive: j['isActive'] as bool? ?? true,
      );
}
