package com.comicreading.service;

import com.comicreading.entity.EmailVerificationCode;
import com.comicreading.entity.User;
import com.comicreading.repository.EmailVerificationCodeRepository;
import com.comicreading.repository.UserRepository;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.mail.MailAuthenticationException;
import org.springframework.mail.SimpleMailMessage;
import org.springframework.mail.javamail.JavaMailSender;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.SecureRandom;
import java.time.LocalDateTime;
import java.util.HexFormat;

@Service
@RequiredArgsConstructor
public class EmailVerificationService {
    private final JavaMailSender mailSender;
    private final EmailVerificationCodeRepository codeRepository;
    private final UserRepository userRepository;

    @Value("${spring.mail.username:}")
    private String mailUsername;

    @Value("${spring.mail.password:}")
    private String mailPassword;

    private final SecureRandom random = new SecureRandom();

    @Transactional
    public void sendCode(String email, String username) {
        if (mailUsername == null || mailUsername.isBlank() || mailPassword == null || mailPassword.isBlank()) {
            throw new IllegalStateException("Chưa cấu hình MAIL_USERNAME và MAIL_PASSWORD. Hãy dùng Gmail App Password theo README.");
        }
        String code = String.format("%06d", random.nextInt(1_000_000));
        codeRepository.deleteByEmail(email);
        codeRepository.save(EmailVerificationCode.builder()
            .email(email)
            .codeHash(hash(code))
            .expiresAt(LocalDateTime.now().plusMinutes(10))
            .createdAt(LocalDateTime.now())
            .build());

        SimpleMailMessage message = new SimpleMailMessage();
        message.setFrom(mailUsername);
        message.setTo(email);
        message.setSubject("Mã xác minh tài khoản Smart Story");
        message.setText("Xin chào " + username + ",\n\nMã xác minh email của bạn là: " + code +
            "\nMã có hiệu lực trong 10 phút.\n\nKhông chia sẻ mã này với người khác. Nếu bạn không yêu cầu tạo tài khoản, hãy bỏ qua email này.");
        try {
            mailSender.send(message);
        } catch (MailAuthenticationException ex) {
            throw new IllegalStateException("Gmail từ chối đăng nhập SMTP. Hãy kiểm tra MAIL_USERNAME và Gmail App Password.", ex);
        } catch (RuntimeException ex) {
            throw new IllegalStateException("Không gửi được email xác minh. Hãy kiểm tra cấu hình SMTP hoặc kết nối mạng.", ex);
        }
    }

    @Transactional
    public void verify(String email, String code) {
        EmailVerificationCode record = codeRepository.findByEmail(email)
            .orElseThrow(() -> new IllegalArgumentException("Không có mã xác minh cho email này. Hãy đăng ký hoặc yêu cầu gửi lại mã."));
        if (record.getExpiresAt().isBefore(LocalDateTime.now())) {
            codeRepository.delete(record);
            throw new IllegalArgumentException("Mã xác minh đã hết hạn. Hãy đăng ký lại hoặc yêu cầu mã mới.");
        }
        if (!MessageDigest.isEqual(record.getCodeHash().getBytes(StandardCharsets.UTF_8), hash(code).getBytes(StandardCharsets.UTF_8))) {
            throw new IllegalArgumentException("Mã xác minh không chính xác.");
        }
        User user = userRepository.findByEmail(email)
            .orElseThrow(() -> new IllegalArgumentException("Không tìm thấy tài khoản."));
        user.setEmailVerified(true);
        userRepository.save(user);
        codeRepository.delete(record);
    }

    private String hash(String code) {
        try {
            MessageDigest digest = MessageDigest.getInstance("SHA-256");
            return HexFormat.of().formatHex(digest.digest(code.getBytes(StandardCharsets.UTF_8)));
        } catch (Exception ex) {
            throw new IllegalStateException("Không thể tạo mã xác minh.", ex);
        }
    }
}
