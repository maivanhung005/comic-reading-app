package com.comicreading.config;

import com.comicreading.security.JwtAuthenticationFilter;
import jakarta.servlet.DispatcherType;
import jakarta.servlet.http.HttpServletResponse;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.http.HttpMethod;
import org.springframework.security.config.annotation.method.configuration.EnableMethodSecurity;
import org.springframework.security.config.annotation.web.builders.HttpSecurity;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.security.config.http.SessionCreationPolicy;
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.security.web.SecurityFilterChain;
import org.springframework.security.web.authentication.UsernamePasswordAuthenticationFilter;
import org.springframework.boot.web.servlet.FilterRegistrationBean;
import org.springframework.web.cors.CorsConfiguration;
import java.util.List;
import java.util.Arrays;

@Configuration
@EnableMethodSecurity
public class SecurityConfig {
    @Value("${app.cors.allowed-origins:http://localhost:3000,http://127.0.0.1:3000,http://localhost:8080}")
    private String allowedOrigins;

    @Bean public PasswordEncoder passwordEncoder() { return new BCryptPasswordEncoder(12); }

    // Prevent Spring Boot from registering the JWT filter both as a servlet filter and a security-chain filter.
    @Bean public FilterRegistrationBean<JwtAuthenticationFilter> jwtFilterRegistration(JwtAuthenticationFilter filter) {
        FilterRegistrationBean<JwtAuthenticationFilter> registration = new FilterRegistrationBean<>(filter);
        registration.setEnabled(false);
        return registration;
    }

    @Bean
    public SecurityFilterChain filterChain(HttpSecurity http, JwtAuthenticationFilter jwtFilter) throws Exception {
        http.cors(cors -> cors.configurationSource(req -> {
            CorsConfiguration cfg = new CorsConfiguration();
            cfg.setAllowedOrigins(Arrays.stream(allowedOrigins.split(",")).map(String::trim).filter(origin -> !origin.isBlank()).toList());
            cfg.setAllowedMethods(List.of("GET", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"));
            cfg.setAllowedHeaders(List.of("Authorization", "Content-Type", "Accept"));
            cfg.setExposedHeaders(List.of("Authorization"));
            return cfg;
        })).csrf(csrf -> csrf.disable())
          .sessionManagement(sm -> sm.sessionCreationPolicy(SessionCreationPolicy.STATELESS))
          .exceptionHandling(ex -> ex
              .authenticationEntryPoint((request, response, authException) -> response.sendError(HttpServletResponse.SC_UNAUTHORIZED, "Cần đăng nhập hoặc token không hợp lệ."))
              .accessDeniedHandler((request, response, accessDeniedException) -> response.sendError(HttpServletResponse.SC_FORBIDDEN, "Bạn không có quyền thực hiện thao tác này.")))
          .authorizeHttpRequests(auth -> auth
              .requestMatchers("/api/auth/register", "/api/auth/login", "/api/auth/verify-email").permitAll()
              .requestMatchers("/swagger-ui/**", "/swagger-ui.html", "/v3/api-docs/**").permitAll()
              .requestMatchers(HttpMethod.GET, "/api/comics", "/api/comics/search", "/api/comics/*", "/api/chapters/*", "/api/recommendations").permitAll()
              .requestMatchers(HttpMethod.POST, "/api/tts/speak").permitAll()
              .requestMatchers("/api/admin/**").hasRole("ADMIN")
              .requestMatchers("/api/moderation/**").hasAnyRole("MODERATOR", "ADMIN")
              .requestMatchers("/api/author/**", "/api/upload/**").hasAnyRole("AUTHOR", "ADMIN")
              .requestMatchers("/api/auth/become-author").authenticated()
              .requestMatchers("/api/**").authenticated()
              .requestMatchers("/uploads/**").permitAll()
              .dispatcherTypeMatchers(DispatcherType.ERROR).permitAll()
              .anyRequest().denyAll())
          .addFilterBefore(jwtFilter, UsernamePasswordAuthenticationFilter.class);
        return http.build();
    }
}
