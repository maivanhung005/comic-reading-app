package com.comicreading.ai;
import com.comicreading.entity.Comic;
import com.comicreading.entity.ReadingHistory;
import com.comicreading.repository.ComicRepository;
import com.comicreading.repository.ReadingHistoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import java.util.*;
import java.util.stream.Collectors;
@Service @RequiredArgsConstructor
public class RecommendationService {
    private final ComicRepository comicRepository;
    private final ReadingHistoryRepository historyRepository;
    public List<Comic> recommendForUser(Long userId) {
        List<Comic> all = comicRepository.findAll();
        if (userId == null || all.isEmpty()) return all;
        List<ReadingHistory> history = historyRepository.findByUserIdOrderByReadAtDesc(userId);
        if (history.isEmpty()) return all;
        Set<Long> readIds = history.stream().map(ReadingHistory::getComicId).collect(Collectors.toSet());
        List<Comic> readComics = all.stream().filter(c -> readIds.contains(c.getId())).toList();
        List<String> vocabulary = all.stream().flatMap(c -> c.getTags().stream()).distinct().toList();
        Map<String, Double> counts = new HashMap<>();
        for (Comic c : readComics) for (String tag : c.getTags()) counts.merge(tag, 1.0, Double::sum);
        double[] userVector = new double[vocabulary.size()];
        for (int i=0; i<vocabulary.size(); i++) userVector[i] = counts.getOrDefault(vocabulary.get(i), 0.0);
        return all.stream().sorted((a,b) -> Double.compare(score(b,userVector,vocabulary), score(a,userVector,vocabulary))).limit(10).toList();
    }
    private double score(Comic comic, double[] userVector, List<String> vocabulary) {
        double[] v = new double[vocabulary.size()];
        for (int i=0; i<vocabulary.size(); i++) v[i] = comic.getTags().contains(vocabulary.get(i)) ? 1.0 : 0.0;
        return CosineSimilarity.calculate(userVector, v);
    }
}
