package com.comicreading.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity @Table(name="moderation_audit")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ModerationAudit {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="actor_user_id", nullable=false) private Long actorUserId;
    @Column(name="target_type", nullable=false, length=32) private String targetType;
    @Column(name="target_id", nullable=false) private Long targetId;
    @Column(nullable=false, length=60) private String action;
    @Column(columnDefinition="TEXT") private String reason;
    @Builder.Default @Column(name="created_at", nullable=false) private LocalDateTime createdAt=LocalDateTime.now();
}
