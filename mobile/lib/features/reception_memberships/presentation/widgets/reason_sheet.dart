import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/error/error_mapper.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';

/// A modal asking for a required reason, then running [submit] with it.
/// Resolves to true once [submit] succeeded, null when dismissed.
Future<bool?> showReasonSheet(
  BuildContext context, {
  required String title,
  required String confirmLabel,
  required String emptyMessage,
  required Future<void> Function(String reason) submit,
  String label = 'Lý do huỷ (bắt buộc)',
  String? summary,
  bool destructive = true,
}) =>
    showHvpSheet<bool>(
      context,
      title: title,
      builder: (_) => _ReasonSheet(
        label: label,
        confirmLabel: confirmLabel,
        emptyMessage: emptyMessage,
        submit: submit,
        summary: summary,
        destructive: destructive,
      ),
    );

class _ReasonSheet extends StatefulWidget {
  const _ReasonSheet({
    required this.label,
    required this.confirmLabel,
    required this.emptyMessage,
    required this.submit,
    required this.destructive,
    this.summary,
  });

  final String label;
  final String confirmLabel;
  final String emptyMessage;
  final String? summary;
  final bool destructive;
  final Future<void> Function(String reason) submit;

  @override
  State<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends State<_ReasonSheet> {
  final TextEditingController _reason = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final reason = _reason.text.trim();
    if (reason.isEmpty) {
      // The toast sits behind the sheet, so the message is also shown inside it.
      HvpToast.error(context, widget.emptyMessage);
      setState(() => _error = widget.emptyMessage);
      return;
    }
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await widget.submit(reason);
      if (mounted) Navigator.of(context).pop(true);
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
            HvpTextField(
                label: widget.label,
                controller: _reason,
                maxLines: 3,
                maxLength: 500),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 12),
              InlineBanner(message: _error!)
            ],
            const SizedBox(height: 16),
            widget.destructive
                ? HvpButton.danger(
                    label: widget.confirmLabel,
                    expand: true,
                    loading: _submitting,
                    onPressed: _submitting ? null : _confirm)
                : HvpButton.primary(
                    label: widget.confirmLabel,
                    expand: true,
                    loading: _submitting,
                    onPressed: _submitting ? null : _confirm),
          ],
        ),
      );
}
