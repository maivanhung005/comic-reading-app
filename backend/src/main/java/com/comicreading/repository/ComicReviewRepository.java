package com.comicreading.repository;

import com.comicreading.entity.ComicReview;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface ComicReviewRepository extends JpaRepository<ComicReview, Long> {
    Optional<ComicReview> findByComicIdAndUserId(Long comicId, Long userId);
    List<ComicReview> findTop20ByComicIdOrderByUpdatedAtDesc(Long comicId);
    Optional<ComicReview> findFirstByComicIdOrderByUpdatedAtDesc(Long comicId);
    List<ComicReview> findTop5ByComicIdInOrderByUpdatedAtDesc(List<Long> comicIds);
    List<ComicReview> findByComicIdIn(List<Long> comicIds);
    long countByComicIdIn(List<Long> comicIds);
    long countByComicId(Long comicId);
    @Query("select coalesce(avg(r.rating), 0.0) from ComicReview r where r.comicId = :comicId")
    double averageRatingForComic(@Param("comicId") Long comicId);
    @Query("select coalesce(avg(r.rating), 0.0) from ComicReview r where r.comicId in :comicIds")
    double averageRatingForComics(@Param("comicIds") List<Long> comicIds);
}
