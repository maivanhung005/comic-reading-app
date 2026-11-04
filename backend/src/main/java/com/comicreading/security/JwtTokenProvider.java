package com.comicreading.security;

import io.jsonwebtoken.Claims;
import io.jsonwebtoken.Jwts;
import io.jsonwebtoken.SignatureAlgorithm;
import io.jsonwebtoken.security.Keys;
import jakarta.annotation.PostConstruct;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;
import java.nio.charset.StandardCharsets;
import java.security.Key;
import java.util.Date;

@Component
public class JwtTokenProvider {
    @Value("${app.jwt.secret:}") private String jwtSecret;
    @Value("${app.jwt.expiration-ms:604800000}") private long jwtExpirationMs;

    @PostConstruct
    public void validateConfiguration() {
        if (jwtSecret == null || jwtSecret.getBytes(StandardCharsets.UTF_8).length < 32) {
            throw new IllegalStateException("Thiếu JWT_SECRET an toàn: hãy tạo kho cấu hình cục bộ bằng backend/tools/setup_backend_env_windows.ps1.");
        }
        if (jwtExpirationMs < 60_000) throw new IllegalStateException("JWT expiration phải ít nhất 60 giây.");
    }

    private Key getSigningKey() { return Keys.hmacShaKeyFor(jwtSecret.getBytes(StandardCharsets.UTF_8)); }

    public String generateToken(Long userId, String email, String role) {
        Date now = new Date();
        return Jwts.builder().setSubject(email).claim("userId", userId).claim("role", role)
            .setIssuedAt(now).setExpiration(new Date(now.getTime() + jwtExpirationMs))
            .signWith(getSigningKey(), SignatureAlgorithm.HS256).compact();
    }

    public Claims parseClaims(String token) {
        return Jwts.parserBuilder().setSigningKey(getSigningKey()).build().parseClaimsJws(token).getBody();
    }
}
