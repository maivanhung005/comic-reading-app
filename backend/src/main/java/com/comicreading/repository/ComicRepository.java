package com.comicreading.repository;
import com.comicreading.entity.Comic;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
public interface ComicRepository extends JpaRepository<Comic, Long> {
    List<Comic> findByTitleContainingIgnoreCaseOrAuthorContainingIgnoreCase(String title, String author);
    List<Comic> findByModerationStatusOrderByCreatedAtDesc(String moderationStatus);
    List<Comic> findByCreatedByUserIdOrderByCreatedAtDesc(Long userId);
    Optional<Comic> findByCoverUrl(String coverUrl);
}
