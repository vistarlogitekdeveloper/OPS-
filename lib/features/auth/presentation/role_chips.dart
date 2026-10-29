import 'package:flutter/material.dart';

import '../../../core/vistar/widgets.dart';
import '../data/auth_models.dart';

/// The pill colour for a role.
///
/// One copy, deliberately: this map used to be written out separately in the
/// home screen, the settings screen and the admin user list, and the three had
/// already drifted apart. Multi-role made every one of them render a list
/// rather than a single pill, so they share this instead.
PillKind rolePillKind(UserRole r) => switch (r) {
      UserRole.admin => PillKind.pink,
      // The filing roles share a colour, the reviewing ones another, so a
      // glance at someone's chips says which half of the flow they work in.
      UserRole.manager => PillKind.amber,
      UserRole.siteUser => PillKind.amber,
      UserRole.clusterManager => PillKind.violet,
      UserRole.opsExcellence => PillKind.violet,
      UserRole.unknown => PillKind.neutral,
    };

/// Every role a user holds, as pills — one employee, several hats.
///
/// Wraps rather than overflowing: a user may hold up to five roles and these
/// sit beside a name that is already using most of the row.
class RoleChips extends StatelessWidget {
  const RoleChips({super.key, required this.roles, this.alignment = WrapAlignment.end});

  final List<UserRole> roles;
  final WrapAlignment alignment;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      alignment: alignment,
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final r in roles)
          RibbonPill(label: roleLabel(r).toUpperCase(), kind: rolePillKind(r)),
      ],
    );
  }
}
