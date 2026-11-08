import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../reception_memberships_providers.dart';

/// The "payment collected" modal: a required photo, then [submit] with its URL.
/// Resolves to the message returned by [submit], or null when dismissed.
Future<String?> showEvidenceSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required Future<String> Function(String evidenceUrl) submit,
  String? summary,
}) =>
    showHvpSheet<String>(
      context,
      title: title,
      builder: (_) => _EvidenceSheet(
          confirmLabel: confirmLabel, submit: submit, summary: summary),
    );

class _EvidenceSheet extends ConsumerStatefulWidget {
  const _EvidenceSheet(
      {required this.confirmLabel, required this.submit, this.summary});

  final String confirmLabel;
  final String? summary;
  final Future<String> Function(String evidenceUrl) submit;

  @override
  ConsumerState<_EvidenceSheet> createState() => _EvidenceSheetState();
}

class _EvidenceSheetState extends ConsumerState<_EvidenceSheet> {
  String? _url;
  bool _submitting = false;
  String? _error;

  Future<void> _confirm() async {
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final message = await widget.submit(_url!);
      if (mounted) Navigator.of(context).pop(message);
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
  Widget build(BuildContext context) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.summary != null) ...<Widget>[
              Text(widget.summary!, style: context.txt.body),
              const SizedBox(height: 14)
            ],
            ref.watch(evidencePhotoBuilderProvider)(
                context, (url) => setState(() => _url = url)),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              InlineBanner(message: _error!)
            ],
            const SizedBox(height: 20),
            HvpButton.gold(
              label: widget.confirmLabel,
              expand: true,
              loading: _submitting,
              onPressed: _url == null || _submitting ? null : _confirm,
            ),
          ],
        ),
      );
}
