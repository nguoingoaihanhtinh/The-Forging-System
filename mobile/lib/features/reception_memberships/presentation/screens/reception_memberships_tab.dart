import 'package:flutter/material.dart';

import '../../../../core/design/hvp_context.dart';
import 'members_tab.dart';
import 'renewal_requests_view.dart';

/// Reception tab "Gói tập": the renewal inbox and the learner list.
class ReceptionMembershipsTab extends StatelessWidget {
  const ReceptionMembershipsTab({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 2,
        child: Column(
          children: <Widget>[
            Material(
              color: context.hvp.surface,
              child: const TabBar(
                  tabs: <Widget>[Tab(text: 'Yêu cầu'), Tab(text: 'Học viên')]),
            ),
            const Expanded(
              child: TabBarView(
                children: <Widget>[
                  RenewalRequestsView(),
                  MembersTab(),
                ],
              ),
            ),
          ],
        ),
      );
}
