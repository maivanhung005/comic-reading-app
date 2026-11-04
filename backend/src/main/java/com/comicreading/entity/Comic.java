package com.comicreading.entity;

import jakarta.persistence.*;
import com.fasterxml.jackson.annotation.JsonIgnore;
import lombok.*;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;

@Entity
@Table(name = "comics")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Comic {
    @Id @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    @Column(nullable = false)
    private String title;
    private String author;
    @Column(columnDefinition = "TEXT")
    private String description;
    @Column(name = "cover_url")
    private String coverUrl;

    @ElementCollection(fetch = FetchType.EAGER)
    @CollectionTable(name = "comic_tags", joinColumns = @JoinColumn(name = "comic_id"))
    @Column(name = "tag")
    @Builder.Default private List<String> tags = new ArrayList<>();

    /** Work progress only, e.g. Đang tiến hành / Hoàn thành. */
    @Builder.Default private String status = "Đang tiến hành";

    /** Ownership is an account ID, distinct from the display-name `author` field. */
    @JsonIgnore
    @Column(name = "created_by_user_id")
    private Long createdByUserId;

    /** PENDING / APPROVED / HIDDEN / REJECTED. Null legacy rows are migrated to APPROVED. */
    @Column(name = "moderation_status", length = 24)
    @Builder.Default private String moderationStatus = "PENDING";

    /** Effective age rating derived from approved chapters. */
    @Column(name = "age_rating", length = 16)
    @Builder.Default private String ageRating = "ALL_AGES";

    /** Author-proposed rating. A moderator assigns each chapter's actual rating. */
    @Column(name = "suggested_age_rating", length = 16)
    @Builder.Default private String suggestedAgeRating = "ALL_AGES";

    @JsonIgnore
    @Column(name = "review_notes", columnDefinition = "TEXT")
    private String reviewNotes;

    @JsonIgnore
    @Column(name = "reviewed_by_user_id")
    private Long reviewedByUserId;

    @Column(name = "reviewed_at")
    private LocalDateTime reviewedAt;

    @Builder.Default
    @Column(name = "created_at")
    private LocalDateTime createdAt = LocalDateTime.now();
}
