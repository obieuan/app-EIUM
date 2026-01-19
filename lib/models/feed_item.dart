class FeedItem {
  final String type; // 'event' or 'activity'
  final int id;
  final String title;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? imagePath;
  final String? locationName;
  final bool registrationOpen; // for activities
  final bool enrollmentOpen; // for events
  final bool hasTickets; // for events

  const FeedItem({
    required this.type,
    required this.id,
    required this.title,
    this.startAt,
    this.endAt,
    this.imagePath,
    this.locationName,
    this.registrationOpen = false,
    this.enrollmentOpen = false,
    this.hasTickets = false,
  });

  // Create from EventSummary
  factory FeedItem.fromEvent(dynamic eventSummary) {
    return FeedItem(
      type: 'event',
      id: eventSummary.id,
      title: eventSummary.title,
      startAt: eventSummary.startAt,
      endAt: eventSummary.endAt,
      imagePath: eventSummary.imagePath,
      enrollmentOpen: eventSummary.enrollmentOpen,
      hasTickets: eventSummary.hasTickets,
    );
  }

  // Create from ActivitySummary
  factory FeedItem.fromActivity(dynamic activitySummary) {
    return FeedItem(
      type: 'activity',
      id: activitySummary.id,
      title: activitySummary.title,
      startAt: activitySummary.startAt,
      endAt: activitySummary.endAt,
      imagePath: activitySummary.imagePath,
      locationName: activitySummary.locationName,
      registrationOpen: activitySummary.registrationOpen,
    );
  }

  bool get isEvent => type == 'event';
  bool get isActivity => type == 'activity';
}
