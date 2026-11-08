import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../reception_checkin/domain/member_hit.dart';
import '../../../reception_checkin/presentation/widgets/member_card.dart';

/// MEM-19: choose the account to keep, confirm, then [submit]. Resolves to the kept id once merged.
/// [accounts] are all the accounts of one person, the learner on screen included.
Future<String?> showMergeSheet(BuildContext context,
        {required List<MemberHit> accounts,
        required String currentId,
        required Future<void> Function(String keepId) submit}) =>
    showHvpSheet<String>(
      context,
      title: 'Gộp tài khoản trùng',
      builder: (_) =>
          _MergeSheet(accounts: accounts, currentId: currentId, submit: submit),
    );

class _MergeSheet extends StatefulWidget {
  const _MergeSheet(
      {required this.accounts, required this.currentId, required this.submit});

  final List<MemberHit> accounts;
  final String currentId;
  final Future<void> Function(String keepId) submit;

  @override
  State<_MergeSheet> createState() => _MergeSheetState();
}

class _MergeSheetState extends State<_MergeSheet> {
  late String _keepId = widget.currentId;
  bool _confirming = false;
  bool _submitting = false;
  String? _error;

  MemberHit get _keep => widget.accounts.firstWhere((a) => a.id == _keepId);

  Future<void> _merge() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.submit(_keepId);
      if (mounted) Navigator.of(context).pop(_keepId);
    } catch (e) {
      if (mounted) {
        setState(() {
          _submitting = false;
          _error = errorMessage(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final others = widget.accounts
        .where((a) => a.id != _keepId)
        .map((a) => a.fullName)
        .join(', ');
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (!_confirming) ...<Widget>[
            Text(
                'Chọn tài khoản giữ lại. Các tài khoản còn lại sẽ được gộp vào đó.',
                style: t.bodySmall),
            const SizedBox(height: 12),
            for (final a in widget.accounts)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Stack(
                  alignment: Alignment.topRight,
                  children: <Widget>[
                    MemberCard(
                        member: a, onTap: () => setState(() => _keepId = a.id)),
                    if (a.id == _keepId)
                      Padding(
                          padding: const EdgeInsets.all(10),
                          child: Icon(HvpIcons.checkCircle,
                              color: context.hvp.gold)),
                  ],
                ),
              ),
            const SizedBox(height: 6),
            HvpButton.primary(
                label: 'Gộp vào ${_keep.fullName}',
                expand: true,
                onPressed: () => setState(() => _confirming = true)),
          ] else ...<Widget>[
            HvpCard(
              accent: context.hvp.red,
              child: Text(
                  'Gộp $others vào ${_keep.fullName}? Việc này không thể hoàn tác. Lịch sử và điểm của tài khoản bị gộp được chuyển sang tài khoản giữ lại.',
                  style: t.body),
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              InlineBanner(message: _error!)
            ],
            const SizedBox(height: 16),
            HvpButton.danger(
                label: 'Xác nhận gộp',
                expand: true,
                loading: _submitting,
                onPressed: _submitting ? null : _merge),
            const SizedBox(height: 8),
            HvpButton.ghost(
                label: 'Quay lại',
                expand: true,
                onPressed: _submitting
                    ? null
                    : () => setState(() => _confirming = false)),
          ],
        ],
      ),
    );
  }
}
