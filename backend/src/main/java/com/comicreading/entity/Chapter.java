package com.comicreading.entity;

import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;

@Entity
@Table(name="chapters", uniqueConstraints = @UniqueConstraint(name="uk_chapter_comic_number", columnNames={"comic_id", "chapter_number"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Chapter {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY)
    private Long id;

    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="comic_id", nullable=false) @JsonIgnore
    private Comic comic;

    @Column(name="chapter_number", nullable=false)
    private Integer chapterNumber;

    @Column(length=180)
    private String title;

    @Builder.Default @Column(name="is_vip") private Boolean isVip=false;
    @Builder.Default private Integer price=0;

    /** IMAGE for comic pages, TEXT for a prose chapter. */
    @Builder.Default @Column(name="content_type", length=16) private String contentType="IMAGE";
    @Column(name="content_text", columnDefinition="TEXT") private String contentText;

    /** PENDING / APPROVED / HIDDEN / REJECTED; chapter content is reviewed independently. */
    @Builder.Default @Column(name="moderation_status", length=24) private String moderationStatus="PENDING";
    /** Effective rating chosen by moderator. */
    @Builder.Default @Column(name="age_rating", length=16) private String ageRating="ALL_AGES";
    /** Author's suggestion shown to reviewers, not trusted as final rating. */
    @Builder.Default @Column(name="suggested_age_rating", length=16) private String suggestedAgeRating="ALL_AGES";
    @JsonIgnore @Column(name="review_notes", columnDefinition="TEXT") private String reviewNotes;
    @JsonIgnore @Column(name="reviewed_by_user_id") private Long reviewedByUserId;
    @Column(name="reviewed_at") private LocalDateTime reviewedAt;

    @Builder.Default @Column(name="created_at") private LocalDateTime createdAt=LocalDateTime.now();
}
