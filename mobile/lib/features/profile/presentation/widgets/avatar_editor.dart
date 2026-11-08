import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/design/color_utils.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/widgets/hvp_avatar.dart';
import '../../../../core/widgets/hvp_bottom_sheet.dart';
import '../../../../core/widgets/hvp_toast.dart';
import '../../../auth/presentation/providers/auth_controller.dart';
import '../providers/profile_providers.dart';

/// AUTH-14: avatar with a camera badge. Picks a photo, uploads it and saves it at once.
class AvatarEditor extends ConsumerWidget {
  const AvatarEditor({super.key, required this.name});

  final String name;

  Future<void> _change(BuildContext context, WidgetRef ref) async {
    final source = await showOptionSheet<ImageSource>(
      context,
      title: 'Ảnh đại diện',
      options: const <SheetOption<ImageSource>>[
        SheetOption<ImageSource>(
            value: ImageSource.camera,
            label: 'Chụp ảnh',
            icon: HvpIcons.camera),
        SheetOption<ImageSource>(
            value: ImageSource.gallery,
            label: 'Chọn từ thư viện',
            icon: HvpIcons.image),
      ],
    );
    if (source == null || !context.mounted) return;
    final picked = await ref.read(profileImagePickerProvider)(source);
    if (picked == null || !context.mounted) return;
    final ok = await ref.read(profileAvatarProvider.notifier).change(picked);
    if (!context.mounted) return;
    if (ok) {
      HvpToast.success(context, 'Đã cập nhật ảnh đại diện.');
    } else {
      HvpToast.error(
          context,
          ref.read(profileAvatarProvider).error ??
              'Không cập nhật được ảnh đại diện.');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.hvp;
    final busy = ref.watch(profileAvatarProvider).submitting;
    final url = ref.watch(currentUserProvider.select((u) => u?.avatarUrl));
    return Center(
      child: SizedBox(
        width: 96,
        height: 96,
        child: Stack(
          children: <Widget>[
            HvpAvatar(url: url, name: name, size: 88),
            if (busy)
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                      shape: BoxShape.circle, color: c.bg.fade(0.6)),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton.filled(
                tooltip: 'Đổi ảnh đại diện',
                style: IconButton.styleFrom(
                    backgroundColor: c.gold, foregroundColor: c.bg),
                onPressed: busy ? null : () => _change(context, ref),
                icon: const Icon(HvpIcons.camera, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
