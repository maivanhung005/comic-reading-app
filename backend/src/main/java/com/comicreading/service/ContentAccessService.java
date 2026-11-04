package com.comicreading.service;

import com.comicreading.entity.Chapter;
import com.comicreading.entity.Comic;
import com.comicreading.entity.User;
import com.comicreading.repository.UserRepository;
import com.comicreading.security.AppPrincipal;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;
import lombok.RequiredArgsConstructor;

import java.time.LocalDate;
import java.time.Period;
import java.util.List;
import java.util.Locale;

@Service
@RequiredArgsConstructor
public class ContentAccessService {
    private final UserRepository userRepository;

    /** Comic metadata and cover can be published without chapter review. Chapter content is gated separately. */
    public boolean canRead(Comic comic) {
        AppPrincipal principal = currentPrincipal();
        if (hasReviewerAccess(principal)) return true;
        boolean owner = isOwner(comic, principal);
        boolean approved = "APPROVED".equalsIgnoreCase(valueOr(comic.getModerationStatus(), "PENDING"));
        return approved || owner;
    }

    public void requireReadable(Comic comic) {
        if (!canRead(comic)) throw new AccessDeniedException("Truyện đã bị ẩn hoặc chưa được công khai.");
    }

    public boolean canRead(Chapter chapter) {
        AppPrincipal principal = currentPrincipal();
        if (hasReviewerAccess(principal)) return true;
        Comic comic = chapter.getComic();
        if (isOwner(comic, principal)) return true; // Owners may preview their own chapter drafts.
        if (!"APPROVED".equalsIgnoreCase(valueOr(comic.getModerationStatus(), "PENDING"))) return false;
        if (!"APPROVED".equalsIgnoreCase(valueOr(chapter.getModerationStatus(), "PENDING"))) return false;
        return isOldEnough(principal, chapter.getAgeRating());
    }

    public void requireReadable(Chapter chapter) {
        if (!canRead(chapter)) throw new AccessDeniedException("Chương chưa được duyệt hoặc không phù hợp với độ tuổi tài khoản.");
    }

    public List<Chapter> visibleChapters(List<Chapter> chapters) {
        return chapters.stream().filter(this::canRead).toList();
    }

    /** A proposed age rating applies to the cover until the work's individual chapters are reviewed. */
    public void requireReadableCover(Comic comic) {
        AppPrincipal principal = currentPrincipal();
        if (hasReviewerAccess(principal) || isOwner(comic, principal)) return;
        if (!"APPROVED".equalsIgnoreCase(valueOr(comic.getModerationStatus(), "PENDING"))) throw new AccessDeniedException("Ảnh bìa chưa được công khai.");
        if (!isOldEnough(principal, comic.getSuggestedAgeRating())) throw new AccessDeniedException("Ảnh bìa thuộc giới hạn tuổi do tác giả đề xuất.");
    }

    public List<Comic> visible(List<Comic> comics) {
        return comics.stream().filter(this::canRead).toList();
    }

    public AppPrincipal currentPrincipal() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        return auth != null && auth.getPrincipal() instanceof AppPrincipal p ? p : null;
    }

    private boolean isOwner(Comic comic, AppPrincipal principal) {
        return principal != null && comic.getCreatedByUserId() != null && comic.getCreatedByUserId().equals(principal.userId());
    }
    private boolean hasReviewerAccess(AppPrincipal principal) {
        return principal != null && ("ADMIN".equals(principal.role()) || "MODERATOR".equals(principal.role()));
    }
    private boolean isOldEnough(AppPrincipal principal, String rating) {
        int minimumAge = minimumAge(rating);
        if (minimumAge == 0) return true;
        if (principal == null) return false;
        User user = userRepository.findById(principal.userId()).orElse(null);
        if (user == null || user.getBirthDate() == null) return false;
        int age = Period.between(user.getBirthDate(), LocalDate.now()).getYears();
        return age >= minimumAge;
    }
    private int minimumAge(String ageRating) {
        if (ageRating == null || ageRating.isBlank() || "ALL_AGES".equalsIgnoreCase(ageRating)) return 0;
        return switch (ageRating.toUpperCase(Locale.ROOT)) {
            case "13+" -> 13;
            case "16+" -> 16;
            case "18+" -> 18;
            default -> 18;
        };
    }
    private String valueOr(String value, String fallback) { return value == null || value.isBlank() ? fallback : value; }
}
