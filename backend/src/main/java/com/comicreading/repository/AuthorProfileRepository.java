package com.comicreading.repository;
import com.comicreading.entity.AuthorProfile;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;
public interface AuthorProfileRepository extends JpaRepository<AuthorProfile, Long> {
    Optional<AuthorProfile> findByUserId(Long userId);
}
