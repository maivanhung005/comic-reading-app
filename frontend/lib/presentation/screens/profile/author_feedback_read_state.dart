import 'package:shared_preferences/shared_preferences.dart';

/// Stores feedback read markers per account and comic on this device.
/// Feedback timestamps come from PostgreSQL and are compared with the last
/// timestamp the author actually opened in the feedback screen.
class AuthorFeedbackReadState {
  static String _key(int userId, int comicId) => 'author_feedback_seen_${userId}_$comicId';

  static DateTime? _parse(dynamic raw) {
    final value = raw == null ? '' : raw.toString().trim();
    if (value.isEmpty) return null;
    return DateTime.tryParse(value);
  }

  static DateTime? latestAt(Map<String, dynamic> summary) {
    final values = <DateTime>[
      if (_parse(summary['latestFeedbackAt']) != null) _parse(summary['latestFeedbackAt'])!,
      if (_parse(summary['latestCommentAt']) != null) _parse(summary['latestCommentAt'])!,
      if (_parse(summary['latestReviewAt']) != null) _parse(summary['latestReviewAt'])!,
    ];
    if (values.isEmpty) return null;
    values.sort();
    return values.last;
  }

  static Future<bool> hasUnread(int userId, int comicId, Map<String, dynamic> summary) async {
    final latest = latestAt(summary);
    if (latest == null) return false;
    final prefs = await SharedPreferences.getInstance();
    final seen = _parse(prefs.getString(_key(userId, comicId)));
    return seen == null || latest.isAfter(seen);
  }

  static Future<void> markSeen(int userId, int comicId, Map<String, dynamic> feedback) async {
    // Do not write a client clock timestamp when the comic has no feedback;
    // server timestamps remain the source of truth for future unread indicators.
    final latest = latestAt(feedback);
    if (latest == null) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(userId, comicId), latest.toIso8601String());
  }
}
