package com.comicreading.repository;

import com.comicreading.entity.Chapter;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ChapterRepository extends JpaRepository<Chapter, Long> {
    List<Chapter> findByComicIdOrderByChapterNumberAsc(Long comicId);
    List<Chapter> findByModerationStatusInOrderByCreatedAtAsc(List<String> statuses);
}
