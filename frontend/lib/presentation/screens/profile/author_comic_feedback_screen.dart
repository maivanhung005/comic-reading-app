import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/remote/remote_data_source.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'author_feedback_read_state.dart';

String _feedbackString(dynamic value, [String fallback = '']) => value == null ? fallback : value.toString();
int _feedbackInt(dynamic value) => int.tryParse('$value') ?? 0;
double _feedbackDouble(dynamic value) => double.tryParse('$value') ?? 0.0;
String _feedbackDate(dynamic value) {
  final raw = _feedbackString(value);
  if (raw.isEmpty) return '';
  final date = DateTime.tryParse(raw);
  if (date == null) return raw;
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year}';
}

class AuthorComicFeedbackScreen extends StatefulWidget {
  final int comicId;
  final String comicTitle;
  const AuthorComicFeedbackScreen({super.key, required this.comicId, required this.comicTitle});
  @override
  State<AuthorComicFeedbackScreen> createState() => _AuthorComicFeedbackScreenState();
}

class _AuthorComicFeedbackScreenState extends State<AuthorComicFeedbackScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() { super.initState(); _load(); }
  @override
  void dispose() { _tabs.dispose(); super.dispose(); }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<RemoteDataSource>().getAuthorComicFeedback(widget.comicId);
      final userId = context.read<AuthViewModel>().currentUser?.id;
      if (userId != null) await AuthorFeedbackReadState.markSeen(userId, widget.comicId, data);
      if (!mounted) return;
      setState(() { _data = data; _loading = false; });
    } catch (e) { if (mounted) setState(() { _error = e.toString(); _loading = false; }); }
  }

  Widget _comments() {
    final items = (_data['comments'] as List? ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
    if (items.isEmpty) return const _FeedbackEmpty(icon: Icons.mode_comment_outlined, title: 'Chưa có bình luận', subtitle: 'Bình luận của độc giả sẽ hiển thị tại đây.');
    return ListView.separated(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), itemCount: items.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
      final item = items[i];
      return ListTile(leading: const CircleAvatar(child: Icon(Icons.person_outline)), title: Text(_feedbackString(item['readerName'], 'Độc giả')), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(_feedbackString(item['content'])), const SizedBox(height: 4), Text(_feedbackDate(item['createdAt']), style: Theme.of(context).textTheme.bodySmall)]));
    });
  }

  Widget _reviews() {
    final items = (_data['reviews'] as List? ?? const []).map((x) => Map<String, dynamic>.from(x as Map)).toList();
    if (items.isEmpty) return const _FeedbackEmpty(icon: Icons.star_outline, title: 'Chưa có đánh giá', subtitle: 'Đánh giá và điểm sao của độc giả sẽ hiển thị tại đây.');
    return ListView.separated(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), itemCount: items.length, separatorBuilder: (_, __) => const Divider(height: 1), itemBuilder: (_, i) {
      final item = items[i];
      final rating = _feedbackInt(item['rating']).clamp(0, 5).toInt();
      final text = _feedbackString(item['reviewText']).trim();
      return ListTile(leading: const Icon(Icons.star, color: Colors.amber), title: Text('${_feedbackString(item['readerName'], 'Độc giả')} · ${List<String>.filled(rating, '★').join()}${List<String>.filled(5 - rating, '☆').join()}'), subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(text.isEmpty ? 'Không kèm nhận xét.' : text), const SizedBox(height: 4), Text(_feedbackDate(item['updatedAt']), style: Theme.of(context).textTheme.bodySmall)]));
    });
  }

  @override
  Widget build(BuildContext context) {
    final avg = _feedbackDouble(_data['averageRating']);
    return Scaffold(
      appBar: AppBar(title: const Text('Bình luận & đánh giá'), actions: [IconButton(tooltip: 'Làm mới', onPressed: _load, icon: const Icon(Icons.refresh))]),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _error != null ? _FeedbackError(message: _error!, retry: _load) : Column(children: [
        Card(margin: const EdgeInsets.fromLTRB(16, 12, 16, 10), child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(widget.comicTitle, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(children: [const Icon(Icons.star_rounded, color: Colors.amber, size: 30), const SizedBox(width: 4), Text(avg.toStringAsFixed(1), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)), const SizedBox(width: 8), Expanded(child: Text('Điểm trung bình từ ${_feedbackInt(_data['reviewCount'])} lượt đánh giá'))]),
          const SizedBox(height: 8),
          Row(children: [const Icon(Icons.mode_comment_outlined, size: 18), const SizedBox(width: 6), Text('${_feedbackInt(_data['commentCount'])} bình luận')]),
        ]))),
        TabBar(controller: _tabs, tabs: [Tab(text: 'Bình luận (${_feedbackInt(_data['commentCount'])})'), Tab(text: 'Đánh giá (${_feedbackInt(_data['reviewCount'])})')]),
        Expanded(child: TabBarView(controller: _tabs, children: [_comments(), _reviews()])),
      ]),
    );
  }
}

class _FeedbackEmpty extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const _FeedbackEmpty({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Icon(icon, size: 42, color: Colors.grey), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))])));
}

class _FeedbackError extends StatelessWidget {
  final String message;
  final Future<void> Function() retry;
  const _FeedbackError({required this.message, required this.retry});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [const Icon(Icons.cloud_off_outlined, size: 42), const SizedBox(height: 10), Text(message, textAlign: TextAlign.center), const SizedBox(height: 10), OutlinedButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Thử lại'))])));
}
