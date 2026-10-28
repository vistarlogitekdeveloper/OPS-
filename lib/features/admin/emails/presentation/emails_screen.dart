import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/errors/api_error.dart';
import '../../../../core/theme/vistar.dart';
import '../../../../core/vistar/widgets.dart';
import '../../../../core/widgets/confirm_dialog.dart';
import '../../../../core/widgets/month_picker.dart';
import '../../../auth/data/auth_models.dart';
import '../data/emails_repository.dart';

/// Admin → Emails: the live SMTP check plus the two mails an admin can send
/// by hand — one to chosen roles, one to whoever still owes a month's report.
/// Each opens on the app's own template, editable in place before sending.
class EmailsScreen extends StatefulWidget {
  const EmailsScreen({super.key});

  @override
  State<EmailsScreen> createState() => _EmailsScreenState();
}

class _EmailsScreenState extends State<EmailsScreen> {
  MailKind _kind = MailKind.common;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        const _SmtpStatusCard(),
        const SizedBox(height: 16),
        LayoutBuilder(builder: (context, box) {
          // Phones: full width, short labels, no icons — the long ones overflow.
          final wide = box.maxWidth >= 520;
          return Align(
            alignment: Alignment.centerLeft,
            child: SizedBox(
              width: wide ? null : double.infinity,
              child: SegmentedButton<MailKind>(
                showSelectedIcon: wide,
                style: wide
                    ? null
                    : const ButtonStyle(
                        visualDensity: VisualDensity.compact,
                        padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6)),
                      ),
                segments: [
                  ButtonSegment(
                    value: MailKind.common,
                    icon: wide ? const Icon(Icons.campaign_outlined) : null,
                    label: Text(wide ? 'Common email' : 'Common'),
                  ),
                  ButtonSegment(
                    value: MailKind.pending,
                    icon: wide ? const Icon(Icons.pending_actions_outlined) : null,
                    label: Text(wide ? 'Pending submissions' : 'Pending'),
                  ),
                ],
                selected: {_kind},
                onSelectionChanged: (s) => setState(() => _kind = s.first),
              ),
            ),
          );
        }),
        const SizedBox(height: 12),
        // Both stay mounted so switching tabs never loses an edited draft.
        Visibility(
          visible: _kind == MailKind.common,
          maintainState: true,
          child: const _ComposeCard(kind: MailKind.common),
        ),
        Visibility(
          visible: _kind == MailKind.pending,
          maintainState: true,
          child: const _ComposeCard(kind: MailKind.pending),
        ),
      ],
    );
  }
}

// ───────────────────────────── SMTP status ─────────────────────────────

class _SmtpStatusCard extends ConsumerWidget {
  const _SmtpStatusCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final async = ref.watch(mailStatusProvider);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13);

    Widget line(IconData icon, Color color, String title, [String? detail]) => Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (detail != null) ...[
                    const SizedBox(height: 2),
                    SelectableText(detail, style: muted),
                  ],
                ],
              ),
            ),
          ],
        );

    return VistarCard(
      cornerS: true,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            'Mail server',
            trailing: IconButton(
              tooltip: 'Check again',
              icon: const Icon(Icons.refresh),
              onPressed: async.isLoading ? null : () => ref.invalidate(mailStatusProvider),
            ),
          ),
          async.when(
            loading: () => Row(
              children: [
                const SizedBox(
                    width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 12),
                Expanded(child: Text('Connecting to the mail server…', style: muted)),
              ],
            ),
            error: (e, _) => line(Icons.error_outline, Vistar.bad,
                'Could not check the mail server', ApiError.from(e).message),
            data: (s) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!s.configured)
                  line(Icons.error_outline, Vistar.bad, 'Mail is not set up', s.error)
                else if (s.verified == false)
                  line(Icons.error_outline, Vistar.bad,
                      'Mail server rejected the connection — emails are NOT being sent',
                      [
                        if (s.host != null) '${s.host}:${s.port}',
                        if (s.error != null) s.error!,
                      ].join('\n'))
                else
                  line(
                    Icons.check_circle_outline,
                    Vistar.ok,
                    s.transport == 'org'
                        ? 'Using this organisation\'s mail server'
                        : 'Connected — emails can be sent',
                    [
                      if (s.host != null) '${s.host}:${s.port}',
                      if (s.from != null) 'From: ${s.from}',
                    ].join('\n'),
                  ),
                const SizedBox(height: 10),
                line(
                  s.schedulersEnabled ? Icons.schedule : Icons.schedule_outlined,
                  s.schedulersEnabled ? Vistar.ok : Vistar.amber,
                  s.schedulersEnabled
                      ? 'Automatic monthly reminders are on'
                      : 'Automatic monthly reminders are off',
                  s.schedulersEnabled
                      ? 'Sent on days 1–7 to anyone who still owes last month\'s report.'
                      : 'Set ENABLE_OPS_SCHEDULERS=true on the server to switch them on.',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────── compose ─────────────────────────────

const _roleOptions = [
  UserRole.siteUser,
  UserRole.manager,
  UserRole.clusterManager,
  UserRole.opsExcellence,
  UserRole.admin,
];

String _monthWire(DateTime m) =>
    '${m.year.toString().padLeft(4, '0')}-${m.month.toString().padLeft(2, '0')}';

DateTime? _monthParse(String? s) {
  if (s == null) return null;
  final p = s.split('-');
  if (p.length != 2) return null;
  final y = int.tryParse(p[0]), m = int.tryParse(p[1]);
  return y == null || m == null ? null : DateTime(y, m);
}

class _ComposeCard extends ConsumerStatefulWidget {
  const _ComposeCard({required this.kind});
  final MailKind kind;

  @override
  ConsumerState<_ComposeCard> createState() => _ComposeCardState();
}

class _ComposeCardState extends ConsumerState<_ComposeCard> {
  final _subject = TextEditingController();
  final _body = TextEditingController();

  Set<UserRole> _roles = {..._roleOptions};
  DateTime? _month; // pending only; null until the server names last month

  MailDraft? _draft;
  Object? _loadError;
  bool _loading = false;
  bool _sending = false;

  /// Recipients the admin un-ticked; the server recomputes the list itself.
  final Set<String> _excluded = {};

  bool get _isCommon => widget.kind == MailKind.common;

  @override
  void initState() {
    super.initState();
    _load(resetText: true);
  }

  @override
  void dispose() {
    _subject.dispose();
    _body.dispose();
    super.dispose();
  }

  /// Fetches the template and recipient list. The admin's edits survive a
  /// change of roles or month; only [resetText] puts the template back.
  Future<void> _load({bool resetText = false}) async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(emailsRepositoryProvider);
      final draft = _isCommon
          ? await repo.commonDraft(_roles)
          : await repo.pendingDraft(_month == null ? null : _monthWire(_month!));
      if (!mounted) return;
      setState(() {
        _draft = draft;
        _month ??= _monthParse(draft.month);
        _excluded.retainAll(draft.recipients.map((r) => r.userId));
        if (resetText || _subject.text.isEmpty && _body.text.isEmpty) {
          _subject.text = draft.subject;
          _body.text = draft.body;
        }
      });
    } catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<MailRecipient> get _chosen => [
        for (final r in _draft?.recipients ?? const <MailRecipient>[])
          if (!_excluded.contains(r.userId)) r,
      ];

  void _insertPlaceholder(String p) {
    final sel = _body.selection;
    final text = _body.text;
    final start = sel.isValid ? sel.start : text.length;
    final end = sel.isValid ? sel.end : text.length;
    _body.value = TextEditingValue(
      text: text.replaceRange(start, end, p),
      selection: TextSelection.collapsed(offset: start + p.length),
    );
  }

  Future<void> _pickMonth() async {
    final now = DateTime.now();
    final picked = await showMonthPicker(
      context: context,
      initial: _month ?? DateTime(now.year, now.month - 1),
      firstMonth: DateTime(2020),
      lastMonth: DateTime(now.year, now.month),
      helpText: 'Month the report is pending for',
    );
    if (picked == null) return;
    setState(() => _month = picked);
    await _load();
  }

  Future<void> _send() async {
    final chosen = _chosen;
    if (chosen.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmAction(
      context,
      title: 'Send this email?',
      message: 'It will go to ${chosen.length} '
          '${chosen.length == 1 ? 'person' : 'people'} now. This cannot be undone.',
      confirmLabel: 'Send',
    );
    if (!ok || !mounted) return;
    setState(() => _sending = true);
    try {
      final outcome = await ref.read(emailsRepositoryProvider).send(
            kind: widget.kind,
            subject: _subject.text.trim(),
            body: _body.text.trim(),
            roles: _isCommon ? _roles : null,
            month: _isCommon || _month == null ? null : _monthWire(_month!),
            excludeUserIds: _excluded,
          );
      if (!mounted) return;
      // Stop the spinner before the results dialog, not after it closes.
      setState(() => _sending = false);
      await showDialog<void>(
        context: context,
        builder: (_) => _OutcomeDialog(outcome: outcome),
      );
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(ApiError.from(e).message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13);
    final draft = _draft;
    final chosen = _chosen;

    return VistarCard(
      cornerS: true,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SectionTitle(
            _isCommon ? 'Common email' : 'Pending submissions reminder',
            trailing: IconButton(
              tooltip: 'Reset to template',
              onPressed: draft == null || _sending
                  ? null
                  : () => setState(() {
                        _subject.text = draft.subject;
                        _body.text = draft.body;
                      }),
              icon: const Icon(Icons.restart_alt),
            ),
          ),
          Text(
            _isCommon
                ? 'One message to every active user in the roles you pick.'
                : 'Each site user / project manager who has not submitted the month gets '
                    'one email listing their own pending sites.',
            style: muted,
          ),
          const SizedBox(height: 14),
          if (_isCommon)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in _roleOptions)
                  FilterChip(
                    label: Text(roleLabel(r)),
                    selected: _roles.contains(r),
                    onSelected: _sending
                        ? null
                        : (on) {
                            final next = {..._roles};
                            on ? next.add(r) : next.remove(r);
                            if (next.isEmpty) return; // at least one role
                            setState(() => _roles = next);
                            _load();
                          },
                  ),
              ],
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.calendar_month_outlined),
              title: const Text('Report month'),
              subtitle: Text(_month == null ? '…' : DateFormat.yMMMM().format(_month!)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _sending ? null : _pickMonth,
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _subject,
            enabled: !_sending,
            decoration: const InputDecoration(labelText: 'Subject'),
            maxLength: 200,
          ),
          const SizedBox(height: 6),
          TextField(
            controller: _body,
            enabled: !_sending,
            minLines: 10,
            maxLines: 24,
            keyboardType: TextInputType.multiline,
            decoration: const InputDecoration(
              labelText: 'Message',
              alignLabelWithHint: true,
            ),
          ),
          if (draft != null && draft.placeholders.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Insert:', style: muted),
                for (final p in draft.placeholders)
                  ActionChip(
                    label: Text(p),
                    visualDensity: VisualDensity.compact,
                    onPressed: _sending ? null : () => _insertPlaceholder(p),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text('Placeholders are filled in separately for each person when the email is sent.',
                style: muted),
          ],
          const SizedBox(height: 14),
          if (_loading)
            const LinearProgressIndicator()
          else if (_loadError != null)
            Row(
              children: [
                const Icon(Icons.error_outline, color: Vistar.bad),
                const SizedBox(width: 8),
                Expanded(child: Text(ApiError.from(_loadError!).message)),
                TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            )
          else if (draft != null) ...[
            if (chosen.isNotEmpty)
              _Preview(
                recipient: chosen.first,
                subject: _subject,
                body: _body,
                monthLabel: draft.monthLabel,
              ),
            _RecipientList(
              draft: draft,
              excluded: _excluded,
              enabled: !_sending,
              onToggle: (id, include) => setState(() {
                include ? _excluded.remove(id) : _excluded.add(id);
              }),
              onAll: (include) => setState(() {
                include
                    ? _excluded.clear()
                    : _excluded.addAll(draft.recipients.map((r) => r.userId));
              }),
            ),
          ],
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: _sending
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                        SizedBox(width: 10),
                        Text('Sending…'),
                      ],
                    ),
                  )
                // RibbonButton's label cannot wrap: shorter wording on phones.
                : LayoutBuilder(
                    builder: (context, box) => RibbonButton(
                      icon: Icons.send_outlined,
                      label: chosen.isEmpty
                          ? (box.maxWidth < 300 ? 'Send' : 'Nobody to send to')
                          : box.maxWidth < 300
                              ? 'Send (${chosen.length})'
                              : 'Send to ${chosen.length} '
                                  '${chosen.length == 1 ? 'person' : 'people'}',
                      onPressed: draft == null || _loading || chosen.isEmpty ? null : _send,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// What the first ticked recipient will actually receive, updated as you type.
class _Preview extends StatelessWidget {
  const _Preview({
    required this.recipient,
    required this.subject,
    required this.body,
    this.monthLabel,
  });
  final MailRecipient recipient;
  final TextEditingController subject;
  final TextEditingController body;
  final String? monthLabel;

  String _fill(String t) {
    final vars = <String, String>{
      'name': recipient.name,
      'month': ?monthLabel,
      if (recipient.sites.isNotEmpty) ...{
        'sites': recipient.sites.map((s) => '  • ${s.code} — ${s.name}').join('\n'),
        'siteCount': '${recipient.sites.length}',
      },
    };
    return t.replaceAllMapped(
        RegExp(r'\{\{\s*(\w+)\s*\}\}'), (m) => vars[m[1]] ?? m[0]!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.visibility_outlined),
        title: Text('Preview for ${recipient.name}'),
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([subject, body]),
            builder: (context, _) => Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText.rich(
                TextSpan(children: [
                  TextSpan(
                    text: '${_fill(subject.text).replaceAll(RegExp(r'\s+'), ' ').trim()}\n\n',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  TextSpan(text: _fill(body.text)),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _RecipientList extends StatelessWidget {
  const _RecipientList({
    required this.draft,
    required this.excluded,
    required this.enabled,
    required this.onToggle,
    required this.onAll,
  });
  final MailDraft draft;
  final Set<String> excluded;
  final bool enabled;
  final void Function(String userId, bool include) onToggle;
  final ValueChanged<bool> onAll;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12.5);
    final total = draft.recipients.length;
    final picked = total - excluded.length;

    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.people_outline),
        title: Text('Recipients — $picked of $total selected'),
        subtitle: draft.noEmail.isEmpty
            ? null
            : Text(
                '${draft.noEmail.length} without an email address will not receive it: '
                '${draft.noEmail.map((r) => r.name).join(', ')}',
                style: const TextStyle(color: Vistar.amber, fontSize: 12.5),
              ),
        children: [
          if (total == 0)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                draft.kind == MailKind.pending
                    ? 'Everyone has submitted ${draft.monthLabel ?? 'this month'}.'
                    : 'No active users in the selected roles.',
                style: muted,
              ),
            )
          else ...[
            Row(
              children: [
                TextButton(
                    onPressed: enabled ? () => onAll(true) : null,
                    child: const Text('Select all')),
                TextButton(
                    onPressed: enabled ? () => onAll(false) : null,
                    child: const Text('Select none')),
              ],
            ),
            for (final r in draft.recipients)
              CheckboxListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: !excluded.contains(r.userId),
                onChanged: enabled ? (v) => onToggle(r.userId, v ?? false) : null,
                title: Text('${r.name} · ${roleLabel(r.role)}'),
                subtitle: Text(
                  [
                    r.email ?? '',
                    if (r.sites.isNotEmpty)
                      'Pending: ${r.sites.map((s) => s.code).join(', ')}',
                  ].join('\n'),
                  style: muted,
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _OutcomeDialog extends StatelessWidget {
  const _OutcomeDialog({required this.outcome});
  final SendOutcome outcome;

  @override
  Widget build(BuildContext context) {
    final failed = outcome.results.where((r) => !r.ok).toList();
    final total = outcome.sent + outcome.failed;
    return AlertDialog(
      icon: Icon(
        failed.isEmpty ? Icons.mark_email_read_outlined : Icons.warning_amber_outlined,
        color: failed.isEmpty ? Vistar.ok : Vistar.amber,
      ),
      title: Text('Sent ${outcome.sent} of $total'),
      content: SizedBox(
        width: 480,
        child: failed.isEmpty
            ? const Text('Every email was accepted by the mail server.')
            : ListView(
                shrinkWrap: true,
                children: [
                  const Text('These could not be sent:'),
                  const SizedBox(height: 8),
                  for (final f in failed)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.error_outline, color: Vistar.bad),
                      title: Text('${f.name} <${f.email}>'),
                      subtitle: SelectableText(f.error ?? 'Unknown error'),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Close')),
      ],
    );
  }
}
