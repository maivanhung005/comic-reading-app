package com.comicreading.repository;

import com.comicreading.entity.FollowedAuthor;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface FollowedAuthorRepository extends JpaRepository<FollowedAuthor, Long> {
    List<FollowedAuthor> findByUserIdOrderByFollowedAtDesc(Long userId);
    Optional<FollowedAuthor> findByUserIdAndAuthorNameIgnoreCase(Long userId, String authorName);
    long countByAuthorNameIgnoreCase(String authorName);
    @Query("select count(distinct f.userId) from FollowedAuthor f where lower(f.authorName) in :names")
    long countDistinctFollowersForAuthorNames(@Param("names") List<String> lowerNames);

    @Query("select f from FollowedAuthor f where lower(f.authorName) in :names order by f.followedAt desc")
    List<FollowedAuthor> findFollowersForAuthorNames(@Param("names") List<String> lowerNames);
}
