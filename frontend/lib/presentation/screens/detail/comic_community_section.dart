import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/remote/remote_data_source.dart';

class ComicCommunitySection extends StatefulWidget {
  final int comicId;
  const ComicCommunitySection({super.key, required this.comicId});

  @override
  State<ComicCommunitySection> createState() => _ComicCommunitySectionState();
}

class _ComicCommunitySectionState extends State<ComicCommunitySection> {
  final TextEditingController _comment = TextEditingController();
  final TextEditingController _reviewText = TextEditingController();
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _reviews = [];
  Map<String, dynamic> _summary = const {};
  int _rating = 5;
  bool _loading = true;
  bool _sendingComment = false;
  bool _sendingReview = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _comment.dispose();
    _reviewText.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<RemoteDataSource>();
      final comments = await api.getComicComments(widget.comicId);
      final reviews = await api.getComicReviews(widget.comicId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _summary = reviews;
        _reviews = (reviews['reviews'] as List? ?? const []).map((item) => Map<String, dynamic>.from(item as Map)).toList();
        final mine = reviews['myReview'];
        if (mine is Map) {
          _rating = int.tryParse('${mine['rating']}') ?? 5;
          _reviewText.text = '${mine['reviewText'] ?? ''}';
        }
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _sendComment() async {
    final content = _comment.text.trim();
    if (content.isEmpty) return;
    setState(() => _sendingComment = true);
    try {
      await context.read<RemoteDataSource>().addComicComment(comicId: widget.comicId, content: content);
      _comment.clear();
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã đăng bình luận.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không đăng được bình luận: $e')));
    } finally {
      if (mounted) setState(() => _sendingComment = false);
    }
  }

  Future<void> _sendReview() async {
    setState(() => _sendingReview = true);
    try {
      await context.read<RemoteDataSource>().submitComicReview(
        comicId: widget.comicId, rating: _rating, reviewText: _reviewText.text.trim());
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu đánh giá của bạn.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không lưu được đánh giá: $e')));
    } finally {
      if (mounted) setState(() => _sendingReview = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final average = double.tryParse('${_summary['averageRating'] ?? 0}') ?? 0;
    final count = int.tryParse('${_summary['count'] ?? 0}') ?? 0;
    return Card(
      margin: const EdgeInsets.only(top: 18, bottom: 20),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(child: Text('Đánh giá & bình luận', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18))),
            IconButton(tooltip: 'Làm mới', onPressed: _load, icon: const Icon(Icons.refresh)),
          ]),
          if (_loading) const Padding(padding: EdgeInsets.all(10), child: Center(child: CircularProgressIndicator())),
          if (!_loading && _error != null) Text('Chưa tải được nhận xét: $_error', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          if (!_loading && _error == null) ...[
            Row(children: [
              const Icon(Icons.star, color: Colors.amber, size: 27),
              const SizedBox(width: 6),
              Text(average.toStringAsFixed(1), style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('$count đánh giá', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
            const SizedBox(height: 10),
            const Text('Đánh giá của bạn', style: TextStyle(fontWeight: FontWeight.w600)),
            Row(children: List.generate(5, (index) => IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _sendingReview ? null : () => setState(() => _rating = index + 1),
              icon: Icon(index < _rating ? Icons.star : Icons.star_border, color: Colors.amber, size: 28),
            ))),
            TextField(controller: _reviewText, maxLength: 2000, maxLines: 2, decoration: const InputDecoration(labelText: 'Nhận xét (không bắt buộc)', border: OutlineInputBorder(), alignLabelWithHint: true)),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _sendingReview ? null : _sendReview, icon: const Icon(Icons.star_outline), label: Text(_sendingReview ? 'Đang gửi...' : 'Lưu đánh giá'))),
            const Divider(height: 28),
            const Text('Bình luận của độc giả', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(controller: _comment, maxLength: 2000, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Viết bình luận', border: OutlineInputBorder(), alignLabelWithHint: true)),
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: FilledButton.icon(onPressed: _sendingComment ? null : _sendComment, icon: const Icon(Icons.send_outlined), label: Text(_sendingComment ? 'Đang gửi...' : 'Gửi bình luận'))),
            const SizedBox(height: 10),
            if (_comments.isEmpty) const Text('Chưa có bình luận. Hãy là người đầu tiên chia sẻ cảm nhận.', style: TextStyle(color: Colors.grey))
            else ..._comments.map((item) => ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const CircleAvatar(child: Icon(Icons.person_outline)),
              title: Text('${item['displayName'] ?? 'Độc giả'} (@${item['username'] ?? 'reader'})', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${item['content'] ?? ''}\n${item['createdAt'] ?? ''}'),
            )),
            const SizedBox(height: 8),
            const Text('Đánh giá gần đây', style: TextStyle(fontWeight: FontWeight.bold)),
            if (_reviews.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Text('Chưa có đánh giá nào.', style: TextStyle(color: Colors.grey)))
            else ..._reviews.map((item) {
              final rawScore = int.tryParse('${item['rating']}') ?? 0;
              final score = rawScore < 0 ? 0 : (rawScore > 5 ? 5 : rawScore);
              final reviewText = '${item['reviewText'] ?? ''}'.trim();
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.star, color: Colors.amber),
                title: Text('${item['displayName'] ?? 'Độc giả'} · ${List<String>.filled(score, '★').join()}${List<String>.filled(5 - score, '☆').join()}'),
                subtitle: Text(reviewText.isEmpty ? 'Không kèm nhận xét.' : reviewText),
              );
            }),
          ],
        ]),
      ),
    );
  }
}
