package com.comicreading.repository;

import com.comicreading.entity.ComicComment;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface ComicCommentRepository extends JpaRepository<ComicComment, Long> {
    List<ComicComment> findTop20ByComicIdAndStatusOrderByCreatedAtDesc(Long comicId, String status);
    List<ComicComment> findTop5ByComicIdInAndStatusOrderByCreatedAtDesc(List<Long> comicIds, String status);
    long countByComicIdInAndStatus(List<Long> comicIds, String status);
    long countByComicIdAndStatus(Long comicId, String status);
    java.util.Optional<ComicComment> findFirstByComicIdAndStatusOrderByCreatedAtDesc(Long comicId, String status);
}
