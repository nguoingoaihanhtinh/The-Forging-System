import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';

/// Asks for the 6 digits shown under the QR on the front-desk screen, for members who cannot scan.
/// Resolves to the digits, or null if dismissed.
Future<String?> showManualCodeSheet(BuildContext context) =>
    showHvpSheet<String>(context, title: 'Nhập mã check-in', builder: (_) => const _ManualCodeForm());

class _ManualCodeForm extends StatefulWidget {
  const _ManualCodeForm();

  @override
  State<_ManualCodeForm> createState() => _ManualCodeFormState();
}

class _ManualCodeFormState extends State<_ManualCodeForm> {
  final TextEditingController _controller = TextEditingController();

  bool get _complete => _controller.text.length == 6;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (_complete) Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Text('Nhập 6 chữ số hiển thị dưới mã QR trên màn hình phòng tập.', style: t.bodySmall),
          const SizedBox(height: 16),
          HvpTextField(
            label: 'Mã 6 số',
            controller: _controller,
            hint: '000000',
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            textAlign: TextAlign.center,
            inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: 16),
          HvpButton.gold(label: 'Check-in', onPressed: _complete ? _submit : null),
        ],
      ),
    );
  }
}
