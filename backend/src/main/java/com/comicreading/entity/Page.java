package com.comicreading.entity;
import com.fasterxml.jackson.annotation.JsonIgnore;
import jakarta.persistence.*;
import lombok.*;
@Entity @Table(name="pages")
@Getter @Setter @NoArgsConstructor @AllArgsConstructor @Builder
public class Page {
    @Id @GeneratedValue(strategy=GenerationType.IDENTITY) private Long id;
    @ManyToOne(fetch=FetchType.LAZY) @JoinColumn(name="chapter_id", nullable=false) @JsonIgnore private Chapter chapter;
    @Column(name="page_number", nullable=false) private Integer pageNumber;
    @Column(name="image_url", nullable=false) private String imageUrl;
}
