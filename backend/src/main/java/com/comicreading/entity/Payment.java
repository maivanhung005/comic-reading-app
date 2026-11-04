package com.comicreading.entity;
import jakarta.persistence.*;
import lombok.*;
import java.time.LocalDateTime;
@Entity @Table(name="payments")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Payment {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @Column(name="user_id", nullable=false) private Long userId;
    @Column(name="chapter_id", nullable=false) private Long chapterId;
    @Column(nullable=false) private Integer amount;
    @Column(nullable=false) private String method;
    @Builder.Default private String status="SUCCESS";
    @Column(name="transaction_id", unique=true) private String transactionId;
    @Builder.Default @Column(name="created_at") private LocalDateTime createdAt=LocalDateTime.now();
}
