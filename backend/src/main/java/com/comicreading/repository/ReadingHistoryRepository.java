package com.comicreading.repository;

import com.comicreading.entity.ReadingHistory;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface ReadingHistoryRepository extends JpaRepository<ReadingHistory, Long> {
    List<ReadingHistory> findByUserIdOrderByReadAtDesc(Long userId);
    Optional<ReadingHistory> findFirstByUserIdAndComicIdAndChapterIdOrderByReadAtDesc(Long userId, Long comicId, Long chapterId);
    long countByComicIdIn(List<Long> comicIds);
    long countByComicId(Long comicId);
    @Query("select count(distinct rh.userId) from ReadingHistory rh where rh.comicId = :comicId")
    long countDistinctReadersByComicId(@Param("comicId") Long comicId);
    @Query("select count(distinct rh.userId) from ReadingHistory rh where rh.comicId in :comicIds")
    long countDistinctReadersByComicIds(@Param("comicIds") List<Long> comicIds);
}
