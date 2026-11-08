import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../../core/widgets/inline_banner.dart';
import '../../../auth/domain/auth_validators.dart';
import '../../domain/profile_changes.dart';
import '../../domain/profile_models.dart';
import '../providers/profile_providers.dart';

/// AUTH-13: edit full name, phone and email. Sends only the changed fields.
class ProfileEditForm extends ConsumerStatefulWidget {
  const ProfileEditForm(
      {super.key, required this.profile, required this.onDone});

  final MemberProfile profile;

  /// Called after a successful save or on cancel.
  final VoidCallback onDone;

  @override
  ConsumerState<ProfileEditForm> createState() => _ProfileEditFormState();
}

class _ProfileEditFormState extends ConsumerState<ProfileEditForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.profile.fullName);
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  late final _email = TextEditingController(text: widget.profile.email ?? '');

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(
        () => ref.read(profileSaveProvider.notifier).reset());
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    super.dispose();
  }

  // Read at validation time: the widget has not rebuilt yet right after a failed save.
  String? _conflict(String field) =>
      ref.read(profileSaveProvider).fieldErrors[field];

  Future<void> _save() async {
    ref
        .read(profileSaveProvider.notifier)
        .reset(); // drop the previous conflict
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final changes = profileChanges(widget.profile,
        fullName: _name.text, phone: _phone.text, email: _email.text);
    if (changes.isEmpty) return widget.onDone();
    final ok = await ref.read(profileSaveProvider.notifier).save(changes);
    if (!mounted) return;
    if (ok) {
      HvpToast.success(context, 'Đã cập nhật hồ sơ.');
      widget.onDone();
    } else {
      _formKey.currentState?.validate(); // shows the phone / email conflict
    }
  }

  @override
  Widget build(BuildContext context) {
    final save = ref.watch(profileSaveProvider);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          HvpTextField(
            label: 'Họ và tên',
            controller: _name,
            maxLength: 100,
            validator: AuthValidators.fullName,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 12),
          HvpTextField(
            label: 'Số điện thoại',
            controller: _phone,
            keyboardType: TextInputType.phone,
            maxLength: 16,
            textInputAction: TextInputAction.next,
            validator: (v) =>
                ((v ?? '').trim().isEmpty ? null : AuthValidators.phone(v)) ??
                _conflict('phone'),
          ),
          const SizedBox(height: 12),
          HvpTextField(
            label: 'Email',
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            maxLength: 254,
            validator: (v) =>
                AuthValidators.optionalEmail(v) ?? _conflict('email'),
          ),
          if (save.error != null) ...<Widget>[
            const SizedBox(height: 12),
            InlineBanner(message: save.error!),
          ],
          const SizedBox(height: 16),
          HvpButton(
              label: 'Lưu thay đổi',
              expand: true,
              loading: save.submitting,
              onPressed: _save),
          const SizedBox(height: 8),
          HvpButton.secondary(
              label: 'Huỷ',
              expand: true,
              onPressed: save.submitting ? null : widget.onDone),
        ],
      ),
    );
  }
}
