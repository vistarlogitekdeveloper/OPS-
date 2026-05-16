enum UserRole { admin, manager, siteUser, opsExcellence, unknown }

UserRole roleFromWire(String raw) {
  switch (raw) {
    case 'ADMIN':
      return UserRole.admin;
    case 'MANAGER':
      return UserRole.manager;
    case 'SITE_USER':
      return UserRole.siteUser;
    case 'OPS_EXCELLENCE':
      return UserRole.opsExcellence;
    default:
      return UserRole.unknown;
  }
}

String roleLabel(UserRole r) {
  switch (r) {
    case UserRole.admin:
      return 'Administrator';
    case UserRole.manager:
      return 'Manager';
    case UserRole.siteUser:
      return 'Site User';
    case UserRole.opsExcellence:
      return 'Ops Excellence';
    case UserRole.unknown:
      return 'Unknown';
  }
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.role,
    required this.assignedProjectIds,
    required this.isActive,
  });

  final String id;
  final String name;
  final String email;
  final String username;
  final UserRole role;
  final List<String> assignedProjectIds;
  final bool isActive;

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        username: j['username'] as String,
        role: roleFromWire(j['role'] as String),
        assignedProjectIds:
            (j['assignedProjectIds'] as List<dynamic>? ?? const []).cast<String>(),
        isActive: j['isActive'] as bool? ?? true,
      );
}

class AuthSession {
  const AuthSession({
    required this.user,
    required this.accessToken,
    required this.refreshToken,
  });

  final AuthUser user;
  final String accessToken;
  final String refreshToken;

  factory AuthSession.fromJson(Map<String, dynamic> j) => AuthSession(
        user: AuthUser.fromJson(j['user'] as Map<String, dynamic>),
        accessToken: j['accessToken'] as String,
        refreshToken: j['refreshToken'] as String,
      );
}
