package com.comicreading.service;

import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import org.apache.pdfbox.pdmodel.PDDocument;
import org.apache.pdfbox.rendering.PDFRenderer;
import org.apache.pdfbox.text.PDFTextStripper;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

import javax.imageio.ImageIO;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.*;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/** Safely prepares chapter assets for Author Studio import. Archive entries are never extracted by path. */
@Service
public class ChapterImportService {
    private static final long MAX_UPLOAD_BYTES = 250L * 1024 * 1024;
    private static final long MAX_EXPANDED_BYTES = 250L * 1024 * 1024;
    private static final int MAX_ASSETS = 1500;
    private static final int MAX_PDF_PAGES = 500;
    private static final Pattern CHAPTER_FOLDER = Pattern.compile("(?i).*(chapter|chap|chương|chuong|tập|tap|episode|ep|volume|vol|part)[ _.-]*\\d+.*");
    private static final Set<String> IMAGE_EXTENSIONS = Set.of("jpg", "jpeg", "png", "webp", "gif", "bmp", "tif", "tiff");
    private static final Set<String> TEXT_EXTENSIONS = Set.of("txt", "md");
    private final ObjectMapper mapper = new ObjectMapper();

    public record PreparedPage(String filename, byte[] bytes, String extension) {}
    public record PreparedChapter(String title, String contentType, String contentText, List<PreparedPage> pages) {}
    private record Asset(String path, byte[] bytes, String extension) {}
    private record PdfContent(String text, List<PreparedPage> pages) {}

    public List<PreparedChapter> prepare(List<MultipartFile> uploads, String relativePathsJson, String requestedMode, String fallbackTitle) throws IOException {
        if (uploads == null || uploads.isEmpty() || uploads.stream().allMatch(f -> f == null || f.isEmpty())) {
            throw new IllegalArgumentException("Hãy chọn ảnh, thư mục nén ZIP/CBZ, PDF hoặc file văn bản để nhập.");
        }
        long incomingTotal = uploads.stream().filter(Objects::nonNull).mapToLong(MultipartFile::getSize).sum();
        if (incomingTotal > MAX_UPLOAD_BYTES) throw new IllegalArgumentException("Tổng dung lượng file tải lên tối đa 250 MB mỗi lần.");

        List<String> relativePaths = List.of();
        if (relativePathsJson != null && !relativePathsJson.isBlank()) {
            try { relativePaths = mapper.readValue(relativePathsJson, new TypeReference<List<String>>() {}); }
            catch (Exception ex) { throw new IllegalArgumentException("Danh sách đường dẫn thư mục không hợp lệ."); }
            if (relativePaths.size() != uploads.size()) throw new IllegalArgumentException("Danh sách file không khớp với đường dẫn thư mục.");
        }

        List<Asset> assets = new ArrayList<>();
        long expandedTotal = 0;
        for (int i = 0; i < uploads.size(); i++) {
            MultipartFile upload = uploads.get(i);
            if (upload == null || upload.isEmpty()) continue;
            String original = i < relativePaths.size() ? safeRelativePath(relativePaths.get(i)) : safeFilename(upload.getOriginalFilename());
            byte[] data = upload.getBytes();
            String ext = extension(original);
            if ("zip".equals(ext) || "cbz".equals(ext)) {
                List<Asset> extracted = readArchive(data);
                // Keep each archive in its own virtual folder. This prevents two CBZ/PDF archives
                // selected together (or inside one directory upload) from merging into one chapter.
                String archiveFolder = stripExtension(baseName(original));
                String parentPrefix = parentPath(original);
                String prefix = parentPrefix.isEmpty() ? archiveFolder + "/" : parentPrefix + "/" + archiveFolder + "/";
                for (Asset asset : extracted) {
                    expandedTotal += asset.bytes().length;
                    if (expandedTotal > MAX_EXPANDED_BYTES) throw new IllegalArgumentException("Nội dung sau giải nén vượt quá giới hạn 250 MB.");
                    assets.add(new Asset(prefix + asset.path(), asset.bytes(), asset.extension()));
                }
            } else {
                // A cover included alongside chapter folders should remain comic metadata, not become chapter 1.
                if (IMAGE_EXTENSIONS.contains(ext) && isStandaloneCoverAsset(original)) {
                    expandedTotal += data.length;
                    continue;
                }
                String assetPath = original;
                // A batch of root-level documents (PDF/TXT/MD) represents separate chapters.
                // Preserve explicit chapter folders from directory uploads, but create a virtual
                // folder for root-level documents so Chapter 1.pdf and Chapter 2.pdf do not merge.
                if (!IMAGE_EXTENSIONS.contains(ext) && uploads.size() > 1
                        && (relativePaths.isEmpty() || parentPath(original).isEmpty())) {
                    assetPath = stripExtension(baseName(original)) + "/" + baseName(original);
                }
                assets.add(new Asset(assetPath, data, ext));
                expandedTotal += data.length;
            }
            if (assets.size() > MAX_ASSETS) throw new IllegalArgumentException("Một lần nhập tối đa 1.500 file ảnh/văn bản.");
        }
        if (expandedTotal > MAX_EXPANDED_BYTES) throw new IllegalArgumentException("Tổng nội dung vượt quá giới hạn 250 MB.");
        if (assets.isEmpty()) throw new IllegalArgumentException("Không tìm thấy ảnh hoặc văn bản hỗ trợ trong file đã chọn.");

        String mode = requestedMode == null ? "AUTO" : requestedMode.trim().toUpperCase(Locale.ROOT);
        if (!Set.of("AUTO", "IMAGE", "TEXT").contains(mode)) throw new IllegalArgumentException("Chế độ nhập không hợp lệ.");
        Map<String, List<Asset>> groups = groupAssets(assets, fallbackTitle);
        List<PreparedChapter> result = new ArrayList<>();
        for (Map.Entry<String, List<Asset>> entry : groups.entrySet()) {
            result.add(prepareGroup(entry.getKey(), entry.getValue(), mode));
        }
        result.sort((a, b) -> naturalCompare(a.title(), b.title()));
        if (result.isEmpty()) throw new IllegalArgumentException("Không thể tạo chương từ các file đã chọn.");
        return result;
    }

    private List<Asset> readArchive(byte[] archiveBytes) throws IOException {
        List<Asset> result = new ArrayList<>();
        long total = 0;
        try (ZipInputStream zip = new ZipInputStream(new ByteArrayInputStream(archiveBytes))) {
            ZipEntry entry;
            while ((entry = zip.getNextEntry()) != null) {
                if (entry.isDirectory()) { zip.closeEntry(); continue; }
                String entryName = safeRelativePath(entry.getName());
                String ext = extension(entryName);
                if (!IMAGE_EXTENSIONS.contains(ext) && !TEXT_EXTENSIONS.contains(ext) && !"pdf".equals(ext)) {
                    zip.closeEntry(); continue;
                }
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                byte[] buffer = new byte[8192];
                int read;
                while ((read = zip.read(buffer)) != -1) {
                    total += read;
                    if (total > MAX_EXPANDED_BYTES) throw new IllegalArgumentException("File ZIP/CBZ giải nén vượt quá 250 MB.");
                    out.write(buffer, 0, read);
                }
                if (IMAGE_EXTENSIONS.contains(ext) && isStandaloneCoverAsset(entryName)) {
                    zip.closeEntry();
                    continue;
                }
                result.add(new Asset(entryName, out.toByteArray(), ext));
                if (result.size() > MAX_ASSETS) throw new IllegalArgumentException("File ZIP/CBZ có quá nhiều file (tối đa 1.500).");
                zip.closeEntry();
            }
        }
        return result;
    }

    private Map<String, List<Asset>> groupAssets(List<Asset> assets, String fallbackTitle) {
        // Flat files form one chapter. Folders named Chapter 1/Chương 2/Vol 3 form distinct chapters.
        Map<String, List<Asset>> groups = new LinkedHashMap<>();
        int chapterDepth = findChapterFolderDepth(assets);
        for (Asset asset : assets) {
            String[] segments = normalizePath(asset.path()).split("/");
            String group = null;
            if (chapterDepth >= 0 && segments.length > chapterDepth + 1) group = segments[chapterDepth];
            if (group == null || group.isBlank()) group = cleanTitle(fallbackTitle, "Chương 1");
            groups.computeIfAbsent(group, ignored -> new ArrayList<>()).add(asset);
        }
        if (groups.size() > 1) {
            Map<String, List<Asset>> sorted = new TreeMap<>(ChapterImportService::naturalCompare);
            sorted.putAll(groups);
            return sorted;
        }
        return groups;
    }

    private int findChapterFolderDepth(List<Asset> assets) {
        int maxDirDepth = assets.stream().mapToInt(a -> normalizePath(a.path()).split("/").length - 1).max().orElse(0);
        // Prefer explicit Chapter/Vol/Part names at any depth.
        for (int depth = 0; depth < maxDirDepth; depth++) {
            for (Asset asset : assets) {
                String[] segments = normalizePath(asset.path()).split("/");
                if (segments.length > depth + 1 && CHAPTER_FOLDER.matcher(segments[depth]).matches()) return depth;
            }
        }
        // Otherwise only split by folders if there are multiple non-generic directories at a common level.
        for (int depth = maxDirDepth - 1; depth >= 0; depth--) {
            Set<String> names = new HashSet<>();
            for (Asset asset : assets) {
                String[] segments = normalizePath(asset.path()).split("/");
                if (segments.length > depth + 1 && !isGenericFolder(segments[depth])) names.add(segments[depth]);
            }
            if (names.size() > 1) return depth;
        }
        return -1;
    }

    private PreparedChapter prepareGroup(String groupName, List<Asset> group, String mode) throws IOException {
        List<PreparedPage> pages = new ArrayList<>();
        List<String> texts = new ArrayList<>();
        List<Asset> sorted = new ArrayList<>(group);
        sorted.sort((a, b) -> naturalCompare(a.path(), b.path()));
        for (Asset asset : sorted) {
            String ext = asset.extension();
            if (IMAGE_EXTENSIONS.contains(ext)) {
                if ("TEXT".equals(mode)) throw new IllegalArgumentException("Bạn chọn chế độ truyện chữ nhưng file có ảnh: " + baseName(asset.path()));
                validateImage(asset.bytes(), asset.path());
                String cleanExt = "jpeg".equals(ext) ? "jpg" : ext;
                byte[] imageBytes = asset.bytes();
                // Flutter/mobile decoders do not universally support TIFF/BMP. Normalize these
                // formats to JPEG while preserving the original order and chapter grouping.
                if (Set.of("bmp", "tif", "tiff").contains(ext)) {
                    BufferedImage decoded = ImageIO.read(new ByteArrayInputStream(asset.bytes()));
                    if (decoded == null) throw new IllegalArgumentException("Không thể đọc ảnh: " + asset.path());
                    ByteArrayOutputStream jpeg = new ByteArrayOutputStream();
                    if (!ImageIO.write(decoded, "jpg", jpeg)) throw new IOException("Không thể chuyển ảnh thành JPEG: " + asset.path());
                    imageBytes = jpeg.toByteArray();
                    cleanExt = "jpg";
                }
                pages.add(new PreparedPage(baseName(asset.path()), imageBytes, cleanExt));
            } else if (TEXT_EXTENSIONS.contains(ext)) {
                if ("IMAGE".equals(mode)) throw new IllegalArgumentException("Bạn chọn chế độ truyện hình nhưng file có văn bản: " + baseName(asset.path()));
                String text = new String(asset.bytes(), StandardCharsets.UTF_8).trim();
                if (!text.isBlank()) texts.add("## " + stripExtension(baseName(asset.path())) + "\n\n" + text);
            } else if ("pdf".equals(ext)) {
                PdfContent pdf = preparePdf(asset.bytes(), mode, baseName(asset.path()));
                if (!pdf.text().isBlank()) texts.add("## " + stripExtension(baseName(asset.path())) + "\n\n" + pdf.text());
                pages.addAll(pdf.pages());
            } else {
                throw new IllegalArgumentException("Định dạng không được hỗ trợ: " + ext);
            }
        }
        if (!texts.isEmpty() && !pages.isEmpty()) throw new IllegalArgumentException("Một chương đang trộn truyện chữ và truyện hình. Hãy tách thành hai chương hoặc nhập theo thư mục riêng.");
        if (!texts.isEmpty()) return new PreparedChapter(groupName, "TEXT", String.join("\n\n", texts), List.of());
        if (!pages.isEmpty()) {
            pages.sort((a, b) -> naturalCompare(a.filename(), b.filename()));
            return new PreparedChapter(groupName, "IMAGE", "", pages);
        }
        throw new IllegalArgumentException("Không tìm thấy nội dung hợp lệ trong nhóm " + groupName + ".");
    }

    private PdfContent preparePdf(byte[] bytes, String mode, String filename) throws IOException {
        try (PDDocument document = PDDocument.load(bytes)) {
            if (document.getNumberOfPages() > MAX_PDF_PAGES) throw new IllegalArgumentException("PDF có quá 500 trang: " + filename);
            String text = new PDFTextStripper().getText(document).trim();
            if ("TEXT".equals(mode)) {
                if (text.isBlank()) throw new IllegalArgumentException("PDF không có lớp văn bản có thể trích xuất: " + filename + ". Hãy chọn chế độ Truyện hình.");
                return new PdfContent(text, List.of());
            }
            if ("AUTO".equals(mode) && text.length() >= 80) return new PdfContent(text, List.of());
            PDFRenderer renderer = new PDFRenderer(document);
            List<PreparedPage> pages = new ArrayList<>();
            for (int i = 0; i < document.getNumberOfPages(); i++) {
                BufferedImage image = renderer.renderImageWithDPI(i, 120);
                ByteArrayOutputStream out = new ByteArrayOutputStream();
                if (!ImageIO.write(image, "jpg", out)) throw new IOException("Không thể chuyển trang PDF thành ảnh JPEG.");
                pages.add(new PreparedPage(stripExtension(filename) + "-" + String.format(Locale.ROOT, "%05d", i + 1) + ".jpg", out.toByteArray(), "jpg"));
            }
            return new PdfContent("", pages);
        }
    }

    private void validateImage(byte[] bytes, String name) throws IOException {
        String ext = extension(name);
        if ("webp".equals(ext)) {
            if (bytes.length < 12 || bytes[0] != 'R' || bytes[1] != 'I' || bytes[2] != 'F' || bytes[3] != 'F' || bytes[8] != 'W' || bytes[9] != 'E' || bytes[10] != 'B' || bytes[11] != 'P') {
                throw new IllegalArgumentException("File WEBP không hợp lệ: " + name);
            }
            return;
        }
        BufferedImage image = ImageIO.read(new ByteArrayInputStream(bytes));
        if (image == null) throw new IllegalArgumentException("File không phải ảnh hợp lệ hoặc định dạng chưa được hỗ trợ: " + name);
        long pixels = (long) image.getWidth() * image.getHeight();
        if (image.getWidth() > 25000 || image.getHeight() > 25000 || pixels > 100_000_000L) throw new IllegalArgumentException("Kích thước ảnh quá lớn: " + name);
    }

    private boolean isStandaloneCoverAsset(String path) {
        String name = stripExtension(baseName(path)).toLowerCase(Locale.ROOT);
        if (!Set.of("cover", "poster", "thumbnail", "thumb", "folder", "banner").contains(name)) return false;
        String parent = parentPath(path);
        if (parent.isBlank()) return true;
        for (String segment : parent.split("/")) {
            if (CHAPTER_FOLDER.matcher(segment).matches()) return false;
        }
        return true;
    }

    private String safeFilename(String value) {
        if (value == null || value.isBlank()) return "upload.bin";
        return value.replace('\\', '/').substring(value.replace('\\', '/').lastIndexOf('/') + 1);
    }
    private String safeRelativePath(String value) {
        if (value == null || value.isBlank()) throw new IllegalArgumentException("Tên/đường dẫn file trống.");
        String path = normalizePath(value);
        if (path.startsWith("/") || path.matches("^[A-Za-z]:.*")) throw new IllegalArgumentException("Đường dẫn file không hợp lệ.");
        for (String part : path.split("/")) if (part.equals("..") || part.equals(".")) throw new IllegalArgumentException("Đường dẫn file không hợp lệ.");
        return path;
    }
    private String normalizePath(String path) { return path == null ? "" : path.replace('\\', '/').replaceAll("/+", "/").replaceFirst("^\\./", ""); }
    private String extension(String name) { int p = name.lastIndexOf('.'); return p < 0 ? "" : name.substring(p + 1).toLowerCase(Locale.ROOT); }
    private String baseName(String name) { String clean = normalizePath(name); return clean.substring(clean.lastIndexOf('/') + 1); }
    private String parentPath(String name) { String clean = normalizePath(name); int p = clean.lastIndexOf('/'); return p < 0 ? "" : clean.substring(0, p); }
    private String stripExtension(String name) { int p = name.lastIndexOf('.'); return p < 0 ? name : name.substring(0, p); }
    private String cleanTitle(String value, String fallback) { String t = value == null ? "" : value.trim(); return t.isBlank() ? fallback : t; }
    private boolean isGenericFolder(String name) { return Set.of("comic", "comics", "manga", "manhwa", "manhua", "images", "image", "pages", "content", "root", "uploads", "files", "truyen", "truyện").contains(name.toLowerCase(Locale.ROOT)); }

    private static int naturalCompare(String left, String right) {
        String a = left == null ? "" : left.toLowerCase(Locale.ROOT);
        String b = right == null ? "" : right.toLowerCase(Locale.ROOT);
        int i = 0, j = 0;
        while (i < a.length() && j < b.length()) {
            char ca = a.charAt(i), cb = b.charAt(j);
            if (Character.isDigit(ca) && Character.isDigit(cb)) {
                int ai = i, bj = j;
                while (ai < a.length() && a.charAt(ai) == '0') ai++;
                while (bj < b.length() && b.charAt(bj) == '0') bj++;
                int ae = ai, be = bj;
                while (ae < a.length() && Character.isDigit(a.charAt(ae))) ae++;
                while (be < b.length() && Character.isDigit(b.charAt(be))) be++;
                int alen = ae - ai, blen = be - bj;
                if (alen != blen) return Integer.compare(alen, blen);
                int cmp = a.substring(ai, ae).compareTo(b.substring(bj, be));
                if (cmp != 0) return cmp;
                i = ae; j = be;
            } else {
                if (ca != cb) return Character.compare(ca, cb);
                i++; j++;
            }
        }
        return Integer.compare(a.length() - i, b.length() - j);
    }
}
