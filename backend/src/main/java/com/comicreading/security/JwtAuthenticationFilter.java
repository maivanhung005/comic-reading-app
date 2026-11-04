package com.comicreading.security;

import com.comicreading.entity.User;
import com.comicreading.repository.UserRepository;
import io.jsonwebtoken.Claims;
import jakarta.servlet.FilterChain;
import jakarta.servlet.ServletException;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;
import lombok.RequiredArgsConstructor;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.stereotype.Component;
import org.springframework.web.filter.OncePerRequestFilter;
import java.io.IOException;
import java.util.List;
import java.util.Locale;

/** Verifies JWT and reads the role from PostgreSQL every request so stale tokens cannot retain old privileges. */
@Component
@RequiredArgsConstructor
public class JwtAuthenticationFilter extends OncePerRequestFilter {
    private final JwtTokenProvider tokenProvider;
    private final UserRepository userRepository;

    @Override
    protected void doFilterInternal(HttpServletRequest request, HttpServletResponse response, FilterChain chain)
            throws ServletException, IOException {
        String header = request.getHeader("Authorization");
        if (header != null && header.startsWith("Bearer ") && SecurityContextHolder.getContext().getAuthentication() == null) {
            try {
                Claims claims = tokenProvider.parseClaims(header.substring(7).trim());
                String subject = claims.getSubject();
                // Current tokens use email as subject. During upgrades, an older token may
                // have username as subject; resolve it too, while still reading authority
                // from the current database record on every request.
                User user = userRepository.findByEmailIgnoreCase(subject)
                    .or(() -> userRepository.findByUsernameIgnoreCase(subject))
                    .orElse(null);
                if (user != null && Boolean.TRUE.equals(user.getEmailVerified())) {
                    String role = normalizeRole(user.getRole());
                    AppPrincipal principal = new AppPrincipal(user.getId(), user.getEmail(), role);
                    var authorities = List.of(new SimpleGrantedAuthority("ROLE_" + role));
                    var authentication = new UsernamePasswordAuthenticationToken(principal, null, authorities);
                    authentication.setDetails(request.getRemoteAddr());
                    SecurityContextHolder.getContext().setAuthentication(authentication);
                }
            } catch (RuntimeException ignored) {
                // A malformed/expired token never grants an identity; protected routes will return 401.
                SecurityContextHolder.clearContext();
            }
        }
        chain.doFilter(request, response);
    }

    private String normalizeRole(String role) {
        if (role == null || role.isBlank() || "USER".equalsIgnoreCase(role)) return "READER";
        String normalized = role.trim().toUpperCase(Locale.ROOT);
        return List.of("READER", "AUTHOR", "MODERATOR", "ADMIN").contains(normalized) ? normalized : "READER";
    }
}
