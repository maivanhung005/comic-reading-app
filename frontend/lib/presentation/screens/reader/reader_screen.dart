import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/comic_entity.dart';
import '../../viewmodels/reader_viewmodel.dart';
import '../../widgets/secure_media_headers.dart';

class ReaderScreen extends StatefulWidget {
  final ComicEntity comic;
  final ChapterEntity chapter;
  final int userId;
  const ReaderScreen({super.key, required this.comic, required this.chapter, required this.userId});
  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.read<ReaderViewModel>().loadChapter(widget.comic, widget.chapter, widget.userId);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ReaderViewModel>();
    final chapter = vm.chapter;
    final pages = chapter?.pages ?? const <PageEntity>[];
    final isText = chapter?.contentType.toUpperCase() == 'TEXT';
    final title = 'Chương ${chapter?.chapterNumber ?? widget.chapter.chapterNumber}';

    return Scaffold(
      backgroundColor: isText ? Theme.of(context).colorScheme.surface : Colors.black,
      appBar: AppBar(
        backgroundColor: isText ? null : Colors.black,
        foregroundColor: isText ? null : Colors.white,
        title: Text(isText ? '$title · Truyện chữ' : '$title · ${pages.isEmpty ? 0 : vm.currentPage + 1}/${pages.length}'),
        actions: [
          PopupMenuButton<double>(
            icon: const Icon(Icons.speed),
            onSelected: vm.changeSpeed,
            itemBuilder: (_) => [0.5, 1.0, 1.5, 2.0].map((s) => PopupMenuItem(value: s, child: Text('Tốc độ ${s}x'))).toList(),
          ),
          if (!isText)
            IconButton(
              tooltip: 'Đổi kiểu đọc',
              icon: Icon(vm.verticalMode ? Icons.swap_horiz : Icons.swap_vert),
              onPressed: () => vm.toggleReadingMode(!vm.verticalMode),
            ),
        ],
      ),
      body: vm.isLoading
          ? const Center(child: CircularProgressIndicator())
          : vm.error != null
              ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Text(vm.error!, textAlign: TextAlign.center, style: TextStyle(color: isText ? null : Colors.white))))
              : isText
                  ? Column(children: [
                      Expanded(
                        child: Scrollbar(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.fromLTRB(22, 20, 22, 24),
                            child: SelectableText(
                              chapter?.contentText ?? '',
                              style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 17, height: 1.75),
                            ),
                          ),
                        ),
                      ),
                      SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                          child: Row(children: [
                            Expanded(child: Text(chapter?.title ?? '', maxLines: 1, overflow: TextOverflow.ellipsis)),
                            IconButton.filledTonal(
                              tooltip: vm.isSpeaking ? 'Dừng đọc' : 'Đọc văn bản thành tiếng',
                              onPressed: vm.toggleSpeak,
                              icon: Icon(vm.isSpeaking ? Icons.stop : Icons.volume_up),
                            ),
                          ]),
                        ),
                      ),
                    ])
                  : pages.isEmpty
                      ? const Center(child: Text('Chương này chưa có trang ảnh.', style: TextStyle(color: Colors.white)))
                      : Stack(children: [
                          vm.verticalMode
                              ? ListView.builder(
                                  itemCount: pages.length,
                                  itemBuilder: (_, i) => CachedNetworkImage(
                                    imageUrl: pages[i].imageUrl,
                                    httpHeaders: secureMediaHeaders(context, pages[i].imageUrl),
                                    fit: BoxFit.fitWidth,
                                    placeholder: (_, __) => const SizedBox(height: 240, child: Center(child: CircularProgressIndicator())),
                                    errorWidget: (_, __, ___) => const SizedBox(height: 240, child: Icon(Icons.broken_image, color: Colors.white)),
                                  ),
                                )
                              : PageView.builder(
                                  itemCount: pages.length,
                                  onPageChanged: vm.setPage,
                                  itemBuilder: (_, i) => PhotoView(
                                    imageProvider: CachedNetworkImageProvider(pages[i].imageUrl, headers: secureMediaHeaders(context, pages[i].imageUrl)),
                                    backgroundDecoration: const BoxDecoration(color: Colors.black),
                                    loadingBuilder: (_, __) => const Center(child: CircularProgressIndicator()),
                                  ),
                                ),
                          Positioned(left: 12, right: 12, top: 12, child: IgnorePointer(child: Container(height: 3, color: Colors.white24, child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: vm.brightness, child: const ColoredBox(color: Colors.amber))))),
                          Positioned(left: 8, bottom: 12, right: 8, child: Row(children: [
                            const Icon(Icons.brightness_6, color: Colors.white),
                            Expanded(child: Slider(value: vm.brightness, min: 0.35, max: 1, onChanged: vm.setBrightness)),
                            FloatingActionButton.small(heroTag: 'tts', onPressed: vm.toggleSpeak, child: Icon(vm.isSpeaking ? Icons.stop : Icons.volume_up)),
                          ])),
                        ]),
    );
  }
}
