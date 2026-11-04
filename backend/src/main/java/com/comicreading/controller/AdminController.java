package com.comicreading.controller;

import com.comicreading.dto.ApiResponse;
import com.comicreading.entity.ModerationAudit;
import com.comicreading.entity.User;
import com.comicreading.repository.ModerationAuditRepository;
import com.comicreading.repository.UserRepository;
import com.comicreading.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.web.bind.annotation.*;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@RestController @RequestMapping("/api/admin") @RequiredArgsConstructor
public class AdminController {
    private final UserRepository userRepository;
    private final CurrentUserService currentUserService;
    private final ModerationAuditRepository auditRepository;

    @GetMapping("/users")
    public ApiResponse<List<Map<String,Object>>> users() {
        // Keep the bootstrap administrator out of the ordinary role-management list.
        List<Map<String,Object>> result = userRepository.findAllByOrderByCreatedAtDesc().stream()
            .filter(user -> !"ADMIN".equalsIgnoreCase(user.getRole()))
            .map(this::publicUser).toList();
        return new ApiResponse<>(true, "Danh sách tài khoản", result);
    }

    /** Lightweight totals for the Admin dashboard; avoids downloading every user for counters. */
    @GetMapping("/summary")
    public ApiResponse<Map<String,Object>> summary() {
        long admins = userRepository.countByRoleIgnoreCase("ADMIN");
        long totalUsers = Math.max(0L, userRepository.count() - admins);
        long moderators = userRepository.countByRoleIgnoreCase("MODERATOR");
        return new ApiResponse<>(true, "Tổng quan tài khoản", Map.of(
            "totalUsers", totalUsers,
            "moderatorCount", moderators
        ));
    }

    /** Server-side search and pagination for large account lists. The bootstrap ADMIN is never returned. */
    @GetMapping("/users/search")
    public ApiResponse<Map<String,Object>> searchUsers(
            @RequestParam(defaultValue = "") String q,
            @RequestParam(defaultValue = "ALL") String role,
            @RequestParam(defaultValue = "0") int page,
            @RequestParam(defaultValue = "25") int size) {
        if (page < 0) throw new IllegalArgumentException("Số trang không hợp lệ.");
        if (size < 10 || size > 100) throw new IllegalArgumentException("Số tài khoản mỗi trang phải từ 10 đến 100.");

        String normalizedRole = role == null || role.isBlank() ? "ALL" : role.trim().toUpperCase(Locale.ROOT);
        if (!"ALL".equals(normalizedRole) && !List.of("READER", "AUTHOR", "MODERATOR").contains(normalizedRole)) {
            throw new IllegalArgumentException("Bộ lọc vai trò không hợp lệ.");
        }
        String normalizedSearch = q == null ? "" : q.trim();
        if (normalizedSearch != null && normalizedSearch.length() > 120) {
            throw new IllegalArgumentException("Nội dung tìm kiếm không vượt quá 120 ký tự.");
        }

        Page<User> result = userRepository.searchManageableUsers(
            normalizedSearch, normalizedRole,
            PageRequest.of(page, size, Sort.by(Sort.Order.desc("createdAt"), Sort.Order.desc("id")))
        );
        List<Map<String,Object>> items = result.getContent().stream().map(this::publicUser).toList();
        return new ApiResponse<>(true, "Danh sách tài khoản", Map.of(
            "items", items,
            "page", result.getNumber(),
            "size", result.getSize(),
            "totalElements", result.getTotalElements(),
            "totalPages", result.getTotalPages()
        ));
    }

    @PatchMapping("/users/{userId}/role") @Transactional
    public ApiResponse<Map<String,Object>> changeRole(@PathVariable Long userId, @RequestBody Map<String,String> body) {
        Long actorId = currentUserService.userId();
        if (actorId.equals(userId)) throw new IllegalArgumentException("Không cho phép tự thay đổi vai trò của tài khoản quản trị đang đăng nhập.");
        User target = userRepository.findById(userId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy tài khoản."));
        if ("ADMIN".equalsIgnoreCase(target.getRole())) throw new IllegalArgumentException("Không thể sửa vai trò tài khoản Admin bootstrap bằng API thông thường.");
        String role = body.getOrDefault("role", "").trim().toUpperCase(Locale.ROOT);
        if (!List.of("READER", "MODERATOR").contains(role)) throw new IllegalArgumentException("Vai trò hợp lệ qua quản trị: READER hoặc MODERATOR. AUTHOR chỉ được kích hoạt qua luồng đăng ký tác giả; không thể tạo Admin từ API này.");
        String previous = target.getRole(); target.setRole(role); userRepository.save(target);
        auditRepository.save(ModerationAudit.builder().actorUserId(actorId).targetType("USER").targetId(userId).action("ROLE_" + previous + "_TO_" + role).reason("Thay đổi vai trò bởi Admin").build());
        return new ApiResponse<>(true, "Đã cập nhật vai trò người dùng.", publicUser(target));
    }

    @GetMapping("/audit")
    public ApiResponse<List<ModerationAudit>> audit() {
        return new ApiResponse<>(true, "Nhật ký kiểm duyệt và phân quyền gần đây", auditRepository.findTop200ByOrderByCreatedAtDesc());
    }

    private Map<String,Object> publicUser(User user) {
        String role = "USER".equalsIgnoreCase(user.getRole()) ? "READER" : user.getRole();
        return Map.of("id", user.getId(), "email", user.getEmail(), "username", user.getUsername() == null ? "" : user.getUsername(),
            "name", user.getName(), "role", role, "emailVerified", Boolean.TRUE.equals(user.getEmailVerified()),
            "createdAt", user.getCreatedAt() == null ? "" : user.getCreatedAt().toString());
    }
}
