#!/usr/bin/env python3
"""Smart Story Comic Importer

Import one comic from a folder, ZIP/CBZ archive, or a PDF into the existing
Spring Boot + PostgreSQL project. Images and PDF pages are normalized to JPEG.
"""
from __future__ import annotations

import argparse
import getpass
import json
import os
import re
import shutil
import sys
import tempfile
import unicodedata
import zipfile
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from typing import Iterable

try:
    from PIL import Image, ImageOps
except ImportError:
    print("Thiếu Pillow. Chạy: python -m pip install -r backend/tools/requirements-importer.txt")
    raise SystemExit(2)

try:
    import fitz  # PyMuPDF
except ImportError:
    print("Thiếu PyMuPDF. Chạy: python -m pip install -r backend/tools/requirements-importer.txt")
    raise SystemExit(2)

IMAGE_EXTS = {".jpg", ".jpeg", ".png", ".webp", ".bmp", ".gif", ".tif", ".tiff"}
ARCHIVE_EXTS = {".zip", ".cbz"}
PDF_EXTS = {".pdf"}
MEDIA_EXTS = IMAGE_EXTS | PDF_EXTS
COVER_WORDS = {"cover", "coverimage", "poster", "thumbnail", "thumb", "folder", "frontcover", "bookcover", "bia", "anhbia"}
MAX_ARCHIVE_FILES = 100_000
MAX_ARCHIVE_UNCOMPRESSED_BYTES = 5 * 1024 * 1024 * 1024  # 5 GiB safety limit
MAX_IMAGE_EDGE = 2400
PDF_SCALE = 1.5

BACKEND_DIR = Path(__file__).resolve().parents[1]
UPLOADS_DIR = BACKEND_DIR / "uploads"


@dataclass
class ChapterSource:
    name: str
    kind: str  # "directory", "archive", "pdf", "flat"
    path: Path | None = None
    files: list[Path] | None = None


@dataclass
class PreparedChapter:
    number: int
    title: str
    page_files: list[Path]


def natural_key(value: str | Path):
    text = str(value).replace("\\", "/").casefold()
    return [int(part) if part.isdigit() else part for part in re.split(r"(\d+)", text)]


def safe_slug(value: str) -> str:
    value = unicodedata.normalize("NFKD", value)
    value = "".join(char for char in value if not unicodedata.combining(char))
    value = re.sub(r"[^A-Za-z0-9]+", "-", value).strip("-").lower()
    return (value[:60] or "comic")


def is_image(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in IMAGE_EXTS


def is_pdf(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in PDF_EXTS


def is_archive(path: Path) -> bool:
    return path.is_file() and path.suffix.lower() in ARCHIVE_EXTS


def all_media_files(folder: Path) -> list[Path]:
    files = [
        p for p in folder.rglob("*")
        if p.is_file()
        and p.suffix.lower() in MEDIA_EXTS
        and not p.name.startswith("._")
        and "__MACOSX" not in p.parts
    ]
    return sorted(files, key=lambda p: natural_key(p.relative_to(folder)))


def root_images(folder: Path) -> list[Path]:
    return sorted(
        [p for p in folder.iterdir() if is_image(p) and not p.name.startswith("._")],
        key=lambda p: natural_key(p.name),
    )


def looks_like_cover(path: Path) -> bool:
    stem = re.sub(r"[^a-z0-9]", "", path.stem.casefold())
    return stem in COVER_WORDS or any(stem.startswith(word) for word in COVER_WORDS)


def safe_extract_zip(archive_path: Path, destination: Path) -> None:
    """Extract ZIP/CBZ without allowing path traversal or huge accidental archives."""
    destination.mkdir(parents=True, exist_ok=True)
    root = destination.resolve()
    with zipfile.ZipFile(archive_path, "r") as zf:
        entries = [entry for entry in zf.infolist() if not entry.is_dir()]
        if len(entries) > MAX_ARCHIVE_FILES:
            raise ValueError(f"Archive có quá nhiều file ({len(entries):,}); giới hạn là {MAX_ARCHIVE_FILES:,}.")
        total_size = sum(entry.file_size for entry in entries)
        if total_size > MAX_ARCHIVE_UNCOMPRESSED_BYTES:
            raise ValueError("Archive sau giải nén vượt quá giới hạn an toàn 5 GiB.")
        for entry in zf.infolist():
            target = (destination / entry.filename).resolve()
            if target != root and root not in target.parents:
                raise ValueError(f"Archive chứa đường dẫn không an toàn: {entry.filename}")
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            # Ignore Unix symlink entries rather than materializing them.
            unix_mode = (entry.external_attr >> 16) & 0xFFFF
            if (unix_mode & 0o170000) == 0o120000:
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            with zf.open(entry, "r") as source, target.open("wb") as dest:
                shutil.copyfileobj(source, dest)


def collapse_single_wrapper(folder: Path) -> Path:
    """CBZ/ZIPs commonly contain one wrapper folder; make that the comic root."""
    current = folder
    while True:
        children = list(current.iterdir())
        dirs = [child for child in children if child.is_dir()]
        files = [child for child in children if child.is_file()]
        if len(dirs) == 1 and not files:
            current = dirs[0]
        else:
            return current


def choose_source_gui() -> Path | None:
    try:
        import tkinter as tk
        from tkinter import filedialog, messagebox
    except Exception:
        print("Không khởi tạo được hộp thoại chọn file. Hãy chạy với --source <đường_dẫn>.")
        return None

    root = tk.Tk()
    root.withdraw()
    try:
        folder_first = messagebox.askyesnocancel(
            "Smart Story - Nhập truyện",
            "Chọn YES để chọn thư mục truyện đã giải nén.\n"
            "Chọn NO để chọn file ZIP/CBZ/PDF.\n"
            "Chọn CANCEL để thoát.",
            parent=root,
        )
        if folder_first is None:
            return None
        if folder_first:
            selected = filedialog.askdirectory(title="Chọn thư mục của một bộ truyện", parent=root)
            return Path(selected) if selected else None
        selected = filedialog.askopenfilename(
            title="Chọn file truyện ZIP, CBZ hoặc PDF",
            filetypes=[("Truyện nén hoặc PDF", "*.zip *.cbz *.pdf"), ("ZIP", "*.zip"), ("Comic Book ZIP", "*.cbz"), ("PDF", "*.pdf")],
            parent=root,
        )
        return Path(selected) if selected else None
    finally:
        root.destroy()


def choose_cover_gui(folder: Path) -> Path | None:
    try:
        import tkinter as tk
        from tkinter import filedialog, messagebox
        root = tk.Tk()
        root.withdraw()
        try:
            want = messagebox.askyesno(
                "Ảnh bìa",
                "Không tìm thấy file bìa có tên cover/poster/thumb.\n"
                "Bạn có muốn tự chọn ảnh bìa không?\n\n"
                "Chọn No để dùng trang đầu làm ảnh bìa (trang đầu vẫn được giữ trong chương).",
                parent=root,
            )
            if not want:
                return None
            value = filedialog.askopenfilename(
                title="Chọn ảnh bìa",
                initialdir=str(folder),
                filetypes=[("Ảnh", "*.jpg *.jpeg *.png *.webp *.bmp *.gif *.tif *.tiff"), ("Tất cả file", "*.*")],
                parent=root,
            )
            return Path(value) if value else None
        finally:
            root.destroy()
    except Exception:
        return None


def resolve_selected_source(source: Path, work_dir: Path) -> tuple[Path | None, Path | None]:
    """Return a folder root or a standalone PDF path. ZIP/CBZ is extracted safely."""
    source = source.expanduser().resolve()
    if not source.exists():
        raise FileNotFoundError(f"Không tìm thấy đường dẫn: {source}")
    if source.is_dir():
        return source, None
    if is_archive(source):
        extracted = work_dir / "selected_archive"
        safe_extract_zip(source, extracted)
        root = collapse_single_wrapper(extracted)
        return root, None
    if is_pdf(source):
        return None, source
    raise ValueError("Chỉ hỗ trợ thư mục, ZIP, CBZ hoặc PDF.")


def has_media(folder: Path) -> bool:
    return any(p.is_file() and (p.suffix.lower() in MEDIA_EXTS or p.suffix.lower() in ARCHIVE_EXTS) for p in folder.rglob("*"))


def discover_chapters(folder: Path) -> tuple[list[ChapterSource], Path | None]:
    """Find chapter folders, root-level PDFs/archives, or a flat root image chapter."""
    top_items: list[ChapterSource] = []
    for child in folder.iterdir():
        if child.is_dir() and has_media(child):
            top_items.append(ChapterSource(name=child.name, kind="directory", path=child))
        elif is_pdf(child):
            top_items.append(ChapterSource(name=child.stem, kind="pdf", path=child))
        elif is_archive(child):
            top_items.append(ChapterSource(name=child.stem, kind="archive", path=child))

    top_items.sort(key=lambda item: natural_key(item.name))
    images = root_images(folder)
    named_covers = [image for image in images if looks_like_cover(image)]
    detected_cover = named_covers[0] if named_covers else None

    if not top_items and images:
        page_images = [image for image in images if image != detected_cover]
        # If only a named cover is present, it is also kept as a page so the chapter is not empty.
        if not page_images:
            page_images = images
        top_items = [ChapterSource(name="Chương 1", kind="flat", files=page_images)]
    return top_items, detected_cover


def chapter_title(index: int, raw_name: str) -> str:
    cleaned = re.sub(r"[_]+", " ", raw_name).strip()
    cleaned = re.sub(r"\s+", " ", cleaned)
    match = re.match(r"(?i)^(?:chapter|chap|chương|chuong|ch)\s*[-_.# ]*0*(\d+)\s*[-_.: ]*?(.*)$", cleaned)
    if match:
        number = int(match.group(1))
        rest = match.group(2).strip(" -_.:")
        return f"Chương {number}" + (f" - {rest}" if rest else "")
    match = re.match(r"^0*(\d+)\s*[-_.: ]+(.+)$", cleaned)
    if match:
        return f"Chương {int(match.group(1))} - {match.group(2).strip()}"
    if not cleaned or cleaned.casefold() in {"images", "pages", "img", "comic"}:
        return f"Chương {index}"
    return f"Chương {index} - {cleaned}"


def chapter_media_paths(chapter: ChapterSource, work_dir: Path, index: int) -> list[Path]:
    if chapter.kind == "flat":
        return list(chapter.files or [])
    if chapter.kind == "pdf":
        return [chapter.path] if chapter.path else []
    if chapter.kind == "directory":
        return all_media_files(chapter.path) if chapter.path else []
    if chapter.kind == "archive":
        if chapter.path is None:
            return []
        destination = work_dir / "chapter_archives" / f"chapter_{index:03d}"
        safe_extract_zip(chapter.path, destination)
        return all_media_files(destination)
    return []


def save_image_as_jpeg(source: Path, destination: Path) -> None:
    try:
        with Image.open(source) as image:
            image = ImageOps.exif_transpose(image)
            if getattr(image, "is_animated", False):
                image.seek(0)
            if image.mode in ("RGBA", "LA") or (image.mode == "P" and "transparency" in image.info):
                image = image.convert("RGBA")
                background = Image.new("RGB", image.size, "white")
                background.paste(image, mask=image.getchannel("A"))
                image = background
            else:
                image = image.convert("RGB")
            image.thumbnail((MAX_IMAGE_EDGE, MAX_IMAGE_EDGE), Image.Resampling.LANCZOS)
            destination.parent.mkdir(parents=True, exist_ok=True)
            image.save(destination, format="JPEG", quality=91, optimize=True, progressive=True)
    except Exception as exc:
        raise ValueError(f"Không đọc được ảnh '{source}': {exc}") from exc


def render_pdf_to_jpegs(source: Path, output_dir: Path) -> list[Path]:
    output_dir.mkdir(parents=True, exist_ok=True)
    produced: list[Path] = []
    try:
        with fitz.open(source) as document:
            if document.is_encrypted:
                raise ValueError(f"PDF có mật khẩu, chưa thể nhập: {source.name}")
            if document.page_count == 0:
                raise ValueError(f"PDF không có trang: {source.name}")
            for page_index, page in enumerate(document, start=1):
                pixmap = page.get_pixmap(matrix=fitz.Matrix(PDF_SCALE, PDF_SCALE), alpha=False)
                image = Image.frombytes("RGB", (pixmap.width, pixmap.height), pixmap.samples)
                image.thumbnail((MAX_IMAGE_EDGE, MAX_IMAGE_EDGE), Image.Resampling.LANCZOS)
                output = output_dir / f"{source.stem}_pdfpage_{page_index:05d}.jpg"
                image.save(output, format="JPEG", quality=91, optimize=True, progressive=True)
                produced.append(output)
    except ValueError:
        raise
    except Exception as exc:
        raise ValueError(f"Không chuyển đổi được PDF '{source}': {exc}") from exc
    return produced


def prepare_chapter_pages(chapter: ChapterSource, index: int, work_dir: Path) -> list[Path]:
    files = chapter_media_paths(chapter, work_dir, index)
    if not files:
        raise ValueError(f"Không tìm thấy ảnh/PDF trong chương '{chapter.name}'.")
    prepared_dir = work_dir / "prepared" / f"chapter_{index:03d}"
    prepared_dir.mkdir(parents=True, exist_ok=True)
    outputs: list[tuple[list[object], int, Path]] = []
    for file_index, source_file in enumerate(files, start=1):
        suffix = source_file.suffix.lower()
        if suffix in IMAGE_EXTS:
            temp_image = prepared_dir / f"source_{file_index:06d}.jpg"
            save_image_as_jpeg(source_file, temp_image)
            outputs.append((natural_key(source_file.name), file_index, temp_image))
        elif suffix in PDF_EXTS:
            rendered = render_pdf_to_jpegs(source_file, prepared_dir / f"pdf_{file_index:06d}")
            for page_number, page_path in enumerate(rendered, start=1):
                outputs.append((natural_key(source_file.name), file_index * 100000 + page_number, page_path))
    outputs.sort(key=lambda item: (item[0], item[1]))
    page_files = [item[2] for item in outputs]
    if not page_files:
        raise ValueError(f"Không tạo được trang ảnh cho chương '{chapter.name}'.")
    return page_files


def prompt_value(label: str, default: str = "") -> str:
    suffix = f" [{default}]" if default else ""
    value = input(f"{label}{suffix}: ").strip()
    return value if value else default


def collect_metadata(args, source: Path, root: Path | None) -> dict:
    default_title = args.title or (root.name if root else source.stem)
    print("\n--- Thông tin truyện ---")
    title = args.title or prompt_value("Tên truyện", default_title)
    author = args.author or prompt_value("Tác giả", "Đang cập nhật")
    description = args.description if args.description is not None else prompt_value("Mô tả (có thể để trống)", "")
    tags_raw = args.tags if args.tags is not None else prompt_value("Thể loại, cách nhau bằng dấu phẩy", "Hành động, Phiêu lưu")
    tags = list(dict.fromkeys(tag.strip() for tag in tags_raw.split(",") if tag.strip()))
    status = args.status or prompt_value("Trạng thái", "Đang tiến hành")
    # Keep stored URLs relative: Flutter resolves them against COMIC_API_URL's host,
    # so imported images work on both Android Emulator and a real phone.
    owner_text = getattr(args, "owner_user_id", None)
    if owner_text is None:
        owner_text = prompt_value("ID tài khoản chủ sở hữu (bắt buộc; dùng ID Admin nếu nhập kho quản trị)", "")
    owner_text = str(owner_text).strip()
    if not owner_text:
        raise ValueError("Bắt buộc gán chủ sở hữu truyện để phân quyền quản lý và truy vết nội dung. Nhập ID tài khoản AUTHOR hoặc ADMIN.")
    try:
        owner_id = int(owner_text)
    except ValueError as exc:
        raise ValueError("Owner user ID phải là số nguyên dương.") from exc
    if owner_id <= 0:
        raise ValueError("Owner user ID phải là số nguyên dương.")
    return {"title": title, "author": author, "description": description, "tags": tags, "status": status, "owner_user_id": owner_id}


def prompt_db_config(args) -> dict:
    print("\n--- Kết nối PostgreSQL ---")
    host = args.db_host or prompt_value("PostgreSQL host", os.getenv("COMIC_DB_HOST", "localhost"))
    port = args.db_port or int(prompt_value("PostgreSQL port", os.getenv("COMIC_DB_PORT", "5432")))
    dbname = args.db_name or prompt_value("Tên database", os.getenv("COMIC_DB_NAME", "comic_db"))
    user = args.db_user or prompt_value("Tên người dùng", os.getenv("COMIC_DB_USER", "postgres"))
    password = args.db_password or os.getenv("COMIC_DB_PASSWORD")
    if password is None:
        password = getpass.getpass("Mật khẩu PostgreSQL (không hiển thị): ")
    return {"host": host, "port": int(port), "dbname": dbname, "user": user, "password": password}


def insert_into_database(db_config: dict, metadata: dict, prepared_chapters: list[PreparedChapter], cover_url: str, chapter_page_urls: list[list[str]]) -> int:
    try:
        import psycopg
    except ImportError as exc:
        raise RuntimeError("Thiếu psycopg. Chạy: python -m pip install -r backend/tools/requirements-importer.txt") from exc

    # Context manager commits on successful exit and rolls back on failure.
    with psycopg.connect(**db_config, connect_timeout=8) as connection:
        with connection.cursor() as cursor:
            if metadata.get("owner_user_id") is None:
                raise ValueError("Bắt buộc gán chủ sở hữu truyện trước khi ghi vào PostgreSQL.")
            cursor.execute("SELECT role FROM users WHERE id = %s", (metadata["owner_user_id"],))
            owner_row = cursor.fetchone()
            if owner_row is None:
                raise ValueError(f"Không tìm thấy tài khoản chủ sở hữu ID={metadata['owner_user_id']}.")
            if str(owner_row[0]).upper() not in {"AUTHOR", "ADMIN"}:
                raise ValueError("Chỉ tài khoản AUTHOR hoặc ADMIN mới được gán làm chủ sở hữu truyện.")
            cursor.execute(
                """INSERT INTO comics (title, author, description, cover_url, status, created_by_user_id,
                                      moderation_status, age_rating, suggested_age_rating, created_at)
                   VALUES (%s, %s, %s, %s, %s, %s, 'APPROVED', 'ALL_AGES', 'ALL_AGES', NOW()) RETURNING id""",
                (metadata["title"], metadata["author"], metadata["description"], cover_url, metadata["status"], metadata["owner_user_id"]),
            )
            comic_id = int(cursor.fetchone()[0])
            for tag in metadata["tags"]:
                cursor.execute("INSERT INTO comic_tags (comic_id, tag) VALUES (%s, %s)", (comic_id, tag))
            for chapter in prepared_chapters:
                cursor.execute(
                    """INSERT INTO chapters (comic_id, chapter_number, title, is_vip, price,
                                               content_type, content_text, moderation_status,
                                               age_rating, suggested_age_rating, created_at)
                       VALUES (%s, %s, %s, FALSE, 0, 'IMAGE', NULL, 'PENDING', 'ALL_AGES', 'ALL_AGES', NOW()) RETURNING id""",
                    (comic_id, chapter.number, chapter.title),
                )
                chapter_id = int(cursor.fetchone()[0])
                for page_number, image_url in enumerate(chapter_page_urls[chapter.number - 1], start=1):
                    cursor.execute(
                        "INSERT INTO pages (chapter_id, page_number, image_url) VALUES (%s, %s, %s)",
                        (chapter_id, page_number, image_url),
                    )
        return comic_id


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Nhập truyện từ thư mục, ZIP/CBZ hoặc PDF vào Smart Story.")
    parser.add_argument("--source", help="Đường dẫn thư mục, file .zip/.cbz hoặc PDF. Bỏ trống để mở hộp thoại chọn.")
    parser.add_argument("--cover", help="Đường dẫn ảnh bìa riêng (tuỳ chọn).")
    parser.add_argument("--title", help="Tên truyện (bỏ trống để hỏi tương tác).")
    parser.add_argument("--author", help="Tên tác giả.")
    parser.add_argument("--description", help="Mô tả truyện.")
    parser.add_argument("--tags", help="Các thể loại, phân cách bằng dấu phẩy.")
    parser.add_argument("--status", help="Trạng thái, mặc định Đang tiến hành.")
    parser.add_argument("--owner-user-id", type=int, help="ID tài khoản chủ truyện (bắt buộc; tài khoản phải có vai trò AUTHOR hoặc ADMIN).")
    parser.add_argument("--db-host", help="PostgreSQL host.")
    parser.add_argument("--db-port", type=int, help="PostgreSQL port.")
    parser.add_argument("--db-name", help="PostgreSQL database.")
    parser.add_argument("--db-user", help="PostgreSQL user.")
    parser.add_argument("--db-password", help="PostgreSQL password (nên dùng COMIC_DB_PASSWORD thay vì truyền trực tiếp).")
    return parser


def main() -> int:
    args = build_arg_parser().parse_args()
    selected_source = Path(args.source).expanduser() if args.source else choose_source_gui()
    if selected_source is None:
        print("Đã huỷ. Không có dữ liệu nào được nhập.")
        return 0
    selected_source = selected_source.resolve()

    if not selected_source.exists():
        print(f"LỖI: Không tìm thấy: {selected_source}")
        return 2

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    final_folder: Path | None = None
    database_record_created = False
    try:
        with tempfile.TemporaryDirectory(prefix="smart_story_import_") as temp_name:
            work_dir = Path(temp_name)
            root, standalone_pdf = resolve_selected_source(selected_source, work_dir)
            if root is None and standalone_pdf is None:
                raise ValueError("Không xác định được nguồn truyện.")

            if standalone_pdf is not None:
                chapters = [ChapterSource(name=standalone_pdf.stem, kind="pdf", path=standalone_pdf)]
                detected_cover = None
            else:
                chapters, detected_cover = discover_chapters(root)
            if not chapters:
                raise ValueError("Không tìm thấy chương nào. Cần có ảnh/PDF ở thư mục gốc hoặc trong các thư mục chương.")

            if args.cover:
                cover_source = Path(args.cover).expanduser().resolve()
                if not cover_source.is_file() or not is_image(cover_source):
                    raise ValueError("--cover phải trỏ đến file ảnh tồn tại (JPG/PNG/WebP/BMP/GIF/TIFF).")
            else:
                cover_source = detected_cover
                if cover_source is None and root is not None:
                    # If there is no conventional cover filename, let the user choose one if desired.
                    candidate = choose_cover_gui(root)
                    if candidate and candidate.is_file() and is_image(candidate):
                        cover_source = candidate.resolve()

            # If a user selected one of the loose root images as the cover, keep it out of
            # the reading pages when other pages remain. Never remove the only page.
            if cover_source is not None and len(chapters) == 1 and chapters[0].kind == "flat":
                flat_images = list(chapters[0].files or [])
                remaining = [p for p in flat_images if p.resolve() != cover_source.resolve()]
                if remaining:
                    chapters[0].files = remaining

            print(f"\nTìm thấy {len(chapters)} chương/nhóm nội dung.")
            prepared_chapters: list[PreparedChapter] = []
            for index, chapter_source in enumerate(chapters, start=1):
                page_files = prepare_chapter_pages(chapter_source, index, work_dir)
                title = chapter_title(index, chapter_source.name)
                prepared_chapters.append(PreparedChapter(index, title, page_files))
                print(f"  {index:>3}. {title}: {len(page_files)} trang")

            if cover_source is None:
                # If no separate cover was selected, use the first page as cover; it remains in the chapter.
                cover_source = prepared_chapters[0].page_files[0]
                already_jpeg = True
            else:
                already_jpeg = False

            metadata = collect_metadata(args, selected_source, root)
            db_config = prompt_db_config(args)

            folder_slug = f"{safe_slug(metadata['title'])}-{timestamp}"
            final_folder = UPLOADS_DIR / "imported" / folder_slug
            if final_folder.exists():
                raise FileExistsError(f"Thư mục đích đã tồn tại: {final_folder}")
            final_folder.mkdir(parents=True, exist_ok=False)

            cover_path = final_folder / "cover.jpg"
            if already_jpeg:
                shutil.copy2(cover_source, cover_path)
            else:
                save_image_as_jpeg(cover_source, cover_path)
            cover_url = f"/uploads/imported/{folder_slug}/cover.jpg"

            page_urls: list[list[str]] = []
            for chapter in prepared_chapters:
                relative_chapter = f"chapter_{chapter.number:03d}"
                chapter_output = final_folder / relative_chapter
                chapter_output.mkdir(parents=True, exist_ok=True)
                urls: list[str] = []
                for page_number, prepared_file in enumerate(chapter.page_files, start=1):
                    output_file = chapter_output / f"page_{page_number:04d}.jpg"
                    shutil.copy2(prepared_file, output_file)
                    urls.append(f"/uploads/imported/{folder_slug}/{relative_chapter}/{output_file.name}")
                page_urls.append(urls)

            manifest = {
                "title": metadata["title"],
                "author": metadata["author"],
                "source_name": selected_source.name,
                "imported_at": datetime.now().isoformat(timespec="seconds"),
                "cover_url": cover_url,
                "chapter_count": len(prepared_chapters),
                "chapters": [{"number": chapter.number, "title": chapter.title, "page_count": len(chapter.page_files)} for chapter in prepared_chapters],
                "note": "Chỉ dùng nội dung mà bạn có quyền sử dụng hoặc phân phối.",
            }
            (final_folder / "import_manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2), encoding="utf-8")

            try:
                comic_id = insert_into_database(db_config, metadata, prepared_chapters, cover_url, page_urls)
                database_record_created = True
            except Exception:
                # Remove only the new, uniquely named upload folder if database creation fails.
                shutil.rmtree(final_folder, ignore_errors=True)
                final_folder = None
                raise

            print("\nNHẬP TRUYỆN THÀNH CÔNG")
            print(f"  ID truyện: {comic_id}")
            print(f"  Chủ sở hữu user ID: {metadata['owner_user_id'] if metadata['owner_user_id'] is not None else 'chưa gán'}")
            print("  Trạng thái kiểm duyệt: PENDING (cần Moderator/Admin duyệt trước khi công khai)")
            print(f"  Tên truyện: {metadata['title']}")
            print(f"  Số chương: {len(prepared_chapters)}")
            print(f"  Tổng số trang: {sum(len(ch.page_files) for ch in prepared_chapters)}")
            print(f"  Ảnh đã lưu: {final_folder}")
            print(f"  Đường dẫn ảnh bìa: {cover_url}")
            print("  API kiểm tra: http://localhost:8080/api/comics")
            print("  URL ảnh được lưu dạng tương đối để Flutter tự ghép host từ COMIC_API_URL.")
            print("\nLưu ý: chạy lại importer sẽ tạo một truyện mới, không ghi đè truyện cũ.")
            return 0
    except KeyboardInterrupt:
        print("\nĐã huỷ bằng bàn phím.")
        if final_folder:
            shutil.rmtree(final_folder, ignore_errors=True)
        return 130
    except Exception as exc:
        if final_folder and not database_record_created:
            shutil.rmtree(final_folder, ignore_errors=True)
        print(f"\nLỖI: {exc}")
        print("Kiểm tra hướng dẫn backend/tools/README_IMPORTER.md để xử lý.")
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
