package com.comicreading.repository;
import com.comicreading.entity.ModerationReport;
import org.springframework.data.jpa.repository.JpaRepository;
import java.util.List;
public interface ModerationReportRepository extends JpaRepository<ModerationReport, Long> {
    List<ModerationReport> findByStatusInOrderByCreatedAtAsc(List<String> statuses);
    List<ModerationReport> findByReporterUserIdOrderByCreatedAtDesc(Long reporterUserId);
    boolean existsByComicIdAndReporterUserIdAndStatusIn(Long comicId, Long reporterUserId, List<String> statuses);
}
