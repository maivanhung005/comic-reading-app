package com.comicreading.security;

import com.comicreading.entity.User;
import com.comicreading.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Service;

@Service
@RequiredArgsConstructor
public class CurrentUserService {
    private final UserRepository userRepository;

    public AppPrincipal principal() {
        Authentication auth = SecurityContextHolder.getContext().getAuthentication();
        if (auth == null || !(auth.getPrincipal() instanceof AppPrincipal p)) {
            throw new AccessDeniedException("Bạn cần đăng nhập để thực hiện thao tác này.");
        }
        return p;
    }

    public User user() {
        return userRepository.findById(principal().userId())
            .orElseThrow(() -> new AccessDeniedException("Tài khoản không còn tồn tại."));
    }

    public Long userId() { return principal().userId(); }
    public String role() { return principal().role(); }

    public void requireSelfOrAdmin(Long targetUserId) {
        if (!userId().equals(targetUserId) && !"ADMIN".equals(role())) {
            throw new AccessDeniedException("Bạn không có quyền truy cập dữ liệu của tài khoản khác.");
        }
    }

    public boolean isReviewer() {
        String role = role();
        return "ADMIN".equals(role) || "MODERATOR".equals(role);
    }
}
