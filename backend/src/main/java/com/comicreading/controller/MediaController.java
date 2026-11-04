package com.comicreading.controller;

import com.comicreading.entity.Comic;
import com.comicreading.entity.Page;
import com.comicreading.repository.ComicRepository;
import com.comicreading.repository.PageRepository;
import com.comicreading.security.CurrentUserService;
import com.comicreading.service.ContentAccessService;
import lombok.RequiredArgsConstructor;
import jakarta.servlet.http.HttpServletRequest;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.core.io.FileSystemResource;
import org.springframework.core.io.Resource;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.access.AccessDeniedException;
import org.springframework.stereotype.Controller;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;

@Controller
@RequiredArgsConstructor
public class MediaController {
    private final ComicRepository comicRepository;
    private final PageRepository pageRepository;
    private final ContentAccessService contentAccessService;
    private final CurrentUserService currentUserService;
    @Value("${app.upload.dir:uploads}") private String uploadDir;

    /** Files are delivered through this controller so age and moderation rules also apply to direct image URLs. */
    @GetMapping("/uploads/{*path}")
    @Transactional(readOnly = true)
    public ResponseEntity<Resource> serve(@PathVariable("path") String rawPath, HttpServletRequest request) throws Exception {
        String relative = rawPath == null ? "" : rawPath.replaceFirst("^/", "");
        Path root = Paths.get(uploadDir).toAbsolutePath().normalize();
        Path file = root.resolve(relative).normalize();
        if (!file.startsWith(root) || !Files.isRegularFile(file)) return ResponseEntity.notFound().build();

        String url = "/uploads/" + relative.replace('\\', '/');
        Comic associatedComic = comicRepository.findByCoverUrl(url).orElse(null);
        Page associatedPage = null;
        if (associatedComic == null) {
            associatedPage = pageRepository.findByImageUrl(url).orElse(null);
            if (associatedPage != null) associatedComic = associatedPage.getChapter().getComic();
        }
        if (associatedPage != null) {
            contentAccessService.requireReadable(associatedPage.getChapter());
        } else if (associatedComic != null) {
            contentAccessService.requireReadableCover(associatedComic);
        } else {
            // Staged uploads are not public: allow only reviewers until a file is linked to an approved comic.
            var principal = contentAccessService.currentPrincipal();
            if (principal == null || !("ADMIN".equals(principal.role()) || "MODERATOR".equals(principal.role()))) {
                throw new AccessDeniedException("Tệp chưa được gắn với truyện được duyệt; chỉ đội ngũ kiểm duyệt có thể xem tệp chờ liên kết.");
            }
        }
        String contentType = Files.probeContentType(file);
        MediaType mediaType = contentType == null ? MediaType.APPLICATION_OCTET_STREAM : MediaType.parseMediaType(contentType);
        return ResponseEntity.ok().contentType(mediaType).header("X-Content-Type-Options", "nosniff")
            .header("Cache-Control", "private, max-age=300").body(new FileSystemResource(file));
    }
}
