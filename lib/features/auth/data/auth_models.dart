enum UserRole { admin, manager, clusterManager, siteUser, opsExcellence, unknown }

UserRole roleFromWire(String raw) {
  switch (raw) {
    case 'ADMIN':
      return UserRole.admin;
    case 'MANAGER':
      return UserRole.manager;
    // 'REGIONAL_MANAGER' is the pre-rename wire name. Kept so this build works
    // against a backend that has not been redeployed yet — without it a cluster
    // manager would fall through to UserRole.unknown and lose every permission.
    case 'REGIONAL_MANAGER':
    case 'CLUSTER_MANAGER':
      return UserRole.clusterManager;
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
      return 'Project Manager';
    case UserRole.clusterManager:
      return 'Cluster Manager';
    case UserRole.siteUser:
      return 'Site User';
    case UserRole.opsExcellence:
      return 'Ops Excellence';
    case UserRole.unknown:
      return 'Unknown';
  }
}

/// Parses the server's role list. `roles` is the full set (primary first); a
/// backend that predates multi-role sends only `role`, which reads as a list of
/// one — so this build works against either.
///
/// Unknown wire names are dropped rather than kept as [UserRole.unknown], which
/// would otherwise sit in the set and make `has(UserRole.unknown)` true. If
/// nothing survives, the primary role is used so the user is never left with an
/// empty set.
List<UserRole> rolesFromWire(Map<String, dynamic> j) {
  final primary = roleFromWire(j['role'] as String);
  final raw = j['roles'] as List<dynamic>?;
  if (raw == null) return [primary];
  final out = <UserRole>[];
  for (final r in raw) {
    if (r is! String) continue;
    final parsed = roleFromWire(r);
    if (parsed != UserRole.unknown && !out.contains(parsed)) out.add(parsed);
  }
  return out.isEmpty ? [primary] : out;
}

class AuthUser {
  const AuthUser({
    required this.id,
    required this.name,
    required this.email,
    required this.username,
    required this.roles,
    required this.assignedProjectIds,
    required this.isActive,
  });

  final String id;
  final String name;
  final String email;
  final String username;

  /// Every role this employee holds — one person, several hats. Primary first.
  ///
  /// Permissions are the UNION: check with [has] / [hasAny] rather than
  /// comparing [role], which only ever names the first one. A project manager
  /// who is also a cluster manager files cycles AND approves them, and a check
  /// written as `user.role == UserRole.clusterManager` would deny them both.
  final List<UserRole> roles;

  final List<String> assignedProjectIds;
  final bool isActive;

  /// The primary role — for display, and for the places that must name one
  /// (telemetry, a single pill). Never use it to decide what someone may do.
  UserRole get role => roles.isEmpty ? UserRole.unknown : roles.first;

  /// Does this user hold [r], in any of their hats?
  bool has(UserRole r) => roles.contains(r);

  /// Does this user hold any of [candidates]?
  bool hasAny(Iterable<UserRole> candidates) => candidates.any(roles.contains);

  factory AuthUser.fromJson(Map<String, dynamic> j) => AuthUser(
        id: j['id'] as String,
        name: j['name'] as String,
        email: j['email'] as String,
        username: j['username'] as String,
        roles: rolesFromWire(j),
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
