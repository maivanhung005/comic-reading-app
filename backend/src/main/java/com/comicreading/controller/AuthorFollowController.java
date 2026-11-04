package com.comicreading.controller;

import com.comicreading.dto.ApiResponse;
import com.comicreading.entity.FollowedAuthor;
import com.comicreading.repository.FollowedAuthorRepository;
import com.comicreading.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class AuthorFollowController {
    private final FollowedAuthorRepository followedAuthorRepository;
    private final CurrentUserService currentUserService;

    @GetMapping("/users/{userId}/authors")
    public ApiResponse<List<FollowedAuthor>> followedAuthors(@PathVariable Long userId) {
        currentUserService.requireSelfOrAdmin(userId);
        return new ApiResponse<>(true, "Danh sách tác giả đang theo dõi", followedAuthorRepository.findByUserIdOrderByFollowedAtDesc(userId));
    }

    @PostMapping("/authors/follow")
    @Transactional
    public ApiResponse<FollowedAuthor> followAuthor(@RequestBody Map<String, Object> body) {
        Long userId = requiredLong(body, "userId");
        currentUserService.requireSelfOrAdmin(userId);
        String authorName = requiredAuthorName(body.get("authorName"));
        FollowedAuthor row = followedAuthorRepository.findByUserIdAndAuthorNameIgnoreCase(userId, authorName)
                .orElseGet(() -> followedAuthorRepository.save(FollowedAuthor.builder().userId(userId).authorName(authorName).build()));
        return new ApiResponse<>(true, "Đã theo dõi tác giả", row);
    }

    @DeleteMapping("/authors/follow")
    @Transactional
    public ApiResponse<Map<String, Object>> unfollowAuthor(@RequestParam Long userId, @RequestParam String authorName) {
        currentUserService.requireSelfOrAdmin(userId);
        String cleanName = requiredAuthorName(authorName);
        followedAuthorRepository.findByUserIdAndAuthorNameIgnoreCase(userId, cleanName).ifPresent(followedAuthorRepository::delete);
        return new ApiResponse<>(true, "Đã bỏ theo dõi tác giả", Map.of("userId", userId, "authorName", cleanName));
    }

    private Long requiredLong(Map<String, Object> body, String key) {
        Object value = body.get(key);
        if (value == null) throw new IllegalArgumentException("Thiếu trường bắt buộc: " + key);
        return Long.parseLong(value.toString());
    }

    private String requiredAuthorName(Object value) {
        String name = value == null ? "" : value.toString().trim();
        if (name.isEmpty()) throw new IllegalArgumentException("Tên tác giả không được để trống.");
        if (name.length() > 180) throw new IllegalArgumentException("Tên tác giả không được vượt quá 180 ký tự.");
        return name;
    }
}
