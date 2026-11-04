package com.comicreading;

import com.comicreading.entity.Chapter;
import com.comicreading.entity.Comic;
import com.comicreading.entity.Page;
import com.comicreading.repository.ChapterRepository;
import com.comicreading.repository.ComicRepository;
import com.comicreading.repository.PageRepository;
import org.modelmapper.ModelMapper;
import org.springframework.boot.CommandLineRunner;
import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.context.annotation.Bean;
import java.util.Arrays;
import java.util.List;

@SpringBootApplication
public class ComicReadingApplication {
    public static void main(String[] args) { SpringApplication.run(ComicReadingApplication.class, args); }

    @Bean public ModelMapper modelMapper() { return new ModelMapper(); }

    @Bean
    public CommandLineRunner seedDatabase(ComicRepository comicRepo, ChapterRepository chapterRepo, PageRepository pageRepo) {
        return args -> {
            if (comicRepo.count() > 0) return;
            Comic c1 = Comic.builder().title("Thám Tử Lừng Danh Conan").author("Gosho Aoyama")
                .description("Shinichi Kudo bị teo nhỏ thành cậu bé Conan và âm thầm phá giải các vụ án bí ẩn.")
                .coverUrl("https://picsum.photos/seed/conan/400/600")
                .tags(Arrays.asList("Trinh thám", "Hành động", "Học đường")).status("Đang tiến hành").moderationStatus("APPROVED").ageRating("ALL_AGES").suggestedAgeRating("ALL_AGES").build();
            Comic c2 = Comic.builder().title("Solo Leveling - Tôi Thăng Cấp Một Mình").author("Chugong")
                .description("Sung Jin-Woo từ thợ săn hạng E yếu nhất thức tỉnh hệ thống trở thành Hoàng Đế Bóng Tối.")
                .coverUrl("https://picsum.photos/seed/solo/400/600")
                .tags(Arrays.asList("Hành động", "Fantasy", "Hệ thống")).status("Hoàn thành").moderationStatus("APPROVED").ageRating("ALL_AGES").suggestedAgeRating("ALL_AGES").build();
            Comic c3 = Comic.builder().title("One Piece - Đảo Hải Tặc").author("Eiichiro Oda")
                .description("Hành trình của Luffy và băng Mũ Rơm chinh phục Đại Hải Trình tìm kiếm kho báu One Piece.")
                .coverUrl("https://picsum.photos/seed/onepiece/400/600")
                .tags(Arrays.asList("Hành động", "Phiêu lưu", "Hài hước")).status("Đang tiến hành").moderationStatus("APPROVED").ageRating("ALL_AGES").suggestedAgeRating("ALL_AGES").build();
            comicRepo.saveAll(List.of(c1, c2, c3));
            Chapter ch1 = chapterRepo.save(Chapter.builder().comic(c1).chapterNumber(1).title("Sherlock Holmes thời hiện đại").isVip(false).price(0).contentType("IMAGE").moderationStatus("APPROVED").ageRating("ALL_AGES").suggestedAgeRating("ALL_AGES").build());
            Chapter ch2 = chapterRepo.save(Chapter.builder().comic(c1).chapterNumber(2).title("Vụ án trên tàu tốc hành (VIP)").isVip(true).price(5000).contentType("IMAGE").moderationStatus("APPROVED").ageRating("ALL_AGES").suggestedAgeRating("ALL_AGES").build());
            Chapter ch3 = chapterRepo.save(Chapter.builder().comic(c2).chapterNumber(1).title("Thợ săn hạng E yếu nhất nhân loại").isVip(false).price(0).contentType("IMAGE").moderationStatus("APPROVED").ageRating("ALL_AGES").suggestedAgeRating("ALL_AGES").build());
            Chapter ch4 = chapterRepo.save(Chapter.builder().comic(c3).chapterNumber(1).title("Bình minh của cuộc phiêu lưu").isVip(false).price(0).contentType("IMAGE").moderationStatus("APPROVED").ageRating("ALL_AGES").suggestedAgeRating("ALL_AGES").build());
            pageRepo.saveAll(List.of(
                Page.builder().chapter(ch1).pageNumber(1).imageUrl("https://picsum.photos/seed/conan-p1/700/1000").build(),
                Page.builder().chapter(ch1).pageNumber(2).imageUrl("https://picsum.photos/seed/conan-p2/700/1000").build(),
                Page.builder().chapter(ch2).pageNumber(1).imageUrl("https://picsum.photos/seed/conan-vip-p1/700/1000").build(),
                Page.builder().chapter(ch3).pageNumber(1).imageUrl("https://picsum.photos/seed/solo-p1/700/1000").build(),
                Page.builder().chapter(ch3).pageNumber(2).imageUrl("https://picsum.photos/seed/solo-p2/700/1000").build(),
                Page.builder().chapter(ch4).pageNumber(1).imageUrl("https://picsum.photos/seed/onepiece-p1/700/1000").build(),
                Page.builder().chapter(ch4).pageNumber(2).imageUrl("https://picsum.photos/seed/onepiece-p2/700/1000").build()
            ));
        };
    }
}
