package com.comicreading.controller;

import com.comicreading.dto.ApiResponse;
import com.comicreading.entity.Favorite;
import com.comicreading.entity.Payment;
import com.comicreading.entity.ReadingHistory;
import com.comicreading.repository.FavoriteRepository;
import com.comicreading.security.CurrentUserService;
import com.comicreading.repository.PaymentRepository;
import com.comicreading.repository.ReadingHistoryRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class LibraryController {
    private final FavoriteRepository favoriteRepository;
    private final ReadingHistoryRepository historyRepository;
    private final PaymentRepository paymentRepository;
    private final CurrentUserService currentUserService;

    @GetMapping("/users/{userId}/history")
    public ApiResponse<List<ReadingHistory>> history(@PathVariable Long userId) {
        currentUserService.requireSelfOrAdmin(userId);
        return new ApiResponse<>(true, "Lịch sử đọc", historyRepository.findByUserIdOrderByReadAtDesc(userId));
    }

    @PostMapping("/history")
    public ApiResponse<ReadingHistory> addHistory(@RequestBody Map<String, Object> body) {
        Long userId = requiredLong(body, "userId");
        currentUserService.requireSelfOrAdmin(userId);
        Long comicId = requiredLong(body, "comicId");
        Long chapterId = requiredLong(body, "chapterId");
        Integer chapterNumber = optionalInt(body.get("chapterNumber"));
        Integer pageNumber = optionalInt(body.get("pageNumber"));
        ReadingHistory row = historyRepository.findFirstByUserIdAndComicIdAndChapterIdOrderByReadAtDesc(userId, comicId, chapterId)
                .orElseGet(() -> ReadingHistory.builder().userId(userId).comicId(comicId).chapterId(chapterId).build());
        row.setChapterNumber(chapterNumber);
        row.setPageNumber(pageNumber);
        row.setReadAt(java.time.LocalDateTime.now());
        return new ApiResponse<>(true, "Đã đồng bộ vị trí đọc", historyRepository.save(row));
    }

    @GetMapping("/users/{userId}/favorites")
    public ApiResponse<List<Favorite>> favorites(@PathVariable Long userId) {
        currentUserService.requireSelfOrAdmin(userId);
        return new ApiResponse<>(true, "Truyện yêu thích", favoriteRepository.findByUserId(userId));
    }

    @PostMapping("/favorites")
    public ApiResponse<Favorite> addFavorite(@RequestBody Map<String, Object> body) {
        Long userId = requiredLong(body, "userId");
        currentUserService.requireSelfOrAdmin(userId);
        Long comicId = requiredLong(body, "comicId");
        Favorite row = favoriteRepository.findByUserIdAndComicId(userId, comicId)
                .orElseGet(() -> favoriteRepository.save(Favorite.builder().userId(userId).comicId(comicId).build()));
        return new ApiResponse<>(true, "Đã lưu truyện yêu thích", row);
    }

    @DeleteMapping("/favorites")
    public ApiResponse<Map<String, Object>> removeFavorite(@RequestParam Long userId, @RequestParam Long comicId) {
        currentUserService.requireSelfOrAdmin(userId);
        favoriteRepository.findByUserIdAndComicId(userId, comicId).ifPresent(favoriteRepository::delete);
        return new ApiResponse<>(true, "Đã bỏ yêu thích", Map.of("userId", userId, "comicId", comicId));
    }

    @GetMapping("/users/{userId}/unlocked-chapters")
    public ApiResponse<List<Long>> unlockedChapters(@PathVariable Long userId) {
        currentUserService.requireSelfOrAdmin(userId);
        // Legacy successful rows and explicitly labelled development mock unlocks remain visible.
        List<Long> ids = java.util.stream.Stream.concat(
                paymentRepository.findByUserIdAndStatus(userId, "SUCCESS").stream(),
                paymentRepository.findByUserIdAndStatus(userId, "MOCK_SUCCESS").stream())
                .map(Payment::getChapterId).distinct().toList();
        return new ApiResponse<>(true, "Danh sách chương đã mở khóa", ids);
    }

    private Long requiredLong(Map<String, Object> body, String key) {
        Object value = body.get(key);
        if (value == null) throw new IllegalArgumentException("Thiếu trường bắt buộc: " + key);
        return Long.parseLong(value.toString());
    }

    private Integer optionalInt(Object value) {
        if (value == null || value.toString().isBlank()) return null;
        return Integer.parseInt(value.toString());
    }
}
