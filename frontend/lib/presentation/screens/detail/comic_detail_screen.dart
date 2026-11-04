import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/comic_entity.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../../data/datasources/remote/remote_data_source.dart';
import '../../viewmodels/payment_viewmodel.dart';
import '../../viewmodels/profile_offline_viewmodel.dart';
import '../payment/payment_screen.dart';
import '../reader/reader_screen.dart';
import '../../widgets/secure_media_headers.dart';
import 'comic_community_section.dart';

class ComicDetailScreen extends StatefulWidget {
  final ComicEntity comic;
  final int userId;
  const ComicDetailScreen({super.key, required this.comic, required this.userId});
  @override
  State<ComicDetailScreen> createState() => _ComicDetailScreenState();
}

class _ComicDetailScreenState extends State<ComicDetailScreen> {
  late Future<ComicEntity> _detailFuture;
  @override
  void initState() { super.initState(); _detailFuture = context.read<HomeViewModel>().loadComicDetail(widget.comic.id); }

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileOfflineViewModel>();
    final fav = profile.isFavorite(widget.comic.id);
    return Scaffold(
      appBar: AppBar(title: const Text('Chi tiết truyện'), actions: [IconButton(tooltip: 'Báo cáo truyện', icon: const Icon(Icons.flag_outlined), onPressed: () => _reportComic(context)), IconButton(onPressed: () => profile.toggleFavorite(widget.userId, widget.comic.id), icon: Icon(fav ? Icons.favorite : Icons.favorite_border, color: fav ? Colors.red : null), tooltip: 'Yêu thích')]),
      body: FutureBuilder<ComicEntity>(
        future: _detailFuture,
        builder: (context, snapshot) {
          final comic = snapshot.data ?? widget.comic;
          if (snapshot.connectionState == ConnectionState.waiting && comic.chapters.isEmpty) return const Center(child: CircularProgressIndicator());
          if (snapshot.hasError && comic.chapters.isEmpty) return Center(child: Padding(padding: const EdgeInsets.all(24), child: Text('Không tải được chi tiết truyện. Hãy kiểm tra kết nối máy chủ.\n${snapshot.error}')));
          return ListView(padding: const EdgeInsets.all(16), children: [
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              ClipRRect(borderRadius: BorderRadius.circular(12), child: SizedBox(width: 132, height: 190, child: comic.coverUrl.isEmpty ? const ColoredBox(color: Colors.black12, child: Icon(Icons.menu_book)) : CachedNetworkImage(imageUrl: comic.coverUrl, httpHeaders: secureMediaHeaders(context, comic.coverUrl), fit: BoxFit.cover, errorWidget: (_, __, ___) => const Icon(Icons.broken_image)))),
              const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(comic.title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: Text('Tác giả: ${comic.author}')),
                  if (comic.author.trim().isNotEmpty)
                    TextButton.icon(
                      onPressed: () async {
                        final wasFollowing = profile.isFollowingAuthor(comic.author);
                        await profile.toggleFollowAuthor(widget.userId, comic.author);
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(wasFollowing ? 'Đã bỏ theo dõi ${comic.author}.' : 'Đang theo dõi ${comic.author}.')));
                        }
                      },
                      icon: Icon(profile.isFollowingAuthor(comic.author) ? Icons.person_remove_alt_1_outlined : Icons.person_add_alt_1_outlined, size: 18),
                      label: Text(profile.isFollowingAuthor(comic.author) ? 'Đang theo dõi' : 'Theo dõi'),
                    ),
                ]),
                const SizedBox(height: 8), Text(comic.status),
                const SizedBox(height: 8), Wrap(spacing: 6, runSpacing: 6, children: comic.tags.map((tag) => Chip(label: Text(tag))).toList()),
              ])),
            ]),
            const SizedBox(height: 16), Text(comic.description), const Divider(height: 32),
            Text('Danh sách chương (${comic.chapters.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            if (comic.chapters.isEmpty) const Padding(padding: EdgeInsets.all(20), child: Text('Truyện này chưa có chương trong database.')),
            ...comic.chapters.map((chapter) => Card(child: ListTile(
              leading: Icon(chapter.isVip ? Icons.lock_outline : Icons.menu_book, color: chapter.isVip ? Colors.orange : Colors.green),
              title: Text('Chương ${chapter.chapterNumber}: ${chapter.title}'),
              subtitle: Text(chapter.isVip ? '${chapter.price} VNĐ · VIP' : 'Miễn phí'),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  tooltip: 'Tải chương để đọc offline',
                  icon: const Icon(Icons.download_for_offline_outlined),
                  onPressed: () async {
                    try {
                      await context.read<HomeViewModel>().downloadChapter(comic, chapter);
                      if (context.mounted) {
                        context.read<ProfileOfflineViewModel>().loadUserData(widget.userId);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã tải chương về thiết bị này.')));
                      }
                    } catch (e) {
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tải được chương: $e')));
                    }
                  },
                ),
                const Icon(Icons.chevron_right),
              ]),
              onTap: () async {
                final payment = context.read<PaymentViewModel>();
                await payment.loadUnlocked(widget.userId);
                var unlocked = payment.isUnlocked(chapter);
                if (!unlocked) {
                  final ok = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => PaymentScreen(comic: comic, chapter: chapter, userId: widget.userId)));
                  if (ok != true || !context.mounted) return;
                  unlocked = true;
                }
                if (unlocked && context.mounted) {
                  await Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(comic: comic, chapter: chapter, userId: widget.userId)));
                  if (context.mounted) context.read<ProfileOfflineViewModel>().loadUserData(widget.userId);
                }
              },
            ))),
            ComicCommunitySection(comicId: comic.id),
          ]);
        },
      ),
    );
  }

  Future<void> _reportComic(BuildContext context) async {
    String reason = 'COPYRIGHT';
    final description = TextEditingController();
    final selected = await showDialog<bool>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, setDialogState) => AlertDialog(title: const Text('Báo cáo truyện'), content: Column(mainAxisSize: MainAxisSize.min, children: [DropdownButtonFormField<String>(value: reason, decoration: const InputDecoration(labelText: 'Lý do'), items: const [DropdownMenuItem(value: 'COPYRIGHT', child: Text('Nghi vấn bản quyền')), DropdownMenuItem(value: 'AGE_RESTRICTION', child: Text('Sai phân loại độ tuổi')), DropdownMenuItem(value: 'INAPPROPRIATE', child: Text('Nội dung không phù hợp')), DropdownMenuItem(value: 'OTHER', child: Text('Khác'))], onChanged: (v) => setDialogState(() => reason = v ?? 'OTHER')), const SizedBox(height: 12), TextField(controller: description, maxLines: 3, decoration: const InputDecoration(labelText: 'Mô tả / căn cứ', border: OutlineInputBorder()))]), actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Huỷ')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Gửi báo cáo'))])));
    if (selected == true && context.mounted) {
      try { await context.read<RemoteDataSource>().reportComic(comicId: widget.comic.id, reasonCode: reason, description: description.text.trim()); if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi báo cáo tới đội ngũ kiểm duyệt.'))); }
      catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không gửi được báo cáo: $e'))); }
    }
    description.dispose();
  }
}
