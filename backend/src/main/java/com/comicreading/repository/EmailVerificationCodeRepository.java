package com.comicreading.repository;

import com.comicreading.entity.EmailVerificationCode;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.Optional;

public interface EmailVerificationCodeRepository extends JpaRepository<EmailVerificationCode, Long> {
    Optional<EmailVerificationCode> findByEmail(String email);
    void deleteByEmail(String email);
}
