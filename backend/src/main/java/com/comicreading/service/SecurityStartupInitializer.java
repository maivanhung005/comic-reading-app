package com.comicreading.service;

import com.comicreading.entity.User;
import com.comicreading.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.core.annotation.Order;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
import com.comicreading.repository.ComicRepository;
import com.comicreading.entity.Comic;

import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;

@Component
@RequiredArgsConstructor
@Order(0)
public class SecurityStartupInitializer implements ApplicationRunner {
    private final UserRepository userRepository;
    private final ComicRepository comicRepository;
    private final com.comicreading.repository.ChapterRepository chapterRepository;
    private final PasswordEncoder passwordEncoder;

    @Value("${app.security.bootstrap-admin.enabled:false}") private boolean bootstrapEnabled;
    @Value("${app.security.bootstrap-admin.email:}") private String adminEmail;
    @Value("${app.security.bootstrap-admin.username:}") private String adminUsername;
    @Value("${app.security.bootstrap-admin.name:}") private String adminName;
    @Value("${app.security.bootstrap-admin.password:}") private String adminPassword;

    @Override
    @Transactional
    public void run(ApplicationArguments args) {
        // Normalize legacy USER rows and ensure no unknown value accidentally grants elevated access.
        for (User user : userRepository.findAll()) {
            String current = user.getRole();
            String normalized = current == null ? "" : current.trim().toUpperCase(Locale.ROOT);
            if (normalized.isBlank() || "USER".equals(normalized)
                    || !List.of("READER", "AUTHOR", "MODERATOR", "ADMIN").contains(normalized)) {
                user.setRole("READER");
                userRepository.save(user);
            } else if (!normalized.equals(current)) {
                user.setRole(normalized);
                userRepository.save(user);
            }
        }
        // Comic metadata/cover no longer needs review. Existing chapter content is separately queued.
        for (Comic comic : comicRepository.findAll()) {
            boolean changed = false;
            String state = comic.getModerationStatus() == null ? "" : comic.getModerationStatus().trim().toUpperCase(Locale.ROOT);
            if (state.isBlank() || "PENDING".equals(state)) {
                comic.setModerationStatus("APPROVED");
                comic.setReviewNotes(null);
                comic.setReviewedByUserId(null);
                comic.setReviewedAt(null);
                changed = true;
            }
            if (comic.getAgeRating() == null || comic.getAgeRating().isBlank()) {
                comic.setAgeRating("ALL_AGES");
                changed = true;
            }
            if (comic.getSuggestedAgeRating() == null || comic.getSuggestedAgeRating().isBlank()) {
                comic.setSuggestedAgeRating(comic.getAgeRating());
                changed = true;
            }
            if (changed) comicRepository.save(comic);
        }
        for (com.comicreading.entity.Chapter chapter : chapterRepository.findAll()) {
            boolean changed = false;
            if (chapter.getModerationStatus() == null || chapter.getModerationStatus().isBlank()) {
                chapter.setModerationStatus("PENDING");
                chapter.setReviewNotes("Chương cũ cần được đọc và gán độ tuổi.");
                chapter.setReviewedByUserId(null);
                chapter.setReviewedAt(null);
                changed = true;
            }
            if (chapter.getContentType() == null || chapter.getContentType().isBlank()) { chapter.setContentType("IMAGE"); changed = true; }
            if (chapter.getSuggestedAgeRating() == null || chapter.getSuggestedAgeRating().isBlank()) {
                chapter.setSuggestedAgeRating(chapter.getComic().getSuggestedAgeRating() == null ? "ALL_AGES" : chapter.getComic().getSuggestedAgeRating());
                changed = true;
            }
            if (chapter.getAgeRating() == null || chapter.getAgeRating().isBlank()) { chapter.setAgeRating(chapter.getSuggestedAgeRating()); changed = true; }
            if (changed) chapterRepository.save(chapter);
        }
        if (!bootstrapEnabled) return;
        if (blank(adminEmail) || blank(adminUsername) || blank(adminName) || adminPassword == null || adminPassword.length() < 16) {
            throw new IllegalStateException("Bootstrap Admin đang bật nhưng chưa cấu hình đủ ADMIN_BOOTSTRAP_EMAIL, USERNAME, NAME và mật khẩu tối thiểu 16 ký tự. Không đặt thông tin này trong source code.");
        }
        String email = adminEmail.trim().toLowerCase(Locale.ROOT);
        User existing = userRepository.findByEmail(email).orElse(null);
        if (existing != null) {
            if (!"ADMIN".equalsIgnoreCase(existing.getRole())) {
                throw new IllegalStateException("Email bootstrap đã tồn tại nhưng không phải ADMIN. Hãy chọn email bootstrap riêng; hệ thống không tự nâng tài khoản có sẵn thành Admin.");
            }
            // Never reset the existing administrator's password from bootstrap values.
            return;
        }
        boolean anAdminAlreadyExists = userRepository.findAll().stream()
            .anyMatch(user -> "ADMIN".equalsIgnoreCase(user.getRole()));
        if (anAdminAlreadyExists) {
            throw new IllegalStateException("Đã có tài khoản ADMIN. Bootstrap không tạo thêm Admin mới; không thể dùng script này để thêm một quản trị viên thứ hai.");
        }
        if (userRepository.existsByUsernameIgnoreCase(adminUsername.trim())) {
            throw new IllegalStateException("Username bootstrap đã tồn tại. Hãy chọn ADMIN_BOOTSTRAP_USERNAME khác.");
        }
        userRepository.save(User.builder()
            .email(email).username(adminUsername.trim()).name(adminName.trim())
            .passwordHash(passwordEncoder.encode(adminPassword))
            .role("ADMIN").emailVerified(true).createdAt(LocalDateTime.now())
            .avatar("").build());
        // Only a BCrypt hash is persisted. The secret itself is never logged or written to a project file.
        System.out.println("Đã khởi tạo tài khoản quản trị bootstrap. Thông tin đăng nhập không được ghi vào log.");
    }

    private boolean blank(String value) { return value == null || value.isBlank(); }
}
