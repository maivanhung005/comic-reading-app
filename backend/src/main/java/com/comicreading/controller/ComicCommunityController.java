package com.comicreading.controller;

import com.comicreading.dto.ApiResponse;
import com.comicreading.entity.Chapter;
import com.comicreading.entity.Comic;
import com.comicreading.entity.ComicComment;
import com.comicreading.entity.ComicReview;
import com.comicreading.entity.User;
import com.comicreading.repository.ChapterRepository;
import com.comicreading.repository.ComicCommentRepository;
import com.comicreading.repository.ComicRepository;
import com.comicreading.repository.ComicReviewRepository;
import com.comicreading.repository.UserRepository;
import com.comicreading.security.CurrentUserService;
import com.comicreading.service.ContentAccessService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.time.LocalDateTime;
import java.util.*;

/** Authenticated reader comments and ratings, shared with the Author Studio feedback panel. */
@RestController
@RequestMapping("/api/comics/{comicId}")
@RequiredArgsConstructor
public class ComicCommunityController {
    private final ComicRepository comicRepository;
    private final ChapterRepository chapterRepository;
    private final ComicCommentRepository commentRepository;
    private final ComicReviewRepository reviewRepository;
    private final UserRepository userRepository;
    private final CurrentUserService currentUserService;
    private final ContentAccessService contentAccessService;

    @GetMapping("/comments")
    @Transactional(readOnly = true)
    public ApiResponse<List<Map<String, Object>>> comments(@PathVariable Long comicId) {
        Comic comic = readableComic(comicId);
        List<Map<String, Object>> results = commentRepository
            .findTop20ByComicIdAndStatusOrderByCreatedAtDesc(comic.getId(), "VISIBLE")
            .stream().map(this::commentView).toList();
        return new ApiResponse<>(true, "Bình luận gần đây", results);
    }

    @PostMapping("/comments")
    @Transactional
    public ApiResponse<Map<String, Object>> addComment(@PathVariable Long comicId, @RequestBody Map<String, Object> body) {
        Comic comic = readableComic(comicId);
        Long userId = currentUserService.userId();
        String content = stringValue(body.get("content")).trim();
        if (content.isBlank()) throw new IllegalArgumentException("Nội dung bình luận không được để trống.");
        if (content.length() > 2000) throw new IllegalArgumentException("Bình luận không vượt quá 2.000 ký tự.");
        Long chapterId = optionalLong(body.get("chapterId"));
        if (chapterId != null) {
            Chapter chapter = chapterRepository.findById(chapterId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy chương."));
            if (!comicId.equals(chapter.getComic().getId())) throw new IllegalArgumentException("Chương không thuộc truyện này.");
            contentAccessService.requireReadable(chapter);
        }
        ComicComment row = commentRepository.save(ComicComment.builder().comicId(comic.getId()).chapterId(chapterId)
            .userId(userId).content(content).status("VISIBLE").createdAt(LocalDateTime.now()).updatedAt(LocalDateTime.now()).build());
        return new ApiResponse<>(true, "Đã đăng bình luận", commentView(row));
    }

    @GetMapping("/reviews")
    @Transactional(readOnly = true)
    public ApiResponse<Map<String, Object>> reviews(@PathVariable Long comicId) {
        Comic comic = readableComic(comicId);
        List<ComicReview> rows = reviewRepository.findTop20ByComicIdOrderByUpdatedAtDesc(comic.getId());
        Map<String, Object> data = new LinkedHashMap<>();
        data.put("count", reviewRepository.countByComicId(comic.getId()));
        data.put("averageRating", reviewRepository.averageRatingForComic(comic.getId()));
        data.put("myReview", reviewRepository.findByComicIdAndUserId(comic.getId(), currentUserService.userId()).map(this::reviewView).orElse(null));
        data.put("reviews", rows.stream().map(this::reviewView).toList());
        return new ApiResponse<>(true, "Đánh giá truyện", data);
    }

    @PostMapping("/reviews")
    @Transactional
    public ApiResponse<Map<String, Object>> upsertReview(@PathVariable Long comicId, @RequestBody Map<String, Object> body) {
        Comic comic = readableComic(comicId);
        Object rawRating = body.get("rating");
        int rating;
        try { rating = Integer.parseInt(String.valueOf(rawRating)); }
        catch (Exception ex) { throw new IllegalArgumentException("Điểm đánh giá phải từ 1 đến 5 sao."); }
        if (rating < 1 || rating > 5) throw new IllegalArgumentException("Điểm đánh giá phải từ 1 đến 5 sao.");
        String reviewText = stringValue(body.get("reviewText")).trim();
        if (reviewText.length() > 2000) throw new IllegalArgumentException("Đánh giá không vượt quá 2.000 ký tự.");
        Long userId = currentUserService.userId();
        ComicReview row = reviewRepository.findByComicIdAndUserId(comic.getId(), userId)
            .orElseGet(() -> ComicReview.builder().comicId(comic.getId()).userId(userId).createdAt(LocalDateTime.now()).build());
        row.setRating(rating);
        row.setReviewText(reviewText);
        row.setUpdatedAt(LocalDateTime.now());
        row = reviewRepository.save(row);
        return new ApiResponse<>(true, "Đã lưu đánh giá", reviewView(row));
    }

    private Comic readableComic(Long comicId) {
        Comic comic = comicRepository.findById(comicId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy truyện."));
        contentAccessService.requireReadable(comic);
        return comic;
    }

    private Map<String, Object> commentView(ComicComment row) {
        User user = userRepository.findById(row.getUserId()).orElse(null);
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", row.getId()); map.put("comicId", row.getComicId()); map.put("chapterId", row.getChapterId());
        map.put("userId", row.getUserId()); map.put("username", user == null ? "Độc giả" : user.getUsername());
        map.put("displayName", user == null ? "Độc giả" : user.getName()); map.put("content", row.getContent());
        map.put("createdAt", row.getCreatedAt() == null ? "" : row.getCreatedAt().toString());
        return map;
    }

    private Map<String, Object> reviewView(ComicReview row) {
        User user = userRepository.findById(row.getUserId()).orElse(null);
        Map<String, Object> map = new LinkedHashMap<>();
        map.put("id", row.getId()); map.put("comicId", row.getComicId()); map.put("userId", row.getUserId());
        map.put("username", user == null ? "Độc giả" : user.getUsername());
        map.put("displayName", user == null ? "Độc giả" : user.getName());
        map.put("rating", row.getRating()); map.put("reviewText", row.getReviewText() == null ? "" : row.getReviewText());
        map.put("updatedAt", row.getUpdatedAt() == null ? "" : row.getUpdatedAt().toString());
        return map;
    }

    private String stringValue(Object value) { return value == null ? "" : value.toString(); }
    private Long optionalLong(Object value) {
        if (value == null || value.toString().isBlank()) return null;
        try { return Long.parseLong(value.toString()); }
        catch (NumberFormatException ex) { throw new IllegalArgumentException("ID chương không hợp lệ."); }
    }
}
