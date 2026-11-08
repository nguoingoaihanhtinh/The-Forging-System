import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_app_bar.dart';
import '../../domain/branch_qr.dart';
import '../providers/branch_admin_providers.dart';

/// BR-06: full-screen printable QR of a branch.
class BranchStaticQrScreen extends ConsumerWidget {
  const BranchStaticQrScreen(
      {super.key, required this.branchId, required this.branchName});

  final String branchId;
  final String branchName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qr = ref.watch(branchStaticQrProvider(branchId));
    return Scaffold(
      appBar: const HvpAppBar(title: 'Mã QR chi nhánh'),
      body: AsyncBody<BranchQr>(
        value: qr,
        onRetry: () => ref.invalidate(branchStaticQrProvider(branchId)),
        builder: (context, data) => _QrView(name: branchName, qr: data),
      ),
    );
  }
}

class _QrView extends StatelessWidget {
  const _QrView({required this.name, required this.qr});

  final String name;
  final BranchQr qr;

  @override
  Widget build(BuildContext context) {
    final c = context.hvp;
    final t = context.txt;
    return LayoutBuilder(
      builder: (context, box) {
        final size = (box.maxWidth - 96).clamp(160.0, 360.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: <Widget>[
              Text(name, style: t.titleL, textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('${qr.code} · Mã QR: phiên bản ${qr.qrVersion}',
                  style: t.body),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: c.gold, width: 3),
                ),
                child: QrImageView(
                  key: ValueKey<String>('qr:${qr.payload}'),
                  data: qr.payload,
                  size: size,
                  backgroundColor: Colors.white,
                  padding: EdgeInsets.zero,
                  semanticsLabel: 'Mã QR in của chi nhánh ${qr.code}',
                ),
              ),
              const SizedBox(height: 20),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(HvpIcons.warning, color: c.amber),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Đây là mã để in, không phải mã check-in. Học viên check-in '
                      'bằng mã xoay vòng trên màn hình QR của lễ tân.',
                      style: t.body,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
