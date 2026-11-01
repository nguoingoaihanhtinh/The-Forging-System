import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_button.dart';

/// Builds the camera view that reports every QR text it reads. Replaced in tests, where there is no camera.
typedef QrScannerBuilder = Widget Function(BuildContext context, ValueChanged<String> onCode);

Widget cameraQrScannerBuilder(BuildContext context, ValueChanged<String> onCode) => CameraQrScanner(onCode: onCode);

/// Live camera preview reading QR codes (back camera). Explains what to do when the camera cannot be used.
class CameraQrScanner extends StatefulWidget {
  const CameraQrScanner({super.key, required this.onCode});

  final ValueChanged<String> onCode;

  @override
  State<CameraQrScanner> createState() => _CameraQrScannerState();
}

class _CameraQrScannerState extends State<CameraQrScanner> {
  late final MobileScannerController _controller = MobileScannerController(formats: const <BarcodeFormat>[BarcodeFormat.qrCode]);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    for (final barcode in capture.barcodes) {
      final text = barcode.rawValue;
      if (text != null && text.isNotEmpty) {
        widget.onCode(text);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MobileScanner(
      controller: _controller,
      onDetect: _onDetect,
      errorBuilder: (context, error, _) => _CameraProblem(code: error.errorCode, onRetry: _controller.start),
    );
  }
}

class _CameraProblem extends StatelessWidget {
  const _CameraProblem({required this.code, required this.onRetry});

  final MobileScannerErrorCode code;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    final message = switch (code) {
      MobileScannerErrorCode.permissionDenied =>
        'Ứng dụng chưa được cấp quyền camera. Hãy bật quyền camera trong Cài đặt của điện thoại rồi thử lại.',
      MobileScannerErrorCode.unsupported => 'Thiết bị này không có camera để quét mã. Hãy nhờ lễ tân check-in hộ.',
      _ => 'Không mở được camera. Hãy thử lại, hoặc nhờ lễ tân check-in hộ.',
    };
    return ColoredBox(
      color: Colors.black,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const Icon(HvpIcons.scan, size: 48, color: Colors.white70),
              const SizedBox(height: 16),
              Text(message, style: t.body.copyWith(color: Colors.white), textAlign: TextAlign.center),
              if (code != MobileScannerErrorCode.unsupported) ...<Widget>[
                const SizedBox(height: 20),
                HvpButton.secondary(label: 'Thử lại', onPressed: onRetry, small: true),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
