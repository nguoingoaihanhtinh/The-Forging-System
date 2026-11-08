import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../app/route_paths.dart';
import '../../../../core/design/hvp_context.dart';
import '../../../../core/design/hvp_icons.dart';
import '../../../../core/design/hvp_layout.dart';
import '../../../../core/widgets/async_body.dart';
import '../../../../core/widgets/empty_state.dart';
import '../../../../core/widgets/hvp_button.dart';
import '../../../../core/widgets/hvp_text_field.dart';
import '../../../reception_checkin/domain/member_hit.dart';
import '../../../reception_checkin/presentation/reception_providers.dart';
import '../widgets/create_member_sheet.dart';
import '../widgets/member_row.dart';

/// "Học viên" tab: find a learner by name or phone and open their detail.
class MembersTab extends ConsumerStatefulWidget {
  const MembersTab({super.key});

  @override
  ConsumerState<MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<MembersTab> {
  Timer? _debounce;

  /// The text actually searched: it follows the field a moment after typing stops.
  String _query = '';

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _typed(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (mounted && value.trim() != _query) {
        setState(() => _query = value.trim());
      }
    });
  }

  Future<void> _create() async {
    final id = await showCreateMemberSheet(context);
    if (id != null && mounted) {
      await context.push(ReceptionPaths.membershipMember(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = context.txt;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Align(
            alignment: Alignment.centerLeft,
            child: HvpButton.secondary(
                label: 'Tạo học viên mới',
                icon: HvpIcons.plus,
                small: true,
                onPressed: _create),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: HvpTextField(
            label: 'Tìm học viên',
            hint: 'Tên hoặc số điện thoại',
            prefixIcon: HvpIcons.search,
            maxLength: 100,
            textInputAction: TextInputAction.search,
            onChanged: _typed,
            onSubmitted: (v) {
              _debounce?.cancel();
              setState(() => _query = v.trim());
            },
          ),
        ),
        Expanded(
          child: _query.length < memberSearchMinLength
              ? const EmptyState(
                  icon: HvpIcons.search,
                  title: 'Tìm học viên',
                  message: 'Nhập ít nhất 2 ký tự: tên hoặc số điện thoại.')
              : AsyncBody<MemberSearchResult>(
                  value: ref.watch(memberSearchProvider(_query)),
                  onRetry: () => ref.invalidate(memberSearchProvider(_query)),
                  builder: (context, result) {
                    if (result.items.isEmpty) {
                      return const EmptyState(
                          icon: HvpIcons.users,
                          title: 'Không tìm thấy học viên');
                    }
                    return ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                          16, 4, 16, HvpLayout.navClearance),
                      itemCount: result.items.length + 1,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        if (i == 0) {
                          return Text(
                            result.hasMoreThanShown
                                ? 'Hiển thị ${result.items.length} trên ${result.total} học viên. Gõ thêm để thu hẹp.'
                                : '${result.total} học viên',
                            style: t.caption,
                          );
                        }
                        final member = result.items[i - 1];
                        return MemberRow(
                            member: member,
                            onTap: () => context.push(
                                ReceptionPaths.membershipMember(member.id)));
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}
