package com.comicreading.controller;

import com.comicreading.dto.ApiResponse;
import com.comicreading.entity.AuthorProfile;
import com.comicreading.entity.User;
import com.comicreading.repository.AuthorProfileRepository;
import com.comicreading.repository.UserRepository;
import com.comicreading.security.CurrentUserService;
import com.comicreading.security.JwtTokenProvider;
import com.comicreading.service.EmailVerificationService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;
import java.util.Map;
import java.util.Locale;

@RestController
@RequestMapping("/api/auth")
@RequiredArgsConstructor
public class AuthController {
    private final UserRepository userRepository;
    private final PasswordEncoder passwordEncoder;
    private final JwtTokenProvider jwtTokenProvider;
    private final EmailVerificationService emailVerificationService;
    private final AuthorProfileRepository authorProfileRepository;
    private final CurrentUserService currentUserService;

    @PostMapping("/register")
    @Transactional
    public ApiResponse<Map<String, Object>> register(@RequestBody Map<String, String> body) {
        String email = require(body.get("email"), "Email không được để trống").trim().toLowerCase(Locale.ROOT);
        String username = require(body.get("username"), "Tên đăng nhập không được để trống").trim();
        String name = require(body.get("name"), "Tên hiển thị không được để trống").trim();
        String password = require(body.get("password"), "Mật khẩu không được để trống");
        String gender = require(body.get("gender"), "Danh xưng là bắt buộc").trim();
        if (email.length() > 254) throw new IllegalArgumentException("Email không được vượt quá 254 ký tự.");
        if (username.length() > 24) throw new IllegalArgumentException("Tên đăng nhập không được vượt quá 24 ký tự.");
        if (name.length() > 120) throw new IllegalArgumentException("Tên hiển thị không được vượt quá 120 ký tự.");
        if (gender.length() > 30) throw new IllegalArgumentException("Danh xưng không được vượt quá 30 ký tự.");
        String birthDateText = require(body.get("birthDate"), "Ngày sinh là bắt buộc");
        if (!email.matches("^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$")) throw new IllegalArgumentException("Email không hợp lệ.");
        if (!username.matches("[A-Za-z0-9_.]{3,24}")) throw new IllegalArgumentException("Tên đăng nhập phải dài 3–24 ký tự và chỉ gồm chữ, số, dấu chấm hoặc gạch dưới.");
        if (password.length() < 12) throw new IllegalArgumentException("Mật khẩu phải có ít nhất 12 ký tự.");
        if (password.getBytes(java.nio.charset.StandardCharsets.UTF_8).length > 72) throw new IllegalArgumentException("Mật khẩu tối đa 72 byte UTF-8 để phù hợp với BCrypt.");
        LocalDate birthDate;
        try { birthDate = LocalDate.parse(birthDateText); }
        catch (Exception ex) { throw new IllegalArgumentException("Ngày sinh phải có định dạng YYYY-MM-DD."); }
        if (birthDate.isAfter(LocalDate.now())) throw new IllegalArgumentException("Ngày sinh không thể ở tương lai.");
        if (userRepository.existsByEmail(email)) throw new IllegalArgumentException("Email đã tồn tại trong hệ thống.");
        if (userRepository.existsByUsernameIgnoreCase(username)) throw new IllegalArgumentException("Tên đăng nhập đã được sử dụng.");

        // Role is fixed on the server; any role field sent by a client is ignored.
        User user = userRepository.save(User.builder()
            .email(email).username(username).passwordHash(passwordEncoder.encode(password))
            .name(name).birthDate(birthDate).gender(gender)
            .avatar("https://i.pravatar.cc/150?img=12").role("READER").emailVerified(false).build());
        emailVerificationService.sendCode(user.getEmail(), user.getUsername());
        return new ApiResponse<>(true, "Đã gửi mã xác minh đến email của bạn. Vai trò mặc định là READER.", Map.of("email", email, "role", "READER"));
    }

    @PostMapping("/verify-email")
    public ApiResponse<Map<String, String>> verifyEmail(@RequestBody Map<String, String> body) {
        String email = require(body.get("email"), "Email không được để trống").trim().toLowerCase(Locale.ROOT);
        String code = require(body.get("code"), "Mã xác minh không được để trống").trim();
        if (!code.matches("\\d{6}")) throw new IllegalArgumentException("Mã xác minh phải gồm 6 chữ số.");
        emailVerificationService.verify(email, code);
        return new ApiResponse<>(true, "Xác minh email thành công. Hãy đăng nhập.", Map.of("email", email));
    }

    /** Refreshes the local UI role/profile from PostgreSQL after a saved session is restored. */
    @GetMapping("/me")
    public ApiResponse<Map<String, Object>> me() {
        User user = currentUserService.user();
        return new ApiResponse<>(true, "Thông tin tài khoản hiện tại", Map.of(
            "user", publicUser(user),
            "token", jwtTokenProvider.generateToken(user.getId(), user.getEmail(), user.getRole())
        ));
    }

    @PostMapping("/login")
    public ApiResponse<Map<String, Object>> login(@RequestBody Map<String, String> body) {
        // `identifier` supports username and email. Keep `email` as a backward-compatible alias
        // so older frontends can still log in while they are being updated.
        String identifier = require(
            body.getOrDefault("identifier", body.get("email")),
            "Tên đăng nhập hoặc email không được để trống"
        ).trim();
        String password = require(body.get("password"), "Mật khẩu không được để trống");
        if (password.getBytes(java.nio.charset.StandardCharsets.UTF_8).length > 72) {
            throw new IllegalArgumentException("Mật khẩu tối đa 72 byte UTF-8.");
        }
        User user = userRepository.findByEmailIgnoreCase(identifier)
            .or(() -> userRepository.findByUsernameIgnoreCase(identifier))
            .orElseThrow(() -> new IllegalArgumentException("Sai tên đăng nhập/email hoặc mật khẩu."));
        if (!Boolean.TRUE.equals(user.getEmailVerified())) {
            throw new IllegalArgumentException("Bạn cần xác minh email trước khi đăng nhập.");
        }
        if (!passwordEncoder.matches(password, user.getPasswordHash())) {
            throw new IllegalArgumentException("Sai tên đăng nhập/email hoặc mật khẩu.");
        }
        return new ApiResponse<>(true, "Đăng nhập thành công", Map.of(
            "user", publicUser(user),
            "token", jwtTokenProvider.generateToken(user.getId(), user.getEmail(), user.getRole())
        ));
    }

    /** Explicit opt-in form turns a reader into an author. There is no client-controlled role field. */
    @PostMapping("/become-author")
    @Transactional
    public ApiResponse<Map<String, Object>> becomeAuthor(@RequestBody Map<String, Object> body) {
        User user = currentUserService.user();
        String penName = String.valueOf(body.getOrDefault("penName", "")).trim();
        Object rawExperience = body.get("experience");
        String experience = rawExperience == null ? "" : rawExperience.toString().trim();
        if (experience.length() > 2000) throw new IllegalArgumentException("Phần giới thiệu không được vượt quá 2000 ký tự.");
        boolean termsAccepted = Boolean.parseBoolean(String.valueOf(body.getOrDefault("termsAccepted", false)));
        if (penName.isBlank() || penName.length() > 120) throw new IllegalArgumentException("Bút danh bắt buộc và không vượt quá 120 ký tự.");
        if (!termsAccepted) throw new IllegalArgumentException("Bạn cần xác nhận quyền sử dụng tác phẩm và tuân thủ quy định nội dung.");
        if ("ADMIN".equals(user.getRole()) || "MODERATOR".equals(user.getRole())) throw new IllegalArgumentException("Tài khoản quản trị/kiểm duyệt không thể tự chuyển vai trò qua chức năng này.");
        if ("READER".equals(user.getRole()) || "USER".equals(user.getRole())) user.setRole("AUTHOR");
        else if (!"AUTHOR".equals(user.getRole())) throw new IllegalArgumentException("Vai trò tài khoản không hợp lệ.");
        userRepository.save(user);
        AuthorProfile profile = authorProfileRepository.findByUserId(user.getId()).orElseGet(() -> AuthorProfile.builder().userId(user.getId()).build());
        profile.setPenName(penName);
        profile.setExperience(experience);
        profile.setTermsAccepted(true);
        authorProfileRepository.save(profile);
        String token = jwtTokenProvider.generateToken(user.getId(), user.getEmail(), user.getRole());
        return new ApiResponse<>(true, "Đã kích hoạt quyền tác giả. Truyện mới sẽ chờ kiểm duyệt trước khi xuất bản.", Map.of("user", publicUser(user), "token", token));
    }

    private Map<String, Object> publicUser(User user) {
        return Map.of(
            "id", user.getId(), "email", user.getEmail(), "username", user.getUsername() == null ? "" : user.getUsername(),
            "name", user.getName(), "birthDate", user.getBirthDate() == null ? "" : user.getBirthDate().toString(),
            "gender", user.getGender() == null ? "" : user.getGender(), "avatar", user.getAvatar() == null ? "" : user.getAvatar(),
            "role", user.getRole(), "emailVerified", Boolean.TRUE.equals(user.getEmailVerified()));
    }

    private String require(String value, String message) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException(message);
        return value;
    }
}
