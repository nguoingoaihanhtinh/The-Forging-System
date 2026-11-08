import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/state/submit_notifier.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/inline_banner.dart';

/// Asks for a reason (3-500 characters), then runs [onConfirm] with it. The sheet closes with `true` once
/// [onConfirm] succeeds. With [required] false an empty reason is allowed and passed on as null.
Future<bool?> showReasonSheet(
  BuildContext context, {
  required String title,
  String? warning,
  required String confirmLabel,
  required bool required,
  required NotifierProvider<SubmitNotifier, SubmitState> submit,
  required Future<void> Function(String? reason) onConfirm,
}) =>
    showHvpSheet<bool>(
      context,
      title: title,
      builder: (_) => _ReasonSheet(
        warning: warning,
        confirmLabel: confirmLabel,
        required: required,
        submit: submit,
        onConfirm: onConfirm,
      ),
    );

class _ReasonSheet extends ConsumerStatefulWidget {
  const _ReasonSheet({
    required this.warning,
    required this.confirmLabel,
    required this.required,
    required this.submit,
    required this.onConfirm,
  });

  final String? warning;
  final String confirmLabel;
  final bool required;
  final NotifierProvider<SubmitNotifier, SubmitState> submit;
  final Future<void> Function(String? reason) onConfirm;

  @override
  ConsumerState<_ReasonSheet> createState() => _ReasonSheetState();
}

class _ReasonSheetState extends ConsumerState<_ReasonSheet> {
  final _formKey = GlobalKey<FormState>();
  final _reason = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(() => ref.read(widget.submit.notifier).reset());
  }

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  String? _validate(String? v) {
    final n = (v ?? '').trim().length;
    if (n == 0 && !widget.required) return null;
    return n >= 3 && n <= 500 ? null : 'Lý do gồm 3–500 ký tự.';
  }

  Future<void> _confirm() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final text = _reason.text.trim();
    final ok = await ref
        .read(widget.submit.notifier)
        .run(() => widget.onConfirm(text.isEmpty ? null : text));
    if (mounted && ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.submit);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (widget.warning != null) ...<Widget>[
              Text(widget.warning!,
                  style: context.txt.body.copyWith(color: context.hvp.amber)),
              const SizedBox(height: 16),
            ],
            HvpTextField(
              label: widget.required ? 'Lý do (bắt buộc)' : 'Lý do (tuỳ chọn)',
              controller: _reason,
              maxLength: 500,
              maxLines: 3,
              validator: _validate,
            ),
            if (state.error != null) ...<Widget>[
              const SizedBox(height: 16),
              InlineBanner(message: state.error!),
            ],
            const SizedBox(height: 24),
            HvpButton.primary(
                label: widget.confirmLabel,
                expand: true,
                loading: state.submitting,
                onPressed: state.submitting ? null : _confirm),
            const SizedBox(height: 8),
            HvpButton.ghost(
                label: 'Huỷ',
                expand: true,
                onPressed: state.submitting
                    ? null
                    : () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}
