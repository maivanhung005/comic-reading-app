package com.comicreading.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity @Table(name="author_profiles", uniqueConstraints=@UniqueConstraint(columnNames={"user_id"}))
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class AuthorProfile {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="user_id", nullable=false, unique=true) private Long userId;
    @Column(name="pen_name", nullable=false, length=120) private String penName;
    @Column(columnDefinition="TEXT") private String experience;
    @Builder.Default @Column(name="terms_accepted", nullable=false) private Boolean termsAccepted=true;
    @Builder.Default @Column(name="created_at", nullable=false) private LocalDateTime createdAt=LocalDateTime.now();
}
