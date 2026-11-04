package com.comicreading.controller;

import com.comicreading.dto.ApiResponse;
import com.comicreading.entity.Comic;
import com.comicreading.entity.ModerationAudit;
import com.comicreading.entity.ModerationReport;
import com.comicreading.repository.ComicRepository;
import com.comicreading.repository.ChapterRepository;
import com.comicreading.repository.PageRepository;
import com.comicreading.entity.Chapter;
import com.comicreading.entity.Page;
import com.comicreading.repository.ModerationAuditRepository;
import com.comicreading.repository.ModerationReportRepository;
import com.comicreading.security.CurrentUserService;
import lombok.RequiredArgsConstructor;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Locale;
import java.util.Map;

@RestController @RequestMapping("/api") @RequiredArgsConstructor
public class ModerationController {
    private final ComicRepository comicRepository;
    private final ChapterRepository chapterRepository;
    private final PageRepository pageRepository;
    private final ModerationReportRepository reportRepository;
    private final ModerationAuditRepository auditRepository;
    private final CurrentUserService currentUserService;

    @PostMapping("/comics/{comicId}/reports") @Transactional
    public ApiResponse<ModerationReport> reportComic(@PathVariable Long comicId, @RequestBody Map<String,String> body) {
        if (!comicRepository.existsById(comicId)) throw new IllegalArgumentException("Không tìm thấy truyện.");
        String reason = body.getOrDefault("reasonCode", "OTHER").trim().toUpperCase(Locale.ROOT);
        if (!List.of("AGE_RESTRICTION", "COPYRIGHT", "INAPPROPRIATE", "OTHER").contains(reason)) throw new IllegalArgumentException("Lý do báo cáo không hợp lệ.");
        String description = body.getOrDefault("description", "").trim();
        if (description.length() > 3000) throw new IllegalArgumentException("Mô tả báo cáo không được vượt quá 3000 ký tự.");
        Long reporterId = currentUserService.userId();
        if (reportRepository.existsByComicIdAndReporterUserIdAndStatusIn(comicId, reporterId, List.of("OPEN", "INVESTIGATING"))) {
            throw new IllegalArgumentException("Bạn đã có một báo cáo đang được xử lý cho truyện này.");
        }
        ModerationReport report = reportRepository.save(ModerationReport.builder().comicId(comicId).reporterUserId(reporterId).reasonCode(reason).description(description).status("OPEN").build());
        return new ApiResponse<>(true, "Đã gửi báo cáo. Đội ngũ kiểm duyệt sẽ xem xét.", report);
    }

    /** Protected preview endpoint: reviewers can inspect pending/reported content before deciding. */
    @GetMapping("/moderation/comics/{comicId}/preview") @Transactional(readOnly = true)
    public ApiResponse<Map<String,Object>> previewComic(@PathVariable Long comicId) {
        Comic comic = comicRepository.findById(comicId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy truyện."));
        List<Map<String,Object>> chapterRows = chapterRepository.findByComicIdOrderByChapterNumberAsc(comicId).stream().map(chapter -> {
            List<Map<String,Object>> pageRows = pageRepository.findByChapterIdOrderByPageNumberAsc(chapter.getId()).stream().map(page ->
                Map.<String,Object>of("id", page.getId(), "pageNumber", page.getPageNumber() == null ? 0 : page.getPageNumber(), "imageUrl", safe(page.getImageUrl()))
            ).toList();
            return Map.<String,Object>of(
                "id", chapter.getId(), "chapterNumber", chapter.getChapterNumber() == null ? 0 : chapter.getChapterNumber(),
                "title", safe(chapter.getTitle()), "contentType", safe(chapter.getContentType()),
                "contentText", safe(chapter.getContentText()), "moderationStatus", normalize(chapter.getModerationStatus()),
                "ageRating", safe(chapter.getAgeRating()), "suggestedAgeRating", safe(chapter.getSuggestedAgeRating()),
                "pages", pageRows
            );
        }).toList();
        Map<String,Object> comicInfo = Map.of(
            "id", comic.getId(), "title", safe(comic.getTitle()), "author", safe(comic.getAuthor()),
            "description", safe(comic.getDescription()), "coverUrl", safe(comic.getCoverUrl()),
            "moderationStatus", normalize(comic.getModerationStatus()), "ageRating", safe(comic.getAgeRating()),
            "tags", comic.getTags() == null ? List.of() : comic.getTags()
        );
        return new ApiResponse<>(true, "Bản xem trước chỉ dành cho Moderator/Admin", Map.of("comic", comicInfo, "chapters", chapterRows));
    }

    @GetMapping("/moderation/queue")
    public ApiResponse<Map<String,Object>> queue() {
        List<ModerationReport> reports = reportRepository.findByStatusInOrderByCreatedAtAsc(List.of("OPEN", "INVESTIGATING"));
        java.util.Set<Long> reportedComicIds = reports.stream().map(ModerationReport::getComicId).collect(java.util.stream.Collectors.toSet());
        List<Map<String,Object>> comics = comicRepository.findAll().stream()
            .filter(c -> List.of("PENDING", "HIDDEN", "REJECTED").contains(normalize(c.getModerationStatus())) || reportedComicIds.contains(c.getId()))
            .map(c -> Map.<String,Object>of("id", c.getId(), "title", c.getTitle(), "author", safe(c.getAuthor()),
                "createdByUserId", c.getCreatedByUserId() == null ? 0L : c.getCreatedByUserId(),
                "status", normalize(c.getModerationStatus()), "ageRating", safe(c.getAgeRating()), "reviewNotes", safe(c.getReviewNotes()),
                "createdAt", c.getCreatedAt() == null ? "" : c.getCreatedAt().toString())).toList();
        List<Map<String,Object>> chapterSummaries = chapterRepository.findByModerationStatusInOrderByCreatedAtAsc(List.of("PENDING", "HIDDEN", "REJECTED")).stream()
            .filter(chapter -> !safe(chapter.getContentText()).isBlank() || !pageRepository.findByChapterIdOrderByPageNumberAsc(chapter.getId()).isEmpty())
            .map(chapter -> {
                Comic parent = chapter.getComic();
                int pageCount = pageRepository.findByChapterIdOrderByPageNumberAsc(chapter.getId()).size();
                return objectMap(
                    "id", chapter.getId(), "chapterNumber", chapter.getChapterNumber() == null ? 0 : chapter.getChapterNumber(),
                    "title", safe(chapter.getTitle()), "comicId", parent.getId(), "comicTitle", safe(parent.getTitle()),
                    "author", safe(parent.getAuthor()), "contentType", safe(chapter.getContentType()), "pageCount", pageCount,
                    "textLength", safe(chapter.getContentText()).length(),
                    "status", normalize(chapter.getModerationStatus()), "ageRating", safe(chapter.getAgeRating()),
                    "suggestedAgeRating", safe(chapter.getSuggestedAgeRating()), "reviewNotes", safe(chapter.getReviewNotes()),
                    "createdAt", chapter.getCreatedAt() == null ? "" : chapter.getCreatedAt().toString()
                );
            }).toList();
        List<Map<String,Object>> reportSummaries = reports.stream().map(r -> {
            Comic target = comicRepository.findById(r.getComicId()).orElse(null);
            return Map.<String,Object>of("id", r.getId(), "comicId", r.getComicId(), "comicTitle", target == null ? "Truyện đã bị xoá" : target.getTitle(),
                "reporterUserId", r.getReporterUserId(), "reasonCode", r.getReasonCode(), "description", safe(r.getDescription()), "status", r.getStatus(),
                "createdAt", r.getCreatedAt() == null ? "" : r.getCreatedAt().toString());
        }).toList();
        return new ApiResponse<>(true, "Hàng chờ kiểm duyệt", Map.of("chapters", chapterSummaries, "comics", comics, "reports", reportSummaries));
    }

    /** Reviewer preview returns the complete chapter text and all page image URLs before a decision. */
    @GetMapping("/moderation/chapters/{chapterId}/preview") @Transactional(readOnly = true)
    public ApiResponse<Map<String,Object>> previewChapter(@PathVariable Long chapterId) {
        Chapter chapter = chapterRepository.findById(chapterId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy chương."));
        Comic comic = chapter.getComic();
        List<Map<String,Object>> pageRows = pageRepository.findByChapterIdOrderByPageNumberAsc(chapterId).stream().map(page ->
            Map.<String,Object>of("id", page.getId(), "pageNumber", page.getPageNumber() == null ? 0 : page.getPageNumber(), "imageUrl", safe(page.getImageUrl()))
        ).toList();
        Map<String,Object> comicInfo = Map.of(
            "id", comic.getId(), "title", safe(comic.getTitle()), "author", safe(comic.getAuthor()),
            "description", safe(comic.getDescription()), "coverUrl", safe(comic.getCoverUrl()),
            "suggestedAgeRating", safe(comic.getSuggestedAgeRating()), "ageRating", safe(comic.getAgeRating())
        );
        Map<String,Object> chapterInfo = objectMap(
            "id", chapter.getId(), "comicId", comic.getId(), "chapterNumber", chapter.getChapterNumber() == null ? 0 : chapter.getChapterNumber(),
            "title", safe(chapter.getTitle()), "contentType", safe(chapter.getContentType()), "contentText", safe(chapter.getContentText()),
            "moderationStatus", normalize(chapter.getModerationStatus()), "ageRating", safe(chapter.getAgeRating()),
            "suggestedAgeRating", safe(chapter.getSuggestedAgeRating()), "reviewNotes", safe(chapter.getReviewNotes()), "pages", pageRows
        );
        return new ApiResponse<>(true, "Xem trước toàn bộ nội dung chương", Map.of("comic", comicInfo, "chapter", chapterInfo));
    }

    @PostMapping("/moderation/chapters/{chapterId}/decision") @Transactional
    public ApiResponse<Map<String,Object>> decideChapter(@PathVariable Long chapterId, @RequestBody Map<String,String> body) {
        Chapter chapter = chapterRepository.findById(chapterId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy chương."));
        Comic comic = chapter.getComic();
        String action = body.getOrDefault("action", "").trim().toUpperCase(Locale.ROOT);
        String rating = body.getOrDefault("ageRating", "ALL_AGES").trim().toUpperCase(Locale.ROOT);
        String reason = body.getOrDefault("reason", "").trim();
        if (!List.of("ALL_AGES", "13+", "16+", "18+").contains(rating)) throw new IllegalArgumentException("ageRating hợp lệ: ALL_AGES, 13+, 16+, 18+.");
        if (reason.length() > 3000) throw new IllegalArgumentException("Lý do kiểm duyệt không được vượt quá 3000 ký tự.");
        if (("AGE_RESTRICT".equals(action) || "HIDE".equals(action) || "REJECT".equals(action)) && reason.isBlank()) throw new IllegalArgumentException("Cần ghi lý do/căn cứ khi giới hạn tuổi, ẩn hoặc từ chối chương.");
        switch (action) {
            case "APPROVE" -> { chapter.setModerationStatus("APPROVED"); chapter.setAgeRating(rating); }
            case "AGE_RESTRICT" -> {
                if (!List.of("13+", "16+", "18+").contains(rating)) throw new IllegalArgumentException("Khi giới hạn độ tuổi, chọn 13+, 16+ hoặc 18+.");
                chapter.setModerationStatus("APPROVED"); chapter.setAgeRating(rating);
            }
            case "HIDE" -> chapter.setModerationStatus("HIDDEN");
            case "REJECT" -> chapter.setModerationStatus("REJECTED");
            default -> throw new IllegalArgumentException("action hợp lệ: APPROVE, AGE_RESTRICT, HIDE, REJECT.");
        }
        chapter.setReviewNotes(reason.isBlank() ? null : reason);
        chapter.setReviewedByUserId(currentUserService.userId());
        chapter.setReviewedAt(LocalDateTime.now());
        chapterRepository.save(chapter);
        recalculateComicRating(comic);
        comicRepository.save(comic);
        auditRepository.save(ModerationAudit.builder().actorUserId(currentUserService.userId()).targetType("CHAPTER").targetId(chapterId).action(action).reason(reason).build());
        return new ApiResponse<>(true, "Đã lưu quyết định cho chương.", Map.of("chapterId", chapterId, "moderationStatus", chapter.getModerationStatus(), "ageRating", chapter.getAgeRating(), "comicAgeRating", comic.getAgeRating()));
    }

    private void recalculateComicRating(Comic comic) {
        List<Chapter> approved = chapterRepository.findByComicIdOrderByChapterNumberAsc(comic.getId()).stream()
            .filter(ch -> "APPROVED".equalsIgnoreCase(ch.getModerationStatus())).toList();
        if (approved.isEmpty()) { comic.setAgeRating("ALL_AGES"); return; }
        String mostRestrictive = approved.stream().map(Chapter::getAgeRating).max(java.util.Comparator.comparingInt(this::ratingRank)).orElse("ALL_AGES");
        comic.setAgeRating(mostRestrictive);
    }
    private int ratingRank(String rating) {
        if (rating == null) return 0;
        return switch (rating.toUpperCase(Locale.ROOT)) { case "13+" -> 13; case "16+" -> 16; case "18+" -> 18; default -> 0; };
    }

    @PostMapping("/moderation/comics/{comicId}/decision") @Transactional
    public ApiResponse<Map<String,Object>> decideComic(@PathVariable Long comicId, @RequestBody Map<String,String> body) {
        Comic comic = comicRepository.findById(comicId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy truyện."));
        String action = body.getOrDefault("action", "").trim().toUpperCase(Locale.ROOT);
        String rating = body.getOrDefault("ageRating", "ALL_AGES").trim().toUpperCase(Locale.ROOT);
        String reason = body.getOrDefault("reason", "").trim();
        if (reason.length() > 3000) throw new IllegalArgumentException("Lý do kiểm duyệt không được vượt quá 3000 ký tự.");
        if (!List.of("ALL_AGES", "13+", "16+", "18+").contains(rating)) throw new IllegalArgumentException("ageRating hợp lệ: ALL_AGES, 13+, 16+, 18+.");
        if (!"APPROVE".equals(action) && reason.isBlank()) throw new IllegalArgumentException("Cần ghi lý do khi giới hạn tuổi, ẩn hoặc từ chối truyện.");
        switch (action) {
            case "APPROVE" -> { comic.setModerationStatus("APPROVED"); comic.setAgeRating(rating); }
            case "AGE_RESTRICT" -> {
                if (!List.of("13+", "16+", "18+").contains(rating)) throw new IllegalArgumentException("Khi giới hạn độ tuổi, ageRating phải là 13+, 16+ hoặc 18+.");
                comic.setModerationStatus("APPROVED"); comic.setAgeRating(rating);
            }
            case "HIDE" -> comic.setModerationStatus("HIDDEN");
            case "REJECT" -> comic.setModerationStatus("REJECTED");
            default -> throw new IllegalArgumentException("action hợp lệ: APPROVE, AGE_RESTRICT, HIDE, REJECT.");
        }
        comic.setReviewNotes(reason); comic.setReviewedByUserId(currentUserService.userId()); comic.setReviewedAt(LocalDateTime.now()); comicRepository.save(comic);
        auditRepository.save(ModerationAudit.builder().actorUserId(currentUserService.userId()).targetType("COMIC").targetId(comicId).action(action).reason(reason).build());
        return new ApiResponse<>(true, "Đã lưu quyết định kiểm duyệt.", Map.of("comicId", comicId, "moderationStatus", comic.getModerationStatus(), "ageRating", comic.getAgeRating()));
    }

    @PostMapping("/moderation/reports/{reportId}/decision") @Transactional
    public ApiResponse<ModerationReport> decideReport(@PathVariable Long reportId, @RequestBody Map<String,String> body) {
        ModerationReport report = reportRepository.findById(reportId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy báo cáo."));
        String action = body.getOrDefault("action", "").trim().toUpperCase(Locale.ROOT);
        String note = body.getOrDefault("note", "").trim();
        if (note.length() > 3000) throw new IllegalArgumentException("Ghi chú không được vượt quá 3000 ký tự.");
        switch (action) {
            case "INVESTIGATING" -> report.setStatus("INVESTIGATING");
            case "RESOLVE" -> report.setStatus("RESOLVED");
            case "DISMISS" -> report.setStatus("DISMISSED");
            default -> throw new IllegalArgumentException("action hợp lệ: INVESTIGATING, RESOLVE, DISMISS.");
        }
        report.setReviewedByUserId(currentUserService.userId()); report.setReviewedAt(LocalDateTime.now()); report.setReviewNote(note);
        reportRepository.save(report);
        auditRepository.save(ModerationAudit.builder().actorUserId(currentUserService.userId()).targetType("REPORT").targetId(reportId).action(action).reason(note).build());
        return new ApiResponse<>(true, "Đã cập nhật trạng thái báo cáo.", report);
    }

    private Map<String,Object> objectMap(Object... pairs) {
        if (pairs.length % 2 != 0) throw new IllegalArgumentException("Map entries must be key/value pairs.");
        Map<String,Object> result = new java.util.LinkedHashMap<>();
        for (int i = 0; i < pairs.length; i += 2) result.put(String.valueOf(pairs[i]), pairs[i + 1]);
        return result;
    }

    private String normalize(String v) { return v == null || v.isBlank() ? "PENDING" : v.toUpperCase(Locale.ROOT); }
    private String safe(String v) { return v == null ? "" : v; }
}
