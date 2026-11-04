package com.comicreading.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity @Table(name="favorites", uniqueConstraints=@UniqueConstraint(columnNames={"user_id","comic_id"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Favorite {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="user_id", nullable=false) private Long userId;
    @Column(name="comic_id", nullable=false) private Long comicId;
    @Builder.Default @Column(name="created_at") private LocalDateTime createdAt=LocalDateTime.now();
}
