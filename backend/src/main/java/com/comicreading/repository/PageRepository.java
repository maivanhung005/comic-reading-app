package com.comicreading.repository;
import com.comicreading.entity.Page;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
public interface PageRepository extends JpaRepository<Page, Long> {
    List<Page> findByChapterIdOrderByPageNumberAsc(Long chapterId);
    Optional<Page> findByImageUrl(String imageUrl);
}
