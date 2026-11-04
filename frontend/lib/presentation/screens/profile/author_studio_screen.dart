import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/remote/remote_data_source.dart';
import '../../../core/errors/api_exception.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'author_feedback_read_state.dart';
import 'author_comic_feedback_screen.dart';

String _value(dynamic value, [String fallback = '']) => value == null ? fallback : value.toString();

String _storedUploadPath(dynamic value) {
  final raw = _value(value);
  if (raw.startsWith('/uploads/')) return raw;
  final uri = Uri.tryParse(raw);
  if (uri != null && uri.path.startsWith('/uploads/')) return uri.path;
  return raw;
}


int _naturalFileCompare(String left, String right) {
  final a = left.toLowerCase();
  final b = right.toLowerCase();
  final partsA = RegExp(r'\d+|\D+').allMatches(a).map((m) => m.group(0)!).toList();
  final partsB = RegExp(r'\d+|\D+').allMatches(b).map((m) => m.group(0)!).toList();
  for (var i = 0; i < partsA.length && i < partsB.length; i++) {
    final pa = partsA[i];
    final pb = partsB[i];
    final na = int.tryParse(pa);
    final nb = int.tryParse(pb);
    final cmp = na != null && nb != null ? na.compareTo(nb) : pa.compareTo(pb);
    if (cmp != 0) return cmp;
  }
  return partsA.length.compareTo(partsB.length);
}

/// Server-backed author workspace. Reading remains available in the main app;
/// this screen adds author tools without replacing the Reader experience.
class AuthorStudioScreen extends StatefulWidget {
  const AuthorStudioScreen({super.key});

  @override
  State<AuthorStudioScreen> createState() => _AuthorStudioScreenState();
}

class _AuthorStudioScreenState extends State<AuthorStudioScreen> {
  List<Map<String, dynamic>> _comics = [];
  bool _loading = true;
  String? _error;
  bool _sessionExpired = false;
  Map<int, Map<String, dynamic>> _comicStats = {};
  Set<int> _unreadFeedbackComicIds = <int>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; _sessionExpired = false; });
    try {
      final api = context.read<RemoteDataSource>();
      final rows = await api.getAuthorComics();
      Map<int, Map<String, dynamic>> statsByComic = {};
      final unread = <int>{};
      final userId = context.read<AuthViewModel>().currentUser?.id;
      try {
        final dashboard = await api.getAuthorDashboard();
        final stats = (dashboard['comicStatistics'] as List? ?? const []).map((row) => Map<String, dynamic>.from(row as Map)).toList();
        for (final item in stats) {
          final id = int.tryParse(_value(item['comicId']));
          if (id == null) continue;
          statsByComic[id] = item;
          if (userId != null && await AuthorFeedbackReadState.hasUnread(userId, id, item)) unread.add(id);
        }
      } catch (_) {
        // Keep the comic list available even if the optional feedback summary fails.
      }
      if (!mounted) return;
      setState(() { _comics = rows; _comicStats = statsByComic; _unreadFeedbackComicIds = unread; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      final unauthorized = e is ApiException && e.statusCode == 401;
      setState(() {
        _sessionExpired = unauthorized;
        _error = unauthorized
            ? 'Phiên đăng nhập đã hết hạn hoặc không còn hợp lệ. Hãy đăng nhập lại để tiếp tục.'
            : e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _relogin() async {
    await context.read<AuthViewModel>().logout();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _openEditor([Map<String, dynamic>? comic]) async {
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AuthorComicEditorScreen(comic: comic)));
    if (changed == true && mounted) {
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(comic == null
              ? 'Đã tạo thông tin truyện. Bạn có thể nhập chương; từng chương sẽ được kiểm duyệt riêng.'
              : 'Đã cập nhật thông tin truyện. Nội dung chương không bị gửi duyệt lại.'),
        ));
      }
    }
  }

  Future<void> _openComic(Map<String, dynamic> comic) async {
    final id = int.tryParse(_value(comic['id']));
    if (id == null) return;
    await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AuthorComicManagerScreen(comicId: id, fallbackTitle: _value(comic['title'], 'Truyện'))));
    await _load();
  }

  Future<void> _hideComic(Map<String, dynamic> comic) async {
    final id = int.tryParse(_value(comic['id']));
    if (id == null) return;
    final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Ẩn truyện này?'),
      content: const Text('Truyện chưa có chương được duyệt sẽ được ẩn khỏi danh sách công khai. Nếu truyện đã có chương công khai, hãy gửi yêu cầu gỡ tới đội ngũ kiểm duyệt.'),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Ẩn truyện'))],
    ));
    if (confirmed != true) return;
    try {
      await context.read<RemoteDataSource>().deleteAuthorComic(id);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi thao tác ẩn truyện.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể ẩn truyện: $e')));
    }
  }

  String _moderationLabel(dynamic value) {
    switch ('$value'.toUpperCase()) {
      case 'APPROVED': return 'Đã duyệt';
      case 'PENDING': return 'Chờ kiểm duyệt';
      case 'REJECTED': return 'Bị từ chối';
      case 'HIDDEN': return 'Đang ẩn';
      default: return 'Chưa xác định';
    }
  }

  Color _moderationColor(BuildContext context, dynamic value) {
    switch ('$value'.toUpperCase()) {
      case 'APPROVED': return Colors.green;
      case 'REJECTED': return Theme.of(context).colorScheme.error;
      case 'HIDDEN': return Colors.grey;
      default: return Colors.orange.shade800;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Studio tác giả'), actions: [IconButton(tooltip: 'Làm mới', onPressed: _load, icon: const Icon(Icons.refresh))]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _openEditor(), icon: const Icon(Icons.add), label: const Text('Tạo truyện')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 100), children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xff35205e), Color(0xff8154ba)]), borderRadius: BorderRadius.circular(20)),
            child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.draw_outlined, color: Colors.white, size: 32),
              SizedBox(height: 10),
              Text('Không gian sáng tác của bạn', style: TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.bold)),
              SizedBox(height: 6),
              Text('Bạn vẫn có thể đọc truyện, lưu thư viện và theo dõi tác giả như Reader. Studio là nơi quản lý các tác phẩm của riêng bạn.', style: TextStyle(color: Colors.white70, height: 1.4)),
            ]),
          ),
          const SizedBox(height: 20),
          Row(children: [Expanded(child: Text('Truyện của tôi (${_comics.length})', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold))), TextButton.icon(onPressed: () => _openEditor(), icon: const Icon(Icons.add), label: const Text('Thêm mới'))]),
          if (_loading) const Padding(padding: EdgeInsets.all(28), child: Center(child: CircularProgressIndicator())),
          if (!_loading && _error != null) Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Icon(_sessionExpired ? Icons.lock_outline : Icons.cloud_off, size: 38), const SizedBox(height: 8), Text(_sessionExpired ? _error! : 'Không tải được truyện: $_error', textAlign: TextAlign.center), const SizedBox(height: 8), if (_sessionExpired) FilledButton.icon(onPressed: _relogin, icon: const Icon(Icons.login), label: const Text('Đăng nhập lại')) else OutlinedButton.icon(onPressed: _load, icon: const Icon(Icons.refresh), label: const Text('Thử lại'))]))),
          if (!_loading && _error == null && _comics.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(22), child: Column(children: [Icon(Icons.menu_book_outlined, size: 40), SizedBox(height: 8), Text('Bạn chưa có truyện nào', style: TextStyle(fontWeight: FontWeight.bold)), SizedBox(height: 4), Text('Tạo thông tin truyện trước, sau đó thêm chương. Từng chương sẽ được duyệt riêng trước khi công khai.', textAlign: TextAlign.center)]))),
          ..._comics.map((comic) {
            final tags = (comic['tags'] as List? ?? const []).map((t) => '$t').join(' · ');
            final comicId = int.tryParse(_value(comic['id'])) ?? -1;
            final stats = _comicStats[comicId] ?? const <String, dynamic>{};
            final rating = double.tryParse('${stats['averageRating'] ?? 0}') ?? 0.0;
            final reviewCount = int.tryParse('${stats['reviewCount'] ?? 0}') ?? 0;
            final hasUnreadFeedback = _unreadFeedbackComicIds.contains(comicId);
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                leading: Stack(clipBehavior: Clip.none, children: [Container(width: 48, height: 58, decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(8)), child: const Icon(Icons.auto_stories_outlined)), if (hasUnreadFeedback) Positioned(right: -3, top: -3, child: Container(width: 11, height: 11, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5))))]),
                title: Text(_value(comic['title'], 'Không tên'), maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Padding(padding: const EdgeInsets.only(top: 5), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (tags.isNotEmpty) Text(tags, maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 5), Wrap(spacing: 6, runSpacing: 4, crossAxisAlignment: WrapCrossAlignment.center, children: [Chip(label: const Text('Thông tin đã lưu'), visualDensity: VisualDensity.compact, side: BorderSide.none, backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest, labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 11)), if (reviewCount > 0) Row(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.star, size: 14, color: Colors.amber), const SizedBox(width: 2), Text('${rating.toStringAsFixed(1)} ($reviewCount)', style: Theme.of(context).textTheme.bodySmall)]), Text('Độ tuổi đề xuất: ' + _value(comic['suggestedAgeRating'], 'ALL_AGES'), style: Theme.of(context).textTheme.bodySmall)])])),
                isThreeLine: true,
                onTap: () => _openComic(comic),
                trailing: PopupMenuButton<String>(
                  tooltip: 'Tùy chọn truyện',
                  onSelected: (v) { if (v == 'edit') _openEditor(comic); else if (v == 'manage') _openComic(comic); else if (v == 'hide') _hideComic(comic); },
                  itemBuilder: (_) => [
                    const PopupMenuItem(value: 'edit', child: Text('Chỉnh sửa thông tin')),
                    const PopupMenuItem(value: 'manage', child: Text('Quản lý chương')),
                    const PopupMenuItem(value: 'hide', child: Text('Ẩn truyện')),
                  ],
                ),
              ),
            );
          }),
          const SizedBox(height: 12),
          const Text('Thông tin truyện và ảnh bìa không cần duyệt. Mỗi chương mới hoặc nội dung chương đã sửa sẽ chờ kiểm duyệt. Bạn chỉ quản lý truyện thuộc quyền sở hữu của mình.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ]),
      ),
    );
  }
}

class AuthorComicEditorScreen extends StatefulWidget {
  final Map<String, dynamic>? comic;
  const AuthorComicEditorScreen({super.key, this.comic});

  @override
  State<AuthorComicEditorScreen> createState() => _AuthorComicEditorScreenState();
}

class _AuthorComicEditorScreenState extends State<AuthorComicEditorScreen> {
  late final TextEditingController _title;
  late final TextEditingController _penName;
  late final TextEditingController _description;
  late final TextEditingController _tags;
  PlatformFile? _coverFile;
  String _suggestedAgeRating = 'ALL_AGES';
  bool _saving = false;

  bool get _editing => widget.comic != null;

  @override
  void initState() {
    super.initState();
    final row = widget.comic ?? const <String, dynamic>{};
    _title = TextEditingController(text: _value(row['title']));
    _penName = TextEditingController(text: _value(row['author']));
    _description = TextEditingController(text: _value(row['description']));
    _tags = TextEditingController(text: (row['tags'] as List? ?? const []).map((t) => '$t').join(', '));
    _suggestedAgeRating = _value(row['suggestedAgeRating'], 'ALL_AGES');
  }

  @override
  void dispose() {
    _title.dispose(); _penName.dispose(); _description.dispose(); _tags.dispose(); super.dispose();
  }

  Future<void> _chooseCover() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'gif'], withData: true, allowMultiple: false);
    if (result == null || result.files.isEmpty) return;
    final picked = result.files.single;
    if (picked.bytes == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không đọc được dữ liệu ảnh. Hãy chọn lại file.')));
      return;
    }
    if (mounted) setState(() => _coverFile = picked);
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty || _penName.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tên truyện và bút danh là bắt buộc.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final api = context.read<RemoteDataSource>();
      var coverUrl = _storedUploadPath(widget.comic?['coverUrl']);
      if (_coverFile != null) {
        final response = await api.uploadCoverBytes(bytes: _coverFile!.bytes!, filename: _coverFile!.name);
        coverUrl = _storedUploadPath(response['url']);
      }
      final tags = _tags.text.split(',').map((tag) => tag.trim()).where((tag) => tag.isNotEmpty).toSet().toList();
      final title = _title.text.trim();
      final penName = _penName.text.trim();
      final description = _description.text.trim();
      if (_editing) {
        await api.updateAuthorComic(comicId: int.parse(_value(widget.comic!['id'])), title: title, author: penName, description: description, coverUrl: coverUrl, tags: tags, suggestedAgeRating: _suggestedAgeRating);
      } else {
        await api.createAuthorComic(title: title, author: penName, description: description, coverUrl: coverUrl, tags: tags, suggestedAgeRating: _suggestedAgeRating);
      }
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được truyện: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_editing ? 'Chỉnh sửa truyện' : 'Tạo truyện mới')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      TextField(controller: _title, maxLength: 180, decoration: const InputDecoration(labelText: 'Tên truyện *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.title))),
      const SizedBox(height: 12),
      TextField(controller: _penName, maxLength: 180, decoration: const InputDecoration(labelText: 'Bút danh *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.draw_outlined))),
      const SizedBox(height: 12),
      TextField(controller: _description, maxLines: 4, maxLength: 5000, decoration: const InputDecoration(labelText: 'Mô tả', alignLabelWithHint: true, border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _tags, decoration: const InputDecoration(labelText: 'Thể loại', hintText: 'Hành động, Fantasy, Học đường', border: OutlineInputBorder(), prefixIcon: Icon(Icons.sell_outlined))),
      const SizedBox(height: 16),
      DropdownButtonFormField<String>(value: _suggestedAgeRating, decoration: const InputDecoration(labelText: 'Độ tuổi đề xuất', helperText: 'Đây là đề xuất của tác giả; người kiểm duyệt sẽ quyết định theo từng chương.', border: OutlineInputBorder(), prefixIcon: Icon(Icons.family_restroom_outlined)), items: const [DropdownMenuItem(value: 'ALL_AGES', child: Text('Mọi lứa tuổi')), DropdownMenuItem(value: '13+', child: Text('13+')), DropdownMenuItem(value: '16+', child: Text('16+')), DropdownMenuItem(value: '18+', child: Text('18+'))], onChanged: _saving ? null : (v) => setState(() => _suggestedAgeRating = v ?? 'ALL_AGES')),
      const SizedBox(height: 16),
      OutlinedButton.icon(onPressed: _saving ? null : _chooseCover, icon: const Icon(Icons.image_outlined), label: Text(_coverFile == null ? (_editing && _value(widget.comic?['coverUrl']).isNotEmpty ? 'Đổi ảnh bìa (tùy chọn)' : 'Chọn ảnh bìa (tùy chọn)') : 'Ảnh bìa: ${_coverFile!.name}')),
      const SizedBox(height: 18),
      FilledButton.icon(onPressed: _saving ? null : _save, icon: _saving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.save_outlined), label: Text(_saving ? 'Đang lưu...' : 'Lưu thông tin truyện')),
      const SizedBox(height: 10),
      const Text('Thông tin truyện và ảnh bìa không cần duyệt. Mỗi chương mới hoặc chương vừa sửa sẽ chờ Moderator/Admin đọc nội dung và quyết định giới hạn tuổi.', style: TextStyle(color: Colors.grey)),
    ]),
  );
}

class AuthorComicManagerScreen extends StatefulWidget {
  final int comicId;
  final String fallbackTitle;
  const AuthorComicManagerScreen({super.key, required this.comicId, required this.fallbackTitle});

  @override
  State<AuthorComicManagerScreen> createState() => _AuthorComicManagerScreenState();
}

class _AuthorComicManagerScreenState extends State<AuthorComicManagerScreen> {
  // This helper belongs to the comic manager state as well; state methods are
  // not visible across separate State classes.
  String _moderationLabel(dynamic value) {
    switch ('$value'.toUpperCase()) {
      case 'APPROVED': return 'Đã duyệt';
      case 'PENDING': return 'Chờ kiểm duyệt';
      case 'REJECTED': return 'Bị từ chối';
      case 'HIDDEN': return 'Đang ẩn';
      default: return 'Chưa xác định';
    }
  }

  Map<String, dynamic>? _comic;
  List<Map<String, dynamic>> _chapters = [];
  Map<String, dynamic> _feedbackSummary = {};
  bool _hasUnreadFeedback = false;
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<RemoteDataSource>();
      final data = await api.getAuthorComicDetail(widget.comicId);
      Map<String, dynamic> feedback = {};
      try { feedback = await api.getAuthorComicFeedback(widget.comicId); } catch (_) {}
      final userId = context.read<AuthViewModel>().currentUser?.id;
      final unread = userId != null && feedback.isNotEmpty
          ? await AuthorFeedbackReadState.hasUnread(userId, widget.comicId, feedback)
          : false;
      if (!mounted) return;
      setState(() {
        _comic = Map<String, dynamic>.from(data['comic'] as Map? ?? const {});
        _chapters = (data['chapters'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _feedbackSummary = feedback;
        _hasUnreadFeedback = unread;
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _openFeedback() async {
    await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => AuthorComicFeedbackScreen(comicId: widget.comicId, comicTitle: _value(_comic?['title'], widget.fallbackTitle))));
    if (mounted) await _load();
  }

  Future<void> _addChapter() async {
    final number = TextEditingController(text: '${_chapters.length + 1}');
    final title = TextEditingController();
    final textContent = TextEditingController();
    String contentType = 'IMAGE';
    String proposedAge = _value(_comic?['suggestedAgeRating'], 'ALL_AGES');
    final form = await showDialog<Map<String, dynamic>>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, updateDialog) => AlertDialog(
      title: const Text('Tạo chương'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: number, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số chương', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Tên chương *', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: contentType, decoration: const InputDecoration(labelText: 'Loại nội dung', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'IMAGE', child: Text('Truyện hình / trang ảnh')), DropdownMenuItem(value: 'TEXT', child: Text('Truyện chữ'))], onChanged: (v) => updateDialog(() => contentType = v ?? 'IMAGE')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: proposedAge, decoration: const InputDecoration(labelText: 'Độ tuổi đề xuất', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'ALL_AGES', child: Text('Mọi lứa tuổi')), DropdownMenuItem(value: '13+', child: Text('13+')), DropdownMenuItem(value: '16+', child: Text('16+')), DropdownMenuItem(value: '18+', child: Text('18+'))], onChanged: (v) => updateDialog(() => proposedAge = v ?? 'ALL_AGES')),
        if (contentType == 'TEXT') ...[
          const SizedBox(height: 10),
          TextField(controller: textContent, minLines: 5, maxLines: 10, maxLength: 500000, decoration: const InputDecoration(labelText: 'Nội dung chương *', alignLabelWithHint: true, border: OutlineInputBorder())),
        ] else ...[
          const SizedBox(height: 8),
          const Text('Sau khi tạo chương, bạn có thể tải nhiều trang ảnh hoặc nhập ZIP/CBZ/PDF.', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(dialogContext, {'number': int.tryParse(number.text.trim()), 'title': title.text.trim(), 'contentType': contentType, 'contentText': textContent.text.trim(), 'suggestedAgeRating': proposedAge}), child: const Text('Tạo chương'))],
    )));
    number.dispose(); title.dispose();
    if (form == null) { textContent.dispose(); return; }
    if (form['number'] == null || (form['number'] as int) < 1 || _value(form['title']).trim().isEmpty || (form['contentType'] == 'TEXT' && _value(form['contentText']).trim().isEmpty)) {
      textContent.dispose();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập số chương, tên chương hợp lệ và nội dung nếu là truyện chữ.')));
      return;
    }
    try {
      await context.read<RemoteDataSource>().createAuthorChapter(comicId: widget.comicId, chapterNumber: form['number'] as int, title: _value(form['title']), contentType: _value(form['contentType']), contentText: _value(form['contentText']), suggestedAgeRating: _value(form['suggestedAgeRating']));
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(form['contentType'] == 'TEXT' ? 'Đã tạo chương chữ và gửi kiểm duyệt.' : 'Đã tạo chương. Hãy tải nội dung để gửi kiểm duyệt.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tạo được chương: $e'))); }
    finally { textContent.dispose(); }
  }

  Future<void> _importChapters() async {
    final start = TextEditingController(text: '${_chapters.length + 1}');
    final title = TextEditingController();
    String rating = _value(_comic?['suggestedAgeRating'], 'ALL_AGES');
    String mode = 'AUTO';
    final metadata = await showDialog<Map<String, dynamic>>(context: context, builder: (dialogContext) => StatefulBuilder(builder: (dialogContext, updateDialog) => AlertDialog(
      title: const Text('Nhập chương từ file'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: start, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Số chương bắt đầu', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        TextField(controller: title, decoration: const InputDecoration(labelText: 'Tên chương nếu chỉ nhập 1 chương', border: OutlineInputBorder())),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: rating, decoration: const InputDecoration(labelText: 'Độ tuổi đề xuất cho chương', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'ALL_AGES', child: Text('Mọi lứa tuổi')), DropdownMenuItem(value: '13+', child: Text('13+')), DropdownMenuItem(value: '16+', child: Text('16+')), DropdownMenuItem(value: '18+', child: Text('18+'))], onChanged: (v) => updateDialog(() => rating = v ?? 'ALL_AGES')),
        const SizedBox(height: 10),
        DropdownButtonFormField<String>(value: mode, decoration: const InputDecoration(labelText: 'Cách xử lý PDF', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'AUTO', child: Text('Tự nhận diện chữ / hình')), DropdownMenuItem(value: 'IMAGE', child: Text('PDF truyện hình → ảnh')), DropdownMenuItem(value: 'TEXT', child: Text('PDF có văn bản → truyện chữ'))], onChanged: (v) => updateDialog(() => mode = v ?? 'AUTO')),
        const SizedBox(height: 8),
        const Text('ZIP/CBZ có các thư mục Chương 1, Chương 2... sẽ được tách thành nhiều chương. Có thể chọn nhiều ảnh để tạo một chương. Chương nhập mới luôn chờ kiểm duyệt.', style: TextStyle(fontSize: 12, color: Colors.grey)),
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(dialogContext, {'start': int.tryParse(start.text.trim()), 'title': title.text.trim(), 'rating': rating, 'mode': mode}), child: const Text('Chọn file'))],
    )));
    start.dispose(); title.dispose();
    if (metadata == null) return;
    if (metadata['start'] == null || (metadata['start'] as int) < 1) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Số chương bắt đầu phải lớn hơn 0.')));
      return;
    }

    List<Map<String, dynamic>> uploadItems = [];
    final chooseSource = await showModalBottomSheet<String>(context: context, builder: (sheetContext) => SafeArea(child: Wrap(children: [
      ListTile(leading: const Icon(Icons.insert_drive_file_outlined), title: const Text('Chọn file / nhiều ảnh / ZIP / CBZ / PDF / TXT'), onTap: () => Navigator.pop(sheetContext, 'files')),
      if (!Platform.isAndroid && !Platform.isIOS) ListTile(leading: const Icon(Icons.folder_open_outlined), title: const Text('Chọn thư mục chứa các chương'), onTap: () => Navigator.pop(sheetContext, 'folder')),
    ])));
    if (chooseSource == null) return;
    try {
      if (chooseSource == 'folder') {
        final folder = await FilePicker.platform.getDirectoryPath(dialogTitle: 'Chọn thư mục truyện đã giải nén');
        if (folder == null) return;
        final root = Directory(folder);
        const allowed = {'jpg','jpeg','png','webp','gif','bmp','tif','tiff','zip','cbz','pdf','txt','md'};
        final all = await root.list(recursive: true, followLinks: false).where((entity) => entity is File).cast<File>().toList();
        all.sort((a,b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()));
        for (final file in all) {
          final relative = file.path.substring(root.path.length).replaceFirst(RegExp(r'^[\\/]'), '').replaceAll('\\', '/');
          final ext = relative.contains('.') ? relative.split('.').last.toLowerCase() : '';
          if (!allowed.contains(ext)) continue;
          final bytes = await file.readAsBytes();
          uploadItems.add({'name': relative, 'relativePath': relative, 'bytes': bytes});
          if (uploadItems.fold<int>(0, (sum, item) => sum + (item['bytes'] as List<int>).length) > 250 * 1024 * 1024) throw Exception('Thư mục vượt quá 250 MB. Hãy chia thành các lần nhập nhỏ hơn.');
        }
      } else {
        final picked = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg','jpeg','png','webp','gif','bmp','tif','tiff','zip','cbz','pdf','txt','md'], allowMultiple: true, withData: true);
        if (picked == null || picked.files.isEmpty) return;
        for (final file in picked.files) {
          if (file.bytes == null) throw Exception('Không đọc được ${file.name}. Hãy chọn lại file.');
          uploadItems.add({'name': file.name, 'bytes': file.bytes!});
        }
      }
      if (uploadItems.isEmpty) throw Exception('Không tìm thấy file được hỗ trợ trong nguồn đã chọn.');
      if (mounted) setState(() => _loading = true);
      final result = await context.read<RemoteDataSource>().importAuthorChapters(comicId: widget.comicId, startingChapterNumber: metadata['start'] as int, title: _value(metadata['title']), mode: _value(metadata['mode']), suggestedAgeRating: _value(metadata['rating']), files: uploadItems);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã nhập ${result['createdCount'] ?? 0} chương. Các chương đang chờ kiểm duyệt.')));
    } catch (e) {
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không nhập được truyện: $e')));
    }
  }

  Future<void> _openChapter(Map<String, dynamic> chapter) async {
    final id = int.tryParse(_value(chapter['id']));
    if (id == null) return;
    final changed = await Navigator.push<bool>(context, MaterialPageRoute(builder: (_) => AuthorChapterManagerScreen(chapterId: id, fallbackTitle: _value(chapter['title'], 'Chương'))));
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_comic?['title']?.toString() ?? widget.fallbackTitle), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _loading ? null : _addChapter, icon: const Icon(Icons.add), label: const Text('Thêm chương')),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Không tải được chi tiết: $_error', textAlign: TextAlign.center), const SizedBox(height: 10), OutlinedButton(onPressed: _load, child: const Text('Thử lại'))]))) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      Card(child: ListTile(leading: const Icon(Icons.info_outline), title: const Text('Thông tin truyện đã được tạo'), subtitle: Text('Độ tuổi đề xuất: ' + _value(_comic?['suggestedAgeRating'], 'ALL_AGES') + '\nCác chương được duyệt và giới hạn tuổi riêng từng chương.'), isThreeLine: true)),
      const SizedBox(height: 12),
      Card(child: ListTile(
        leading: Stack(clipBehavior: Clip.none, children: [const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.forum_outlined, color: Color(0xff7b4ab9), size: 27)), if (_hasUnreadFeedback) Positioned(right: -3, top: -3, child: Container(width: 10, height: 10, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5))))]),
        title: const Text('Bình luận & đánh giá', style: TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('★ ${(double.tryParse('${_feedbackSummary['averageRating'] ?? 0}') ?? 0.0).toStringAsFixed(1)} (${int.tryParse('${_feedbackSummary['reviewCount'] ?? 0}') ?? 0} đánh giá) · ${int.tryParse('${_feedbackSummary['commentCount'] ?? 0}') ?? 0} bình luận'),
        trailing: const Icon(Icons.chevron_right),
        onTap: _openFeedback,
      )),
      const SizedBox(height: 14),
      Text('Danh sách chương (${_chapters.length})', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      FilledButton.tonalIcon(onPressed: _loading ? null : _importChapters, icon: const Icon(Icons.drive_folder_upload_outlined), label: const Text('Nhập truyện từ file / thư mục')) ,
      if (_chapters.isEmpty) const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Chưa có chương. Dùng nút Thêm chương để bắt đầu.'))),
      ..._chapters.map((chapter) => Card(child: ListTile(leading: CircleAvatar(child: Text(_value(chapter['chapterNumber'], '?'))), title: Text(_value(chapter['title'], 'Chương')), subtitle: Text('${_value(chapter['contentType'], 'IMAGE') == 'TEXT' ? 'Truyện chữ' : 'Truyện hình'} · ${_moderationLabel(chapter['moderationStatus'])} · Độ tuổi: ${_value(chapter['ageRating'], 'ALL_AGES')}'), trailing: const Icon(Icons.chevron_right), onTap: () => _openChapter(chapter)))),
      const SizedBox(height: 8),
      const Text('Mỗi chương mới, nội dung chữ được sửa hoặc trang ảnh được thêm sẽ được gửi kiểm duyệt riêng. Thông tin truyện và ảnh bìa không cần duyệt.', style: TextStyle(color: Colors.grey, fontSize: 12)),
    ])),
  );
}

class AuthorChapterManagerScreen extends StatefulWidget {
  final int chapterId;
  final String fallbackTitle;
  const AuthorChapterManagerScreen({super.key, required this.chapterId, required this.fallbackTitle});

  @override
  State<AuthorChapterManagerScreen> createState() => _AuthorChapterManagerScreenState();
}

class _AuthorChapterManagerScreenState extends State<AuthorChapterManagerScreen> {
  Map<String, dynamic>? _chapter;
  List<Map<String, dynamic>> _pages = [];
  bool _loading = true;
  bool _uploading = false;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<RemoteDataSource>().getAuthorChapterDetail(widget.chapterId);
      if (!mounted) return;
      setState(() {
        _chapter = Map<String, dynamic>.from(data['chapter'] as Map? ?? const {});
        _pages = (data['pages'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _editTextContent() async {
    final controller = TextEditingController(text: _value(_chapter?['contentText']));
    final content = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sửa nội dung chương chữ'),
        content: SizedBox(
          width: 560,
          child: TextField(
            controller: controller,
            minLines: 8,
            maxLines: 16,
            maxLength: 500000,
            decoration: const InputDecoration(
              labelText: 'Nội dung chương',
              alignLabelWithHint: true,
              border: OutlineInputBorder(),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Hủy')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text.trim()), child: const Text('Lưu và gửi duyệt lại')),
        ],
      ),
    );
    controller.dispose();
    if (content == null) return;
    if (content.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nội dung chương không được để trống.')));
      return;
    }
    setState(() => _uploading = true);
    try {
      await context.read<RemoteDataSource>().updateAuthorTextChapter(chapterId: widget.chapterId, contentText: content);
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật nội dung. Chương chuyển về trạng thái chờ kiểm duyệt.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được nội dung: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _uploadPage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'], withData: true, allowMultiple: true);
    if (result == null || result.files.isEmpty) return;
    final files = result.files.where((f) => f.bytes != null).toList()..sort((a, b) => _naturalFileCompare(a.name, b.name));
    if (files.isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Không đọc được file ảnh. Hãy chọn lại.')));
      return;
    }
    var next = _pages.fold<int>(0, (max, row) => (int.tryParse(_value(row['pageNumber'])) ?? 0) > max ? (int.tryParse(_value(row['pageNumber'])) ?? 0) : max) + 1;
    var uploadedCount = 0;
    setState(() => _uploading = true);
    try {
      for (final file in files) {
        final lower = file.name.toLowerCase();
        if (!lower.endsWith('.jpg') && !lower.endsWith('.jpeg') && !lower.endsWith('.png') && !lower.endsWith('.webp')) continue;
        await context.read<RemoteDataSource>().uploadAuthorPage(chapterId: widget.chapterId, pageNumber: next, bytes: file.bytes!, filename: file.name);
        next++;
        uploadedCount++;
      }
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã tải $uploadedCount trang ảnh. Chương đang chờ kiểm duyệt.')));
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không tải được ảnh: $e'))); }
    finally { if (mounted) setState(() => _uploading = false); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(_chapter?['title']?.toString() ?? widget.fallbackTitle), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh))]),
    floatingActionButton: FloatingActionButton.extended(onPressed: _uploading || _loading ? null : (_value(_chapter?['contentType'], 'IMAGE') == 'TEXT' ? _editTextContent : _uploadPage), icon: _uploading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(_value(_chapter?['contentType'], 'IMAGE') == 'TEXT' ? Icons.edit_note : Icons.add_photo_alternate_outlined), label: Text(_uploading ? 'Đang lưu...' : (_value(_chapter?['contentType'], 'IMAGE') == 'TEXT' ? 'Sửa nội dung chữ' : 'Tải trang ảnh'))),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Không tải được chương: $_error', textAlign: TextAlign.center), const SizedBox(height: 10), OutlinedButton(onPressed: _load, child: const Text('Thử lại'))]))) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(children: [
          const Icon(Icons.collections_outlined, size: 30),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_value(_chapter?['contentType'], 'IMAGE') == 'TEXT' ? 'Nội dung truyện chữ' : 'Trang ảnh (${_pages.length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            Text(_value(_chapter?['contentType'], 'IMAGE') == 'TEXT' ? 'Nội dung chương chữ sẽ được đọc trước khi kiểm duyệt.' : 'Ảnh được đánh số theo thứ tự tự nhiên của tên file.'),
          ])),
        ]),
      ),
      const SizedBox(height: 12),
      if (_value(_chapter?['contentType'], 'IMAGE') == 'TEXT' && _value(_chapter?['contentText']).isNotEmpty) ...[
        Card(child: Padding(padding: const EdgeInsets.all(16), child: SelectableText(_value(_chapter?['contentText'])))),
        OutlinedButton.icon(onPressed: _uploading ? null : _editTextContent, icon: const Icon(Icons.edit_outlined), label: const Text('Sửa nội dung chữ')),
      ],
      if (_pages.isEmpty && _value(_chapter?['contentType'], 'IMAGE') != 'TEXT') const Card(child: Padding(padding: EdgeInsets.all(20), child: Text('Chương chưa có trang ảnh. Dùng nút Tải trang ảnh hoặc Nhập chương từ ZIP/CBZ/PDF.'))),
      ..._pages.map((page) => Card(child: ListTile(leading: CircleAvatar(child: Text(_value(page['pageNumber'], '?'))), title: Text('Trang ' + _value(page['pageNumber'], '?')), subtitle: Text(_value(page['imageUrl']), maxLines: 2, overflow: TextOverflow.ellipsis), trailing: const Icon(Icons.image_outlined)))),
      const SizedBox(height: 8),
      const Text('Sau khi tải ảnh, chương được đưa vào hàng chờ kiểm duyệt. Hãy tải đủ trang theo thứ tự trước khi gửi tác phẩm cho độc giả.', style: TextStyle(color: Colors.grey, fontSize: 12)),
    ])),
  );
}
