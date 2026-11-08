import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/error/api_exception.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../auth/domain/auth_validators.dart';
import '../../../reception_checkin/presentation/reception_providers.dart';
import '../../domain/member_models.dart';
import '../../domain/phone_rules.dart';
import '../reception_memberships_providers.dart';

/// MEM-17: look the phone up, then create the learner. Resolves to the new learner's id, or null.
Future<String?> showCreateMemberSheet(BuildContext context) =>
    showHvpSheet<String>(
      context,
      title: 'Tạo học viên mới',
      builder: (_) => const _CreateMemberSheet(),
    );

class _CreateMemberSheet extends ConsumerStatefulWidget {
  const _CreateMemberSheet();

  @override
  ConsumerState<_CreateMemberSheet> createState() => _CreateMemberSheetState();
}

class _CreateMemberSheetState extends ConsumerState<_CreateMemberSheet> {
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _name = TextEditingController();

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(createMemberSubmitProvider.notifier).reset());
  }

  @override
  void dispose() {
    _phone.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final phone = normalizePhone(_phone.text.trim());
    CreatedMember? created;
    final ok =
        await ref.read(createMemberSubmitProvider.notifier).run(() async {
      final found =
          await ref.read(memberSearchRepositoryProvider).search(phone);
      for (final m in found.items) {
        if (samePhone(m.phone, phone)) {
          throw ApiException(
              code: 'PHONE_EXISTS',
              message: 'SĐT đã tồn tại: ${m.fullName} — không tạo mới.');
        }
      }
      created = await ref
          .read(receptionMembershipsRepositoryProvider)
          .createMember(fullName: _name.text.trim(), phone: phone);
    });
    if (!mounted || !ok || created == null) return;
    HvpToast.success(context, 'Đã tạo tài khoản mới (chưa trùng SĐT).');
    await showHvpSheet<void>(context,
        title: 'Đã tạo tài khoản',
        builder: (_) =>
            _PasswordResult(name: _name.text.trim(), created: created!));
    if (mounted) Navigator.of(context).pop(created!.id);
  }

  @override
  Widget build(BuildContext context) {
    final submit = ref.watch(createMemberSubmitProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Text(
                'Nhập số điện thoại trước: nếu đã có tài khoản, hệ thống sẽ không tạo mới.',
                style: context.txt.bodySmall),
            const SizedBox(height: 16),
            HvpTextField(
              label: 'Số điện thoại',
              controller: _phone,
              keyboardType: TextInputType.phone,
              maxLength: 16,
              textInputAction: TextInputAction.next,
              validator: AuthValidators.phone,
            ),
            const SizedBox(height: 14),
            HvpTextField(
                label: 'Họ và tên',
                controller: _name,
                maxLength: 100,
                validator: AuthValidators.fullName),
            if (submit.error != null) ...<Widget>[
              const SizedBox(height: 16),
              InlineBanner(message: submit.error!)
            ],
            const SizedBox(height: 24),
            HvpButton.primary(
                label: 'Tra cứu & tạo',
                expand: true,
                loading: submit.submitting,
                onPressed: submit.submitting ? null : _submit),
          ],
        ),
      ),
    );
  }
}

class _PasswordResult extends StatelessWidget {
  const _PasswordResult({required this.name, required this.created});

  final String name;
  final CreatedMember created;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('$name đăng nhập bằng số điện thoại và mật khẩu tạm dưới đây.',
                style: context.txt.body),
            if (created.temporaryPassword != null) ...<Widget>[
              const SizedBox(height: 16),
              SelectableText(created.temporaryPassword!,
                  style: context.txt.titleM.copyWith(color: context.hvp.gold)),
              const SizedBox(height: 8),
              Text(
                  'Sao chép và gửi mật khẩu này an toàn. Mật khẩu sẽ không hiện lại.',
                  style: context.txt.bodySmall),
            ],
            const SizedBox(height: 20),
            HvpButton.primary(
                label: 'Đã lưu mật khẩu',
                expand: true,
                onPressed: () => Navigator.of(context).pop()),
          ],
        ),
      );
}
