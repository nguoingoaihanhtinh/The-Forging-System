import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/branch/branch.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/error/api_exception.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../domain/branch_input.dart';
import '../providers/branch_admin_providers.dart';
import '../screens/branch_static_qr_screen.dart';
import 'branch_reason_sheet.dart';

/// BR-05: add a branch, or edit [branch].
class BranchFormSheet extends ConsumerStatefulWidget {
  const BranchFormSheet({super.key, this.branch});

  final Branch? branch;

  @override
  ConsumerState<BranchFormSheet> createState() => _BranchFormSheetState();
}

class _BranchFormSheetState extends ConsumerState<BranchFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final _code = TextEditingController(text: widget.branch?.code);
  late final _name = TextEditingController(text: widget.branch?.name);
  late final _address = TextEditingController(text: widget.branch?.address);
  late final _hours = TextEditingController(text: widget.branch?.openingHours);
  late final _lat =
      TextEditingController(text: widget.branch?.latitude?.toString());
  late final _lng =
      TextEditingController(text: widget.branch?.longitude?.toString());
  late final _radius = TextEditingController(
      text: (widget.branch?.geofenceRadiusM ?? 100).toString());

  /// BRANCH_CODE_TAKEN, shown under the code field until it is edited.
  String? _codeTaken;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(branchFormSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    for (final c in <TextEditingController>[
      _code,
      _name,
      _address,
      _hours,
      _lat,
      _lng,
      _radius
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _codeTaken = null);
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final input = BranchInput(
      code: _code.text.trim().toUpperCase(),
      name: _name.text,
      address: _address.text,
      openingHours: _hours.text,
      latitude: BranchRules.parseCoordinate(_lat.text),
      longitude: BranchRules.parseCoordinate(_lng.text),
      geofenceRadiusM: int.parse(_radius.text.trim()),
    );
    final repo = ref.read(branchAdminRepositoryProvider);
    final editing = widget.branch;
    final ok = await ref.read(branchFormSubmitProvider.notifier).run(() async {
      try {
        editing == null
            ? await repo.create(input)
            : await repo.update(editing.id, input);
      } on ApiException catch (e) {
        if (e.code == 'BRANCH_CODE_TAKEN' && mounted) {
          setState(() => _codeTaken = e.message);
          _formKey.currentState?.validate();
        }
        rethrow;
      }
    });
    if (!mounted || !ok) return;
    ref.invalidate(adminBranchesProvider);
    HvpToast.success(
        context, editing == null ? 'Đã tạo chi nhánh' : 'Đã lưu thay đổi');
    Navigator.of(context).pop();
  }

  /// Extra: the on/off switch asks for a reason, then closes the form.
  Future<void> _toggleActive(Branch branch, bool isActive) async {
    final repo = ref.read(branchAdminRepositoryProvider);
    final done = await showReasonSheet(
      context,
      title: isActive ? 'Kích hoạt lại chi nhánh' : 'Ngừng hoạt động chi nhánh',
      confirmLabel: isActive ? 'Kích hoạt lại' : 'Ngừng hoạt động',
      required: true,
      submit: branchStatusSubmitProvider,
      onConfirm: (reason) =>
          repo.setActive(branch.id, isActive: isActive, reason: reason!),
    );
    if (!mounted || done != true) return;
    ref.invalidate(adminBranchesProvider);
    HvpToast.success(
        context,
        isActive
            ? 'Đã kích hoạt lại chi nhánh'
            : 'Đã ngừng hoạt động chi nhánh');
    Navigator.of(context).pop();
  }

  /// BR-06: warns that printed codes stop working, rotates, then closes the form.
  Future<void> _rotateQr(Branch branch) async {
    final repo = ref.read(branchAdminRepositoryProvider);
    final done = await showReasonSheet(
      context,
      title: 'Đổi mã QR',
      warning: 'Mã QR đã in sẽ không còn dùng được. '
          'Bạn cần in lại mã mới cho chi nhánh này.',
      confirmLabel: 'Đổi mã QR',
      required: false,
      submit: branchRotateSubmitProvider,
      onConfirm: (reason) => repo.rotateQr(branch.id, reason: reason),
    );
    if (!mounted || done != true) return;
    ref.invalidate(adminBranchesProvider);
    HvpToast.success(context, 'Đã đổi mã QR check-in.');
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(branchFormSubmitProvider);
    // The code error sits under its field, so the banner skips it.
    final fieldErrors = submit.fieldErrors;
    final banner = _codeTaken != null ? null : submit.error;
    const gap = SizedBox(height: 14);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            HvpTextField(
              label: 'Mã chi nhánh',
              controller: _code,
              maxLength: 20,
              inputFormatters: <TextInputFormatter>[_UpperCase()],
              textInputAction: TextInputAction.next,
              onChanged: (_) {
                if (_codeTaken != null) setState(() => _codeTaken = null);
              },
              validator: (v) =>
                  BranchRules.code(v) ?? _codeTaken ?? fieldErrors['code'],
            ),
            gap,
            HvpTextField(
                label: 'Tên chi nhánh',
                controller: _name,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                validator: BranchRules.name),
            gap,
            HvpTextField(
                label: 'Địa chỉ',
                controller: _address,
                maxLength: 255,
                textInputAction: TextInputAction.next,
                validator: BranchRules.address),
            gap,
            HvpTextField(
                label: 'Giờ mở cửa',
                hint: '06:00 – 21:30',
                controller: _hours,
                maxLength: 100,
                textInputAction: TextInputAction.next,
                validator: BranchRules.openingHours),
            gap,
            Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: HvpTextField(
                        label: 'Vĩ độ',
                        controller: _lat,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        textInputAction: TextInputAction.next,
                        validator: BranchRules.latitude),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: HvpTextField(
                        label: 'Kinh độ',
                        controller: _lng,
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true, signed: true),
                        textInputAction: TextInputAction.next,
                        validator: BranchRules.longitude),
                  ),
                ]),
            gap,
            HvpTextField(
                label: 'Bán kính check-in (m)',
                controller: _radius,
                keyboardType: TextInputType.number,
                validator: BranchRules.radius),
            if (banner != null) ...<Widget>[
              const SizedBox(height: 16),
              InlineBanner(message: banner),
            ],
            const SizedBox(height: 24),
            HvpButton.primary(
                label: widget.branch == null ? 'Tạo chi nhánh' : 'Lưu thay đổi',
                expand: true,
                loading: submit.submitting,
                onPressed: submit.submitting ? null : _submit),
            if (widget.branch != null)
              // Material ancestor so the tile's ink shows above the sheet's decorated container.
              Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: widget.branch!.isActive,
                  activeThumbColor: context.hvp.gold,
                  title: Text('Đang hoạt động', style: context.txt.body),
                  onChanged: (v) => _toggleActive(widget.branch!, v),
                ),
              ),
            if (widget.branch != null) ...<Widget>[
              Text('Mã QR: phiên bản ${widget.branch!.qrVersion ?? '1'}',
                  style: context.txt.caption),
              const SizedBox(height: 8),
              HvpButton.secondary(
                  label: 'Xem mã QR để in',
                  expand: true,
                  onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                          builder: (_) => BranchStaticQrScreen(
                              branchId: widget.branch!.id,
                              branchName: widget.branch!.name)))),
              const SizedBox(height: 8),
              HvpButton.danger(
                  label: 'Đổi mã QR',
                  expand: true,
                  onPressed: () => _rotateQr(widget.branch!)),
            ],
          ],
        ),
      ),
    );
  }
}

class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
          TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
