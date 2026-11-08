import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/hvp_context.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/hvp_card.dart';
import '../../../../core/widgets/section_header.dart';
import '../../../fighter_record/presentation/providers/fighter_record_providers.dart';
import '../../domain/profile_models.dart';
import '../providers/profile_providers.dart';

/// AUTH-12: personal info of the student Hồ sơ tab.
class ProfileDetails extends ConsumerWidget {
  const ProfileDetails({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    // The rank name is not in the profile response: reuse the fighter record.
    final rank =
        ref.watch(rankProgressProvider).valueOrNull?.current.displayName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        const SectionHeader(
            title: 'Thông tin cá nhân',
            padding: EdgeInsets.only(top: 20, bottom: 10)),
        AsyncBody<MemberProfile>(
          value: profile,
          onRetry: () => ref.invalidate(profileProvider),
          loading: const SizedBox(
              height: 160, child: Center(child: CircularProgressIndicator())),
          builder: (_, p) => HvpCard(
            child: Column(
              children: <Widget>[
                _InfoRow(label: 'Họ và tên', value: p.fullName),
                _InfoRow(label: 'Số điện thoại', value: p.phone),
                _InfoRow(label: 'Email', value: p.email),
                _InfoRow(
                    label: 'Ngày tham gia',
                    value: p.joinedAt == null ? null : formatDate(p.joinedAt!)),
                _InfoRow(label: 'Hạng hiện tại', value: rank),
                _InfoRow(label: 'Trạng thái tài khoản', value: p.statusLabel),
                _InfoRow(label: 'Chi nhánh chính', value: p.homeBranchName),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(flex: 4, child: Text(label, style: t.bodySmall)),
          Expanded(
            flex: 6,
            child: Text(value == null || value!.isEmpty ? '—' : value!,
                style: t.body, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
