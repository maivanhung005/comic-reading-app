package com.comicreading.entity;

import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name = "followed_authors", uniqueConstraints = @UniqueConstraint(columnNames = {"user_id", "author_name"}))
@Getter
@Setter
@NoArgsConstructor
@AllArgsConstructor
@Builder
public class FollowedAuthor {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(name = "user_id", nullable = false)
    private Long userId;

    @Column(name = "author_name", nullable = false, length = 180)
    private String authorName;

    @Builder.Default
    @Column(name = "followed_at", nullable = false)
    private LocalDateTime followedAt = LocalDateTime.now();
}
