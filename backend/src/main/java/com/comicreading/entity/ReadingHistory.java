package com.comicreading.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity @Table(name="reading_history")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class ReadingHistory {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="user_id", nullable=false) private Long userId;
    @Column(name="comic_id", nullable=false) private Long comicId;
    @Column(name="chapter_id", nullable=false) private Long chapterId;
    @Column(name="chapter_number") private Integer chapterNumber;
    @Column(name="page_number") private Integer pageNumber;
    @Builder.Default @Column(name="read_at") private LocalDateTime readAt=LocalDateTime.now();
}
