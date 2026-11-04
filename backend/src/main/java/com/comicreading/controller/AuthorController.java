package com.comicreading.controller;

import com.comicreading.dto.ApiResponse;
import com.comicreading.entity.Chapter;
import com.comicreading.entity.Comic;
import com.comicreading.entity.Page;
import com.comicreading.repository.ChapterRepository;
import com.comicreading.repository.ComicRepository;
import com.comicreading.repository.PageRepository;
import com.comicreading.repository.AuthorProfileRepository;
import com.comicreading.repository.FollowedAuthorRepository;
import com.comicreading.repository.ReadingHistoryRepository;
import com.comicreading.repository.ComicCommentRepository;
import com.comicreading.repository.ComicReviewRepository;
import com.comicreading.repository.UserRepository;
import com.comicreading.entity.AuthorProfile;
import com.comicreading.entity.FollowedAuthor;
import com.comicreading.entity.ComicComment;
import com.comicreading.entity.ComicReview;
import com.comicreading.entity.User;
import com.comicreading.security.CurrentUserService;
import com.comicreading.service.ChapterImportService;
import lombok.RequiredArgsConstructor;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.ImageIO;
import java.io.ByteArrayInputStream;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.LocalDateTime;
import java.util.*;

@RestController @RequestMapping("/api/author") @RequiredArgsConstructor
public class AuthorController {
    private final ComicRepository comicRepository;
    private final ChapterRepository chapterRepository;
    private final PageRepository pageRepository;
    private final AuthorProfileRepository authorProfileRepository;
    private final FollowedAuthorRepository followedAuthorRepository;
    private final ReadingHistoryRepository readingHistoryRepository;
    private final ComicCommentRepository comicCommentRepository;
    private final ComicReviewRepository comicReviewRepository;
    private final UserRepository userRepository;
    private final CurrentUserService currentUserService;
    private final ChapterImportService chapterImportService;
    @Value("${app.upload.dir:uploads}") private String uploadDir;

    @GetMapping("/comics")
    public ApiResponse<List<Comic>> myComics() {
        return new ApiResponse<>(true, "Truyện do tôi quản lý", comicRepository.findByCreatedByUserIdOrderByCreatedAtDesc(currentUserService.userId()));
    }

    /** Server-backed author analytics: only data belonging to the authenticated account is returned. */
    @GetMapping("/dashboard") @Transactional(readOnly=true)
    public ApiResponse<Map<String,Object>> authorDashboard() {
        Long userId = currentUserService.userId();
        List<Comic> comics = comicRepository.findByCreatedByUserIdOrderByCreatedAtDesc(userId);
        List<Long> comicIds = comics.stream().map(Comic::getId).filter(Objects::nonNull).toList();
        Set<String> authorNames = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
        comics.stream().map(Comic::getAuthor).filter(v -> v != null && !v.isBlank()).forEach(authorNames::add);
        AuthorProfile profile = authorProfileRepository.findByUserId(userId).orElse(null);
        if (profile != null && profile.getPenName() != null && !profile.getPenName().isBlank()) authorNames.add(profile.getPenName());
        List<String> normalizedAuthorNames = authorNames.stream().map(v -> v.toLowerCase(Locale.ROOT)).toList();
        long followers = normalizedAuthorNames.isEmpty() ? 0 : followedAuthorRepository.countDistinctFollowersForAuthorNames(normalizedAuthorNames);
        long reads = comicIds.isEmpty() ? 0 : readingHistoryRepository.countByComicIdIn(comicIds);
        long uniqueReaders = comicIds.isEmpty() ? 0 : readingHistoryRepository.countDistinctReadersByComicIds(comicIds);
        long comments = comicIds.isEmpty() ? 0 : comicCommentRepository.countByComicIdInAndStatus(comicIds, "VISIBLE");
        long reviewCount = comicIds.isEmpty() ? 0 : comicReviewRepository.countByComicIdIn(comicIds);
        double averageRating = comicIds.isEmpty() ? 0.0 : comicReviewRepository.averageRatingForComics(comicIds);
        List<Map<String,Object>> recentComments = comicIds.isEmpty() ? List.of() : comicCommentRepository
            .findTop5ByComicIdInAndStatusOrderByCreatedAtDesc(comicIds, "VISIBLE").stream().map(this::authorCommentView).toList();
        List<Map<String,Object>> recentReviews = comicIds.isEmpty() ? List.of() : comicReviewRepository
            .findTop5ByComicIdInOrderByUpdatedAtDesc(comicIds).stream().map(this::authorReviewView).toList();
        Map<String,Object> result = new LinkedHashMap<>();
        result.put("followerCount", followers);
        result.put("comicCount", comics.size());
        result.put("readingProgressCount", reads);
        result.put("uniqueReaderCount", uniqueReaders);
        result.put("commentCount", comments);
        result.put("reviewCount", reviewCount);
        result.put("averageRating", averageRating);
        result.put("recentComments", recentComments);
        result.put("recentReviews", recentReviews);
        result.put("penName", profile == null ? "" : profile.getPenName());

        // Per-comic statistics also provide the newest feedback timestamps used by the
        // Flutter Studio to show unread-feedback indicators without loading every item.
        List<Map<String,Object>> comicStatistics = new ArrayList<>();
        for (Comic comic : comics) {
            Long comicId = comic.getId();
            List<Chapter> chapters = chapterRepository.findByComicIdOrderByChapterNumberAsc(comicId);
            long pendingChapters = chapters.stream().filter(c -> "PENDING".equalsIgnoreCase(c.getModerationStatus())).count();
            Optional<ComicComment> latestComment = comicCommentRepository.findFirstByComicIdAndStatusOrderByCreatedAtDesc(comicId, "VISIBLE");
            Optional<ComicReview> latestReview = comicReviewRepository.findFirstByComicIdOrderByUpdatedAtDesc(comicId);
            LocalDateTime latestCommentAt = latestComment.map(ComicComment::getCreatedAt).orElse(null);
            LocalDateTime latestReviewAt = latestReview.map(ComicReview::getUpdatedAt).orElse(null);
            LocalDateTime latestFeedbackAt = latestCommentAt == null ? latestReviewAt
                : latestReviewAt == null ? latestCommentAt
                : (latestCommentAt.isAfter(latestReviewAt) ? latestCommentAt : latestReviewAt);
            Map<String,Object> stats = new LinkedHashMap<>();
            stats.put("comicId", comicId);
            stats.put("title", comic.getTitle());
            stats.put("readerCount", readingHistoryRepository.countDistinctReadersByComicId(comicId));
            stats.put("readingCount", readingHistoryRepository.countByComicId(comicId));
            stats.put("commentCount", comicCommentRepository.countByComicIdAndStatus(comicId, "VISIBLE"));
            stats.put("reviewCount", comicReviewRepository.countByComicId(comicId));
            stats.put("averageRating", comicReviewRepository.averageRatingForComic(comicId));
            stats.put("chapterCount", chapters.size());
            stats.put("pendingChapterCount", pendingChapters);
            stats.put("latestCommentAt", latestCommentAt == null ? "" : latestCommentAt.toString());
            stats.put("latestReviewAt", latestReviewAt == null ? "" : latestReviewAt.toString());
            stats.put("latestFeedbackAt", latestFeedbackAt == null ? "" : latestFeedbackAt.toString());
            comicStatistics.add(stats);
        }
        result.put("comicStatistics", comicStatistics);
        return new ApiResponse<>(true, "Thống kê Studio tác giả", result);
    }

    @GetMapping("/followers") @Transactional(readOnly=true)
    public ApiResponse<Map<String,Object>> authorFollowers() {
        Long userId = currentUserService.userId();
        List<Comic> comics = comicRepository.findByCreatedByUserIdOrderByCreatedAtDesc(userId);
        Set<String> names = new TreeSet<>(String.CASE_INSENSITIVE_ORDER);
        comics.stream().map(Comic::getAuthor).filter(v -> v != null && !v.isBlank()).forEach(names::add);
        AuthorProfile profile = authorProfileRepository.findByUserId(userId).orElse(null);
        if (profile != null && profile.getPenName() != null && !profile.getPenName().isBlank()) names.add(profile.getPenName());
        List<String> normalized = names.stream().map(v -> v.toLowerCase(Locale.ROOT)).toList();
        Map<String,Object> result = new LinkedHashMap<>();
        if (normalized.isEmpty()) {
            result.put("followerCount", 0);
            result.put("followers", List.of());
            return new ApiResponse<>(true, "Người theo dõi tác giả", result);
        }
        List<FollowedAuthor> rows = followedAuthorRepository.findFollowersForAuthorNames(normalized);
        Map<Long, FollowedAuthor> distinct = new LinkedHashMap<>();
        for (FollowedAuthor row : rows) distinct.putIfAbsent(row.getUserId(), row);
        List<Map<String,Object>> followers = new ArrayList<>();
        for (FollowedAuthor row : distinct.values()) {
            User follower = userRepository.findById(row.getUserId()).orElse(null);
            Map<String,Object> item = new LinkedHashMap<>();
            item.put("userId", row.getUserId());
            item.put("username", follower == null ? "" : Objects.toString(follower.getUsername(), ""));
            item.put("displayName", follower == null ? "Độc giả" : Objects.toString(follower.getName(), "Độc giả"));
            item.put("avatar", follower == null ? "" : Objects.toString(follower.getAvatar(), ""));
            item.put("followedAt", row.getFollowedAt() == null ? "" : row.getFollowedAt().toString());
            followers.add(item);
        }
        result.put("followerCount", followers.size());
        result.put("followers", followers);
        return new ApiResponse<>(true, "Người theo dõi tác giả", result);
    }

    @GetMapping("/comics/{comicId}/feedback") @Transactional(readOnly=true)
    public ApiResponse<Map<String,Object>> authorComicFeedback(@PathVariable Long comicId) {
        Comic comic = ownedComic(comicId);
        List<ComicComment> comments = comicCommentRepository.findTop20ByComicIdAndStatusOrderByCreatedAtDesc(comicId, "VISIBLE");
        List<ComicReview> reviews = comicReviewRepository.findTop20ByComicIdOrderByUpdatedAtDesc(comicId);
        long commentCount = comicCommentRepository.countByComicIdAndStatus(comicId, "VISIBLE");
        long reviewCount = comicReviewRepository.countByComicId(comicId);
        double averageRating = comicReviewRepository.averageRatingForComic(comicId);
        Optional<ComicComment> latestComment = comicCommentRepository.findFirstByComicIdAndStatusOrderByCreatedAtDesc(comicId, "VISIBLE");
        Optional<ComicReview> latestReview = comicReviewRepository.findFirstByComicIdOrderByUpdatedAtDesc(comicId);
        LocalDateTime commentAt = latestComment.map(ComicComment::getCreatedAt).orElse(null);
        LocalDateTime reviewAt = latestReview.map(ComicReview::getUpdatedAt).orElse(null);
        LocalDateTime latestAt = commentAt == null ? reviewAt : reviewAt == null ? commentAt : (commentAt.isAfter(reviewAt) ? commentAt : reviewAt);
        Map<String,Object> data = new LinkedHashMap<>();
        data.put("comicId", comic.getId()); data.put("comicTitle", comic.getTitle());
        data.put("commentCount", commentCount); data.put("reviewCount", reviewCount); data.put("averageRating", averageRating);
        data.put("latestCommentAt", commentAt == null ? "" : commentAt.toString());
        data.put("latestReviewAt", reviewAt == null ? "" : reviewAt.toString());
        data.put("latestFeedbackAt", latestAt == null ? "" : latestAt.toString());
        data.put("comments", comments.stream().map(this::authorCommentView).toList());
        data.put("reviews", reviews.stream().map(this::authorReviewView).toList());
        return new ApiResponse<>(true, "Bình luận và đánh giá của truyện", data);
    }

    private Map<String,Object> authorCommentView(ComicComment comment) {
        Map<String,Object> map = new LinkedHashMap<>();
        User user = userRepository.findById(comment.getUserId()).orElse(null);
        Comic comic = comicRepository.findById(comment.getComicId()).orElse(null);
        map.put("id", comment.getId()); map.put("comicId", comment.getComicId());
        map.put("comicTitle", comic == null ? "Truyện" : comic.getTitle());
        map.put("readerName", user == null ? "Độc giả" : user.getName());
        map.put("content", comment.getContent());
        map.put("createdAt", comment.getCreatedAt() == null ? "" : comment.getCreatedAt().toString());
        return map;
    }

    private Map<String,Object> authorReviewView(ComicReview review) {
        Map<String,Object> map = new LinkedHashMap<>();
        User user = userRepository.findById(review.getUserId()).orElse(null);
        Comic comic = comicRepository.findById(review.getComicId()).orElse(null);
        map.put("id", review.getId()); map.put("comicId", review.getComicId());
        map.put("comicTitle", comic == null ? "Truyện" : comic.getTitle());
        map.put("readerName", user == null ? "Độc giả" : user.getName());
        map.put("rating", review.getRating());
        map.put("reviewText", review.getReviewText() == null ? "" : review.getReviewText());
        map.put("updatedAt", review.getUpdatedAt() == null ? "" : review.getUpdatedAt().toString());
        return map;
    }

    @GetMapping("/comics/{comicId}") @Transactional(readOnly=true)
    public ApiResponse<Map<String,Object>> myComicDetail(@PathVariable Long comicId) {
        Comic comic = ownedComic(comicId);
        List<Chapter> chapters = chapterRepository.findByComicIdOrderByChapterNumberAsc(comicId);
        return new ApiResponse<>(true, "Chi tiết truyện của tác giả", Map.of("comic", comic, "chapters", chapters));
    }

    @GetMapping("/chapters/{chapterId}") @Transactional(readOnly=true)
    public ApiResponse<Map<String,Object>> myChapterDetail(@PathVariable Long chapterId) {
        Chapter chapter = chapterRepository.findById(chapterId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy chương."));
        ownedComic(chapter.getComic().getId());
        List<Page> pages = pageRepository.findByChapterIdOrderByPageNumberAsc(chapterId);
        return new ApiResponse<>(true, "Chi tiết chương của tác giả", Map.of("chapter", chapter, "pages", pages));
    }

    /** Create comic metadata immediately. Only chapter content is sent to moderation. */
    @PostMapping("/comics") @Transactional
    public ApiResponse<Comic> createComic(@RequestBody Map<String,Object> body) {
        String title = text(body, "title", true, 180);
        String author = text(body, "author", true, 180);
        String description = text(body, "description", false, 5000);
        String coverUrl = coverPath(text(body, "coverUrl", false, 500));
        String status = text(body, "status", false, 80);
        String proposedRating = ageRating(body.getOrDefault("suggestedAgeRating", "ALL_AGES"));
        List<String> tags = tags(body.get("tags"));
        Comic comic = Comic.builder().title(title).author(author).description(description).coverUrl(coverUrl)
            .tags(tags).status(status.isBlank() ? "Đang tiến hành" : status)
            .createdByUserId(currentUserService.userId())
            .moderationStatus("APPROVED").ageRating("ALL_AGES").suggestedAgeRating(proposedRating)
            .reviewNotes(null).reviewedByUserId(null).reviewedAt(null).build();
        return new ApiResponse<>(true, "Đã tạo thông tin truyện. Bạn có thể tải chương; từng chương mới cần kiểm duyệt trước khi công khai.", comicRepository.save(comic));
    }

    /** Editing metadata/cover is not a chapter moderation event. */
    @PutMapping("/comics/{comicId}") @Transactional
    public ApiResponse<Comic> updateComic(@PathVariable Long comicId, @RequestBody Map<String,Object> body) {
        Comic comic = ownedComic(comicId);
        comic.setTitle(text(body, "title", true, 180));
        comic.setAuthor(text(body, "author", true, 180));
        comic.setDescription(text(body, "description", false, 5000));
        comic.setCoverUrl(coverPath(text(body, "coverUrl", false, 500)));
        String status = text(body, "status", false, 80);
        comic.setStatus(status.isBlank() ? comic.getStatus() : status);
        if (body.containsKey("tags")) comic.setTags(tags(body.get("tags")));
        if (body.containsKey("suggestedAgeRating")) comic.setSuggestedAgeRating(ageRating(body.get("suggestedAgeRating")));
        return new ApiResponse<>(true, "Đã cập nhật thông tin truyện. Nội dung chương không bị gửi duyệt lại chỉ vì sửa metadata.", comicRepository.save(comic));
    }

    @PostMapping("/comics/{comicId}/chapters") @Transactional
    public ApiResponse<Chapter> createChapter(@PathVariable Long comicId, @RequestBody Map<String,Object> body) {
        Comic comic = ownedComic(comicId);
        int number = positiveInt(body.get("chapterNumber"), "chapterNumber");
        String title = text(body, "title", true, 180);
        if (chapterRepository.findByComicIdOrderByChapterNumberAsc(comicId).stream().anyMatch(c -> c.getChapterNumber() == number)) throw new IllegalArgumentException("Số chương đã tồn tại trong truyện.");
        String type = contentType(body.getOrDefault("contentType", "IMAGE"));
        String contentText = text(body, "contentText", false, 500_000);
        if ("TEXT".equals(type) && contentText.isBlank()) throw new IllegalArgumentException("Chương chữ cần có nội dung.");
        String proposedRating = ageRating(body.getOrDefault("suggestedAgeRating", comic.getSuggestedAgeRating()));
        Chapter chapter = Chapter.builder().comic(comic).chapterNumber(number).title(title)
            .contentType(type).contentText("TEXT".equals(type) ? contentText : null)
            .moderationStatus("PENDING").suggestedAgeRating(proposedRating).ageRating(proposedRating)
            .reviewNotes(null).reviewedAt(null).reviewedByUserId(null).isVip(false).price(0).build();
        return new ApiResponse<>(true, "Đã tạo chương ở trạng thái chờ kiểm duyệt nội dung.", chapterRepository.save(chapter));
    }

    @PutMapping("/chapters/{chapterId}/content") @Transactional
    public ApiResponse<Chapter> updateTextChapter(@PathVariable Long chapterId, @RequestBody Map<String,Object> body) {
        Chapter chapter = chapterRepository.findById(chapterId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy chương."));
        ownedComic(chapter.getComic().getId());
        String content = text(body, "contentText", true, 500_000);
        if (!pageRepository.findByChapterIdOrderByPageNumberAsc(chapterId).isEmpty()) throw new IllegalArgumentException("Chương đang có ảnh trang. Hãy tạo chương chữ riêng hoặc xóa nội dung ảnh trước khi chuyển kiểu.");
        chapter.setContentType("TEXT"); chapter.setContentText(content);
        chapter.setModerationStatus("PENDING"); chapter.setReviewNotes(null); chapter.setReviewedByUserId(null); chapter.setReviewedAt(null);
        chapter.setAgeRating(chapter.getSuggestedAgeRating());
        return new ApiResponse<>(true, "Đã lưu nội dung chữ và gửi chương chờ kiểm duyệt.", chapterRepository.save(chapter));
    }

    /** Import one/many chapters from image files, ZIP/CBZ, PDF, TXT/MD, or a folder upload from desktop. */
    @PostMapping(value="/comics/{comicId}/import", consumes=MediaType.MULTIPART_FORM_DATA_VALUE) @Transactional
    public ApiResponse<Map<String,Object>> importChapters(
            @PathVariable Long comicId,
            @RequestParam("files") List<MultipartFile> files,
            @RequestParam(defaultValue="1") Integer startingChapterNumber,
            @RequestParam(defaultValue="") String title,
            @RequestParam(defaultValue="AUTO") String mode,
            @RequestParam(defaultValue="") String suggestedAgeRating,
            @RequestParam(required=false) String relativePaths) throws IOException {
        Comic comic = ownedComic(comicId);
        int starting = startingChapterNumber == null ? 1 : startingChapterNumber;
        if (starting < 1) throw new IllegalArgumentException("Số chương bắt đầu phải lớn hơn 0.");
        String rating = ageRating(suggestedAgeRating == null || suggestedAgeRating.isBlank() ? comic.getSuggestedAgeRating() : suggestedAgeRating);
        List<ChapterImportService.PreparedChapter> prepared = chapterImportService.prepare(files, relativePaths, mode, title);
        if (prepared.size() > 500) throw new IllegalArgumentException("Mỗi lần nhập tối đa 500 chương.");
        Set<Integer> existingNumbers = new HashSet<>();
        chapterRepository.findByComicIdOrderByChapterNumberAsc(comicId).forEach(c -> existingNumbers.add(c.getChapterNumber()));
        for (int i = 0; i < prepared.size(); i++) {
            int number = starting + i;
            if (existingNumbers.contains(number)) throw new IllegalArgumentException("Số chương " + number + " đã tồn tại. Hãy chọn số chương bắt đầu khác.");
        }

        Path base = Paths.get(uploadDir).toAbsolutePath().normalize();
        List<Path> createdFiles = new ArrayList<>();
        List<Chapter> createdChapters = new ArrayList<>();
        try {
            for (int i = 0; i < prepared.size(); i++) {
                ChapterImportService.PreparedChapter data = prepared.get(i);
                int number = starting + i;
                Chapter chapter = Chapter.builder().comic(comic).chapterNumber(number)
                    .title(textValue(data.title(), title.isBlank() ? "Chương " + number : title, 180))
                    .contentType(data.contentType()).contentText("TEXT".equals(data.contentType()) ? data.contentText() : null)
                    .moderationStatus("PENDING").suggestedAgeRating(rating).ageRating(rating)
                    .reviewNotes(null).reviewedByUserId(null).reviewedAt(null).isVip(false).price(0).build();
                chapter = chapterRepository.saveAndFlush(chapter);
                createdChapters.add(chapter);
                if (!data.pages().isEmpty()) {
                    String folder = "comics/" + comic.getId() + "/chapter-" + chapter.getId();
                    Path dir = base.resolve(folder).normalize();
                    if (!dir.startsWith(base)) throw new IllegalArgumentException("Đường dẫn lưu ảnh không hợp lệ.");
                    Files.createDirectories(dir);
                    int pageNumber = 1;
                    for (ChapterImportService.PreparedPage imported : data.pages()) {
                        String ext = safeImageExtension(imported.extension());
                        String filename = String.format(Locale.ROOT, "page-%05d-%s.%s", pageNumber, UUID.randomUUID().toString().substring(0, 8), ext);
                        Path destination = dir.resolve(filename).normalize();
                        if (!destination.startsWith(base)) throw new IllegalArgumentException("Đường dẫn file không hợp lệ.");
                        Files.write(destination, imported.bytes()); createdFiles.add(destination);
                        pageRepository.save(Page.builder().chapter(chapter).pageNumber(pageNumber)
                            .imageUrl("/uploads/" + folder + "/" + filename).build());
                        pageNumber++;
                    }
                }
            }
        } catch (Exception ex) {
            for (Path file : createdFiles) try { Files.deleteIfExists(file); } catch (IOException ignored) {}
            if (ex instanceof RuntimeException re) throw re;
            throw new IOException("Không thể lưu nội dung nhập vào.", ex);
        }
        comic.setSuggestedAgeRating(rating);
        // Creating/updating comic metadata does not need approval; each uploaded chapter does.
        comic.setModerationStatus("APPROVED");
        comicRepository.save(comic);
        List<Map<String,Object>> summaries = createdChapters.stream().map(chapter -> Map.<String,Object>of(
            "id", chapter.getId(), "chapterNumber", chapter.getChapterNumber(), "title", chapter.getTitle(),
            "contentType", chapter.getContentType(), "moderationStatus", chapter.getModerationStatus(),
            "suggestedAgeRating", chapter.getSuggestedAgeRating(), "pageCount", pageRepository.findByChapterIdOrderByPageNumberAsc(chapter.getId()).size()
        )).toList();
        return new ApiResponse<>(true, "Đã nhập " + summaries.size() + " chương. Từng chương đang chờ Moderator/Admin đọc nội dung và quyết định giới hạn tuổi.", Map.of("createdCount", summaries.size(), "chapters", summaries));
    }

    @PostMapping("/chapters/{chapterId}/pages") @Transactional
    public ApiResponse<Page> addPage(@PathVariable Long chapterId, @RequestParam("file") MultipartFile file, @RequestParam("pageNumber") Integer pageNumber) throws Exception {
        if (file == null || file.isEmpty()) throw new IllegalArgumentException("Vui lòng chọn ảnh trang truyện.");
        if (pageNumber == null || pageNumber < 1) throw new IllegalArgumentException("pageNumber phải lớn hơn 0.");
        String type = file.getContentType() == null ? "" : file.getContentType().toLowerCase(Locale.ROOT);
        if (!List.of("image/jpeg", "image/png", "image/webp").contains(type)) throw new IllegalArgumentException("Chỉ chấp nhận ảnh JPEG, PNG hoặc WebP.");
        if (file.getSize() > 10 * 1024 * 1024) throw new IllegalArgumentException("Mỗi trang ảnh tối đa 10 MB.");
        Chapter chapter = chapterRepository.findById(chapterId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy chương."));
        Comic comic = ownedComic(chapter.getComic().getId());
        if (pageRepository.findByChapterIdOrderByPageNumberAsc(chapterId).stream().anyMatch(p -> p.getPageNumber().equals(pageNumber))) throw new IllegalArgumentException("Số trang đã tồn tại trong chương.");
        String ext = switch (type) { case "image/jpeg" -> ".jpg"; case "image/png" -> ".png"; default -> ".webp"; };
        String folder = "comics/" + comic.getId() + "/chapter-" + chapterId;
        Path base = Paths.get(uploadDir).toAbsolutePath().normalize();
        Path dir = base.resolve(folder).normalize();
        if (!dir.startsWith(base)) throw new IllegalArgumentException("Đường dẫn upload không hợp lệ.");
        Files.createDirectories(dir);
        String filename = String.format(Locale.ROOT, "page-%05d-%s%s", pageNumber, UUID.randomUUID().toString().substring(0,8), ext);
        Path target = dir.resolve(filename);
        file.transferTo(target);
        Page page = Page.builder().chapter(chapter).pageNumber(pageNumber).imageUrl("/uploads/" + folder + "/" + filename).build();
        chapter.setContentType("IMAGE"); chapter.setContentText(null);
        chapter.setModerationStatus("PENDING"); chapter.setAgeRating(chapter.getSuggestedAgeRating()); chapter.setReviewNotes(null); chapter.setReviewedAt(null); chapter.setReviewedByUserId(null);
        chapterRepository.save(chapter);
        return new ApiResponse<>(true, "Đã thêm trang ảnh; chương được đưa về trạng thái chờ kiểm duyệt.", pageRepository.save(page));
    }

    @DeleteMapping("/comics/{comicId}") @Transactional
    public ApiResponse<Map<String,Object>> deleteAuthorComic(@PathVariable Long comicId) {
        Comic comic = ownedComic(comicId);
        boolean hasPublishedChapter = chapterRepository.findByComicIdOrderByChapterNumberAsc(comicId).stream().anyMatch(c -> "APPROVED".equalsIgnoreCase(c.getModerationStatus()));
        if (hasPublishedChapter) throw new AccessDeniedException("Truyện đã có chương được duyệt cần gửi yêu cầu gỡ; chỉ Admin/Moderator được ẩn trực tiếp.");
        comic.setModerationStatus("HIDDEN"); comicRepository.save(comic);
        return new ApiResponse<>(true, "Đã ẩn truyện khỏi danh sách công khai.", Map.of("comicId", comicId));
    }

    private Comic ownedComic(Long comicId) {
        Comic comic = comicRepository.findById(comicId).orElseThrow(() -> new IllegalArgumentException("Không tìm thấy truyện."));
        if (!"ADMIN".equals(currentUserService.role()) && !currentUserService.userId().equals(comic.getCreatedByUserId())) throw new AccessDeniedException("Bạn chỉ được quản lý truyện thuộc tài khoản của mình.");
        return comic;
    }
    private String text(Map<String,Object> body, String key, boolean required, int max) {
        Object raw = body.get(key); String value = raw == null ? "" : raw.toString().trim();
        if (required && value.isBlank()) throw new IllegalArgumentException(key + " không được để trống.");
        if (value.length() > max) throw new IllegalArgumentException(key + " vượt quá " + max + " ký tự.");
        return value;
    }
    private String textValue(String value, String fallback, int max) {
        String result = value == null || value.isBlank() ? fallback : value.trim();
        if (result.length() > max) result = result.substring(0, max);
        return result;
    }
    private int positiveInt(Object raw, String field) {
        try { int value = Integer.parseInt(String.valueOf(raw)); if (value > 0) return value; }
        catch (Exception ignored) {}
        throw new IllegalArgumentException(field + " phải là số nguyên dương.");
    }
    private String ageRating(Object raw) {
        String value = raw == null ? "ALL_AGES" : raw.toString().trim().toUpperCase(Locale.ROOT);
        if (!List.of("ALL_AGES", "13+", "16+", "18+").contains(value)) throw new IllegalArgumentException("Độ tuổi hợp lệ: ALL_AGES, 13+, 16+ hoặc 18+.");
        return value;
    }
    private String contentType(Object raw) {
        String value = raw == null ? "IMAGE" : raw.toString().trim().toUpperCase(Locale.ROOT);
        if (!List.of("IMAGE", "TEXT").contains(value)) throw new IllegalArgumentException("contentType chỉ nhận IMAGE hoặc TEXT.");
        return value;
    }
    private String coverPath(String value) {
        if (value.isBlank()) return value;
        if (!value.startsWith("/uploads/") || value.contains("..") || value.contains("\\")) throw new IllegalArgumentException("Ảnh bìa phải được tải lên Backend và dùng đường dẫn /uploads/...");
        return value;
    }
    private String safeImageExtension(String ext) {
        String value = ext == null ? "jpg" : ext.toLowerCase(Locale.ROOT);
        if (!List.of("jpg", "jpeg", "png", "webp", "gif", "bmp", "tif", "tiff").contains(value)) throw new IllegalArgumentException("Định dạng ảnh không hợp lệ.");
        return "jpeg".equals(value) ? "jpg" : value;
    }
    private List<String> tags(Object raw) {
        if (raw == null) return new ArrayList<>();
        List<String> values = new ArrayList<>();
        if (raw instanceof List<?> list) for (Object item : list) { String v = String.valueOf(item).trim(); if (!v.isBlank() && !values.contains(v) && v.length() <= 60 && values.size() < 12) values.add(v); }
        return values;
    }
}
