import '../entities/comic_entity.dart';
import 'dart:math';

class RecommendationEngine {
  static List<ComicEntity> recommend(List<ComicEntity> comics, List<int> interactedIds) {
    if (comics.isEmpty) return const [];
    final interacted = comics.where((comic) => interactedIds.contains(comic.id)).toList();
    if (interacted.isEmpty) {
      final sorted = [...comics]..sort((a, b) => b.views.compareTo(a.views));
      return sorted.map((comic) => comic.copyWith(similarityScore: 0.5)).toList();
    }
    final vocabulary = comics.expand((comic) => comic.tags).toSet().toList();
    final userVector = vocabulary.map((tag) => interacted.where((comic) => comic.tags.contains(tag)).length.toDouble()).toList();
    final ranked = comics.map((comic) {
      final vector = vocabulary.map((tag) => comic.tags.contains(tag) ? 1.0 : 0.0).toList();
      double dot = 0, a = 0, b = 0;
      for (var i = 0; i < vector.length; i++) {
        dot += userVector[i] * vector[i];
        a += userVector[i] * userVector[i];
        b += vector[i] * vector[i];
      }
      final score = a == 0 || b == 0 ? 0.0 : dot / (sqrt(a) * sqrt(b));
      return comic.copyWith(similarityScore: score);
    }).toList();
    ranked.sort((a, b) => b.similarityScore.compareTo(a.similarityScore));
    return ranked;
  }
}
