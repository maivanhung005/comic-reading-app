package com.comicreading.controller;

import com.comicreading.ai.RecommendationService;
import com.comicreading.ai.TTSService;
import com.comicreading.dto.ApiResponse;
import com.comicreading.entity.Chapter;
import com.comicreading.entity.Comic;
import com.comicreading.entity.Page;
import com.comicreading.repository.ChapterRepository;
import com.comicreading.repository.ComicRepository;
import com.comicreading.repository.PageRepository;
import com.comicreading.security.CurrentUserService;
import com.comicreading.service.ContentAccessService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.transaction.annotation.Transactional;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@RestController @RequestMapping("/api") @RequiredArgsConstructor
public class ComicController {
    private final ComicRepository comicRepository;
    private final ChapterRepository chapterRepository;
    private final PageRepository pageRepository;
    private final RecommendationService recommendationService;
    private final TTSService ttsService;
    private final ContentAccessService contentAccessService;
    private final CurrentUserService currentUserService;
    @Value("${app.upload.dir:uploads}") private String uploadDir;

    @GetMapping("/comics")
    public ApiResponse<List<Comic>> getAllComics() {
        return new ApiResponse<>(true, "Danh sách truyện tranh", contentAccessService.visible(comicRepository.findAll()));
    }

    @GetMapping("/comics/search")
    public ApiResponse<List<Comic>> searchComics(@RequestParam(defaultValue="") String q) {
        return new ApiResponse<>(true, "Kết quả tìm kiếm", contentAccessService.visible(comicRepository.findByTitleContainingIgnoreCaseOrAuthorContainingIgnoreCase(q, q)));
    }

    @GetMapping("/comics/{id}") @Transactional(readOnly=true)
    public ApiResponse<Map<String,Object>> getComicDetail(@PathVariable Long id) {
        Comic comic = comicRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy truyện"));
        contentAccessService.requireReadable(comic);
        List<Chapter> chapters = contentAccessService.visibleChapters(chapterRepository.findByComicIdOrderByChapterNumberAsc(id));
        Map<String,Object> data = new HashMap<>(); data.put("comic", comic); data.put("chapters", chapters);
        return new ApiResponse<>(true,"Chi tiết truyện",data);
    }

    @GetMapping("/chapters/{id}") @Transactional(readOnly=true)
    public ApiResponse<Map<String,Object>> getChapterPages(@PathVariable Long id) {
        Chapter chapter = chapterRepository.findById(id).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy chương"));
        Comic comic = comicRepository.findById(chapter.getComic().getId()).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy truyện"));
        contentAccessService.requireReadable(chapter);
        List<Page> pages = pageRepository.findByChapterIdOrderByPageNumberAsc(id);
        return new ApiResponse<>(true,"Chi tiết chương",Map.of("chapter",chapter,"pages",pages));
    }

    @GetMapping("/recommendations")
    public ApiResponse<List<Comic>> getRecommendations(@RequestParam(required=false) Long userId) {
        if (userId != null) currentUserService.requireSelfOrAdmin(userId);
        List<Comic> recommendations = recommendationService.recommendForUser(userId);
        return new ApiResponse<>(true,"Gợi ý truyện theo Content-Based Filtering",contentAccessService.visible(recommendations));
    }

    @PostMapping("/tts/speak") public ApiResponse<Map<String,Object>> speakText(@RequestBody Map<String,Object> body) {
        String text = String.valueOf(body.getOrDefault("text",""));
        String lang = String.valueOf(body.getOrDefault("language","vi-VN"));
        double speed = Double.parseDouble(String.valueOf(body.getOrDefault("speed",1.0)));
        return new ApiResponse<>(true,"TTS metadata (âm thanh được phát từ Flutter)",ttsService.synthesizeSpeechMetadata(text,lang,speed));
    }

    // Existing generic upload endpoint is still role-protected by SecurityConfig (AUTHOR / ADMIN).
    @PostMapping("/upload/cover") public ApiResponse<Map<String,String>> uploadCover(@RequestParam("file") MultipartFile file) throws IOException {
        if (file.isEmpty()) throw new IllegalArgumentException("Vui lòng chọn file ảnh");
        String contentType = file.getContentType() == null ? "" : file.getContentType().toLowerCase();
        if (!List.of("image/jpeg", "image/png", "image/webp", "image/gif").contains(contentType)) throw new IllegalArgumentException("Chỉ chấp nhận ảnh JPEG, PNG, WebP hoặc GIF.");
        if (file.getSize() > 10 * 1024 * 1024) throw new IllegalArgumentException("Ảnh không được vượt quá 10 MB.");
        Path dir = Paths.get(uploadDir).toAbsolutePath().normalize(); Files.createDirectories(dir);
        String original = file.getOriginalFilename() == null ? "cover.jpg" : Path.of(file.getOriginalFilename()).getFileName().toString();
        String ext = original.contains(".") ? original.substring(original.lastIndexOf('.')).toLowerCase() : ".jpg";
        if (!List.of(".jpg", ".jpeg", ".png", ".webp", ".gif").contains(ext)) throw new IllegalArgumentException("Định dạng ảnh không được hỗ trợ.");
        String filename = System.currentTimeMillis() + "_" + java.util.UUID.randomUUID().toString().substring(0,8) + ext;
        Files.copy(file.getInputStream(), dir.resolve(filename));
        return new ApiResponse<>(true,"Upload ảnh thành công",Map.of("url","/uploads/"+filename));
    }
}
