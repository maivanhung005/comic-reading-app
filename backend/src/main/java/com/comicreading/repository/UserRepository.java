package com.comicreading.repository;

import com.comicreading.entity.User;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.Pageable;
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import java.util.List;
import java.util.Optional;

public interface UserRepository extends JpaRepository<User, Long> {
    Optional<User> findByEmail(String email);
    Optional<User> findByEmailIgnoreCase(String email);
    Optional<User> findByUsernameIgnoreCase(String username);
    boolean existsByEmail(String email);
    boolean existsByUsername(String username);
    boolean existsByUsernameIgnoreCase(String username);
    List<User> findAllByOrderByCreatedAtDesc();
    long countByRoleIgnoreCase(String role);

    @Query("""
        SELECT u FROM User u
        WHERE UPPER(u.role) <> 'ADMIN'
          AND (:role = 'ALL' OR UPPER(u.role) = :role OR (:role = 'READER' AND UPPER(u.role) = 'USER'))
          AND (:search = ''
               OR LOWER(u.email) LIKE LOWER(CONCAT('%', :search, '%'))
               OR LOWER(COALESCE(u.username, '')) LIKE LOWER(CONCAT('%', :search, '%'))
               OR LOWER(u.name) LIKE LOWER(CONCAT('%', :search, '%')))
        """)
    Page<User> searchManageableUsers(@Param("search") String search, @Param("role") String role, Pageable pageable);
}
