import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/remote/remote_data_source.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'author_studio_screen.dart';

String _s(dynamic value, [String fallback = '']) => value == null ? fallback : value.toString();
int _i(dynamic value) => int.tryParse('$value') ?? 0;
double _d(dynamic value) => double.tryParse('$value') ?? 0.0;

String _dateLabel(dynamic value) {
  final raw = _s(value);
  if (raw.isEmpty) return '';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _moderationLabel(dynamic value) {
  switch (_s(value).toUpperCase()) {
    case 'APPROVED': return 'Đã duyệt';
    case 'PENDING': return 'Chờ duyệt';
    case 'REJECTED': return 'Bị từ chối';
    case 'HIDDEN': return 'Đang ẩn';
    default: return 'Chưa có chương';
  }
}

Color _moderationColor(BuildContext context, dynamic value) {
  switch (_s(value).toUpperCase()) {
    case 'APPROVED': return Colors.green;
    case 'REJECTED': return Theme.of(context).colorScheme.error;
    case 'HIDDEN': return Colors.grey;
    default: return Colors.orange.shade800;
  }
}

class AuthorFollowersScreen extends StatefulWidget {
  const AuthorFollowersScreen({super.key});
  @override
  State<AuthorFollowersScreen> createState() => _AuthorFollowersScreenState();
}

class _AuthorFollowersScreenState extends State<AuthorFollowersScreen> {
  List<Map<String, dynamic>> _followers = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<RemoteDataSource>().getAuthorFollowers();
      if (!mounted) return;
      setState(() {
        _followers = (data['followers'] as List? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
        _loading = false;
      });
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Người theo dõi'), actions: [IconButton(tooltip: 'Làm mới', onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null
      ? _WorkspaceError(message: _error!, retry: _load)
      : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.groups_2_outlined, size: 34, color: Color(0xff7b4ab9)),
                const SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${_followers.length}', style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Text('Độc giả đang theo dõi bạn'),
                ])),
              ]),
            ),
          ),
          const SizedBox(height: 12),
          if (_followers.isEmpty) const _WorkspaceEmpty(icon: Icons.people_outline, title: 'Chưa có người theo dõi', subtitle: 'Khi độc giả theo dõi bút danh của bạn, họ sẽ xuất hiện ở đây.'),
          ..._followers.map((follower) {
            final name = _s(follower['displayName'], _s(follower['username'], 'Độc giả'));
            final username = _s(follower['username']);
            return Card(child: ListTile(
              leading: CircleAvatar(child: Text(name.trim().isEmpty ? 'Đ' : name.trim().substring(0, 1).toUpperCase())),
              title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text([if (username.isNotEmpty) '@$username', if (_dateLabel(follower['followedAt']).isNotEmpty) 'Theo dõi từ ${_dateLabel(follower['followedAt'])}'].join(' · ')),
            ));
          }),
        ])),
  );
}

class AuthorStatisticsScreen extends StatefulWidget {
  const AuthorStatisticsScreen({super.key});
  @override
  State<AuthorStatisticsScreen> createState() => _AuthorStatisticsScreenState();
}

class _AuthorStatisticsScreenState extends State<AuthorStatisticsScreen> {
  Map<String, dynamic> _dashboard = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await context.read<RemoteDataSource>().getAuthorDashboard();
      if (!mounted) return;
      setState(() { _dashboard = result; _loading = false; });
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
  }

  @override
  Widget build(BuildContext context) {
    final comics = (_dashboard['comicStatistics'] as List? ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê truyện'), actions: [IconButton(tooltip: 'Làm mới', onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? _WorkspaceError(message: _error!, retry: _load) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
        GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, childAspectRatio: 1.65, crossAxisSpacing: 10, mainAxisSpacing: 10, children: [
          _MetricCard(icon: Icons.auto_stories_outlined, label: 'Truyện', value: '${_i(_dashboard['comicCount'])}'),
          _MetricCard(icon: Icons.visibility_outlined, label: 'Lượt đọc', value: '${_i(_dashboard['readingProgressCount'])}'),
          _MetricCard(icon: Icons.people_alt_outlined, label: 'Độc giả', value: '${_i(_dashboard['uniqueReaderCount'])}'),
          _MetricCard(icon: Icons.mode_comment_outlined, label: 'Bình luận', value: '${_i(_dashboard['commentCount'])}'),
        ]),
        const SizedBox(height: 20),
        Text('Hiệu suất từng truyện', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (comics.isEmpty) const _WorkspaceEmpty(icon: Icons.auto_stories_outlined, title: 'Chưa có dữ liệu truyện', subtitle: 'Tạo truyện và xuất bản chương để theo dõi hiệu suất.'),
        ...comics.map((comic) {
          final avg = _d(comic['averageRating']);
          final reviewCount = _i(comic['reviewCount']);
          return Card(margin: const EdgeInsets.only(bottom: 10), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(_s(comic['title'], 'Truyện'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 8),
            Row(children: [const Icon(Icons.star, color: Colors.amber, size: 19), const SizedBox(width: 4), Text('${avg.toStringAsFixed(1)} (${reviewCount} đánh giá)'), const Spacer(), Text('${_i(comic['readerCount'])} độc giả', style: Theme.of(context).textTheme.bodySmall)]),
            const SizedBox(height: 10),
            Wrap(spacing: 7, runSpacing: 7, children: [
              _SmallMetric(icon: Icons.visibility_outlined, label: '${_i(comic['readingCount'])} lượt đọc'),
              _SmallMetric(icon: Icons.mode_comment_outlined, label: '${_i(comic['commentCount'])} bình luận'),
              _SmallMetric(icon: Icons.menu_book_outlined, label: '${_i(comic['chapterCount'])} chương'),
            ]),
          ])));
        }),
      ])),
    );
  }
}

class AuthorModerationStatusScreen extends StatefulWidget {
  const AuthorModerationStatusScreen({super.key});
  @override
  State<AuthorModerationStatusScreen> createState() => _AuthorModerationStatusScreenState();
}

class _AuthorModerationStatusScreenState extends State<AuthorModerationStatusScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<RemoteDataSource>();
      final comics = await api.getAuthorComics();
      final result = <Map<String, dynamic>>[];
      for (final comic in comics) {
        final id = int.tryParse(_s(comic['id']));
        if (id == null) continue;
        final details = await api.getAuthorComicDetail(id);
        final fullComic = Map<String, dynamic>.from(details['comic'] as Map? ?? comic);
        final chapters = (details['chapters'] as List? ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
        result.add({'comic': fullComic, 'chapters': chapters});
      }
      if (!mounted) return;
      setState(() { _items = result; _loading = false; });
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
  }

  Future<void> _openComic(Map<String, dynamic> comic) async {
    final id = int.tryParse(_s(comic['id']));
    if (id == null) return;
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AuthorComicManagerScreen(comicId: id, fallbackTitle: _s(comic['title'], 'Truyện'))));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trạng thái duyệt'), actions: [IconButton(tooltip: 'Làm mới', onPressed: _load, icon: const Icon(Icons.refresh))]),
    body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? _WorkspaceError(message: _error!, retry: _load) : RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('Theo dõi tiến độ kiểm duyệt của từng chương. Thông tin truyện và ảnh bìa không cần duyệt; nội dung chương mới hoặc đã sửa sẽ chờ Moderator/Admin xem xét.', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 12),
      if (_items.isEmpty) const _WorkspaceEmpty(icon: Icons.fact_check_outlined, title: 'Chưa có truyện', subtitle: 'Tạo truyện trong Studio để bắt đầu.'),
      ..._items.map((item) {
        final comic = Map<String, dynamic>.from(item['comic'] as Map);
        final chapters = (item['chapters'] as List? ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
        final pending = chapters.where((c) => _s(c['moderationStatus']).toUpperCase() == 'PENDING').length;
        final approved = chapters.where((c) => _s(c['moderationStatus']).toUpperCase() == 'APPROVED').length;
        final rejected = chapters.where((c) => _s(c['moderationStatus']).toUpperCase() == 'REJECTED').length;
        return Card(margin: const EdgeInsets.only(bottom: 12), child: Padding(padding: const EdgeInsets.all(14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_s(comic['title'], 'Truyện'), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          Wrap(spacing: 7, runSpacing: 7, children: [
            _CountPill(label: '$pending chờ duyệt', color: Colors.orange.shade800),
            _CountPill(label: '$approved đã duyệt', color: Colors.green),
            if (rejected > 0) _CountPill(label: '$rejected bị từ chối', color: Theme.of(context).colorScheme.error),
          ]),
          const SizedBox(height: 8),
          if (chapters.isEmpty) const Text('Chưa có chương.', style: TextStyle(color: Colors.grey)) else ...chapters.map((chapter) => ListTile(
            dense: true, contentPadding: EdgeInsets.zero, leading: Icon(Icons.menu_book_outlined, color: _moderationColor(context, chapter['moderationStatus'])),
            title: Text('Chương ${_i(chapter['chapterNumber'])}: ${_s(chapter['title'], 'Chưa đặt tên')}', maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(_moderationLabel(chapter['moderationStatus']) + ( _s(chapter['reviewNotes']).isNotEmpty ? ' · ${_s(chapter['reviewNotes'])}' : '')),
          )),
          Align(alignment: Alignment.centerRight, child: TextButton.icon(onPressed: () => _openComic(comic), icon: const Icon(Icons.open_in_new), label: const Text('Quản lý truyện'))),
        ])));
      }),
    ])),
  );
}

class _WorkspaceError extends StatelessWidget {
  final String message;
  final Future<void> Function() retry;
  const _WorkspaceError({required this.message, required this.retry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 42), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center), const SizedBox(height: 10), OutlinedButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Thử lại'))])));
}

class _WorkspaceEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _WorkspaceEmpty({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 42, color: Colors.grey), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))]));
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _MetricCard({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [Icon(icon, color: const Color(0xff7b4ab9), size: 25), const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)), Text(label, style: Theme.of(context).textTheme.bodySmall)]))])));
}

class _SmallMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SmallMetric({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 15, color: Colors.grey), const SizedBox(width: 4), Text(label, style: Theme.of(context).textTheme.bodySmall)]);
}

class _CountPill extends StatelessWidget {
  final String label;
  final Color color;
  const _CountPill({required this.label, required this.color});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5), decoration: BoxDecoration(color: color.withOpacity(.10), borderRadius: BorderRadius.circular(20)), child: Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)));
}
