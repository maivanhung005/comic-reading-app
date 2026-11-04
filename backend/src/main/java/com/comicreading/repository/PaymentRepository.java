package com.comicreading.repository;

import com.comicreading.entity.Payment;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;

public interface PaymentRepository extends JpaRepository<Payment, Long> {
    List<Payment> findByUserIdAndStatus(Long userId, String status);
}
