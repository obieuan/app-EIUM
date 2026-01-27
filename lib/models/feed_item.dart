class FeedItem {
  final String type; // 'event' or 'activity'
  final int id;
  final String title;
  final String? description;
  final DateTime? startAt;
  final DateTime? endAt;
  final String? imagePath;
  final String? locationName;
  final String? tagName;
  final bool registrationOpen; // for activities
  final bool enrollmentOpen; // for events
  final bool hasTickets; // for events

  const FeedItem({
    required this.type,
    required this.id,
    required this.title,
    this.description,
    this.startAt,
    this.endAt,
    this.imagePath,
    this.locationName,
    this.tagName,
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
      description: eventSummary.description,
      startAt: eventSummary.startAt,
      endAt: eventSummary.endAt,
      imagePath: eventSummary.imagePath,
      tagName: eventSummary.tagName,
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
      description: activitySummary.description,
      startAt: activitySummary.startAt,
      endAt: activitySummary.endAt,
      imagePath: activitySummary.imagePath,
      locationName: activitySummary.locationName,
      tagName: activitySummary.typeName,
      registrationOpen: activitySummary.registrationOpen,
    );
  }

  bool get isEvent => type == 'event';
  bool get isActivity => type == 'activity';
}
