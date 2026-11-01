/// One entry of the learner's inbox (personal notifications and branch / rank broadcasts).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.eventType,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.isRead,
    this.payload = const <String, dynamic>{},
  });

  final String id;

  /// Machine event (`RANK_EARNED`, `SESSION_COMPLETED`, `BROADCAST`...); picks the icon and, later, the target screen.
  final String eventType;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool isRead;

  /// Extra data of the event (ids of what it is about); may be empty.
  final Map<String, dynamic> payload;

  AppNotification asRead() => AppNotification(
        id: id,
        eventType: eventType,
        title: title,
        body: body,
        createdAt: createdAt,
        isRead: true,
        payload: payload,
      );
}

/// One page of the inbox.
class NotificationPage {
  const NotificationPage({required this.items, required this.unread, required this.total, required this.hasMore});

  final List<AppNotification> items;

  /// Unread notifications over the whole inbox, not just this page.
  final int unread;

  /// Notifications in the whole inbox, read or not.
  final int total;

  /// Whether a later page exists.
  final bool hasMore;
}

abstract interface class NotificationRepository {
  Future<NotificationPage> list({required int page, required int limit});

  Future<void> markRead(String id);

  Future<void> markAllRead();
}
