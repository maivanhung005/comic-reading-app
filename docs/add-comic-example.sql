-- Chạy trong pgAdmin > database comic_db > Query Tool.
-- Ví dụ đầy đủ tạo một truyện, tag, một chương và hai trang minh họa.
-- Thay tiêu đề/tác giả/URL ảnh bằng dữ liệu mà bạn có quyền sử dụng.
DO $$
DECLARE
    new_comic_id BIGINT;
    new_chapter_id BIGINT;
BEGIN
    INSERT INTO comics (title, author, description, cover_url, status, created_at)
    VALUES (
        'Truyện thử nghiệm',
        'Tác giả mẫu',
        'Mô tả truyện mẫu',
        'https://picsum.photos/seed/comic-new/400/600',
        'Đang tiến hành',
        NOW()
    )
    RETURNING id INTO new_comic_id;

    INSERT INTO comic_tags (comic_id, tag)
    VALUES (new_comic_id, 'Phiêu lưu'), (new_comic_id, 'Hành động');

    INSERT INTO chapters (comic_id, chapter_number, title, is_vip, price, created_at)
    VALUES (new_comic_id, 1, 'Chương mở đầu', FALSE, 0, NOW())
    RETURNING id INTO new_chapter_id;

    INSERT INTO pages (chapter_id, page_number, image_url)
    VALUES
        (new_chapter_id, 1, 'https://picsum.photos/seed/comic-page-1/700/1000'),
        (new_chapter_id, 2, 'https://picsum.photos/seed/comic-page-2/700/1000');
END $$;
