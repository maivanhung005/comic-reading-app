package com.comicreading.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity @Table(name="moderation_reports")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ModerationReport {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="comic_id", nullable=false) private Long comicId;
    @Column(name="reporter_user_id", nullable=false) private Long reporterUserId;
    @Column(name="reason_code", nullable=false, length=40) private String reasonCode;
    @Column(columnDefinition="TEXT") private String description;
    @Builder.Default @Column(nullable=false, length=24) private String status="OPEN";
    @Column(name="reviewed_by_user_id") private Long reviewedByUserId;
    @Column(name="review_note", columnDefinition="TEXT") private String reviewNote;
    @Builder.Default @Column(name="created_at", nullable=false) private LocalDateTime createdAt=LocalDateTime.now();
    @Column(name="reviewed_at") private LocalDateTime reviewedAt;
}
