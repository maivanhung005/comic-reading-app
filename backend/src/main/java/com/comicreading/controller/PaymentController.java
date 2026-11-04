package com.comicreading.controller;
import com.comicreading.dto.ApiResponse;
import com.comicreading.entity.Payment;
import com.comicreading.repository.PaymentRepository;
import com.comicreading.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;
import java.util.Map;
@RestController @RequestMapping("/api/payment") @RequiredArgsConstructor
public class PaymentController {
    private final PaymentRepository paymentRepository;
    private final CurrentUserService currentUserService;
    @PostMapping("/create") public ApiResponse<Payment> createPayment(@RequestBody Map<String,Object> body) {
        Long callerId = currentUserService.userId();
        Object requestedUser = body.get("userId");
        if (requestedUser != null && Long.parseLong(requestedUser.toString()) != callerId) throw new org.springframework.security.access.AccessDeniedException("Không thể tạo giao dịch cho tài khoản khác.");
        Long chapterId = Long.parseLong(String.valueOf(body.getOrDefault("chapterId", "0")));
        Integer amount = Integer.parseInt(String.valueOf(body.getOrDefault("amount", "5000")));
        String method = String.valueOf(body.getOrDefault("method", "MOCK"));
        if (chapterId <= 0) throw new IllegalArgumentException("chapterId không hợp lệ.");
        if (amount <= 0) throw new IllegalArgumentException("Số tiền thanh toán phải lớn hơn 0");
        // This is a development mock, not a real payment provider. Never use SUCCESS here in production.
        Payment payment = Payment.builder().userId(callerId).chapterId(chapterId).amount(amount).method(method)
            .status("MOCK_SUCCESS").transactionId(method+"_SPRING_"+System.currentTimeMillis()).build();
        return new ApiResponse<>(true,"Tạo giao dịch mô phỏng thành công (không phải thanh toán thật)",paymentRepository.save(payment));
    }
}
