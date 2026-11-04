package com.comicreading.repository;
import com.comicreading.entity.Favorite;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
import java.util.Optional;
public interface FavoriteRepository extends JpaRepository<Favorite, Long> { List<Favorite> findByUserId(Long userId); Optional<Favorite> findByUserIdAndComicId(Long userId, Long comicId); }
