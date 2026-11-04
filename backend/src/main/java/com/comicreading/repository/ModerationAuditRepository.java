package com.comicreading.repository;
import com.comicreading.entity.ModerationAudit;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface ModerationAuditRepository extends JpaRepository<ModerationAudit, Long> {
    List<ModerationAudit> findTop200ByOrderByCreatedAtDesc();
}
