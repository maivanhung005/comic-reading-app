import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../navigation/auth_navigation.dart';
import '../../../data/datasources/remote/remote_data_source.dart';
import '../../../core/constants/api_constants.dart';
import '../../viewmodels/profile_offline_viewmodel.dart';
import 'author_studio_screen.dart';

class FeatureInfoScreen extends StatelessWidget {
  final String title;
  final IconData icon;
  final String description;
  final List<String> details;
  const FeatureInfoScreen({super.key, required this.title, required this.icon, required this.description, this.details = const []});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      Container(padding: const EdgeInsets.all(24), decoration: BoxDecoration(gradient: const LinearGradient(colors: [Color(0xff6f42c1), Color(0xff9b72cf)]), borderRadius: BorderRadius.circular(22)), child: Column(children: [Icon(icon, color: Colors.white, size: 48), const SizedBox(height: 12), Text(title, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)), const SizedBox(height: 8), Text(description, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70))]),),
      const SizedBox(height: 20),
      ...details.map((item) => Card(margin: const EdgeInsets.only(bottom: 10), child: ListTile(leading: const Icon(Icons.check_circle_outline, color: Color(0xff6f42c1)), title: Text(item)))),
      const SizedBox(height: 16),
      const Text('Một số tính năng cần API và dữ liệu máy chủ riêng sẽ được hoàn thiện ở các bước tiếp theo. Dữ liệu demo trên màn hình này không đại diện cho giao dịch thật.', style: TextStyle(color: Colors.grey), textAlign: TextAlign.center),
    ]),
  );
}

class InboxScreen extends StatelessWidget {
  const InboxScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hộp tin nhắn')),
    body: ListView(padding: const EdgeInsets.all(16), children: const [
      Card(child: ListTile(leading: CircleAvatar(child: Icon(Icons.campaign_outlined)), title: Text('Thông báo hệ thống'), subtitle: Text('Chào mừng bạn đến với Smart Story. Tại đây sẽ hiển thị thông báo tài khoản, cập nhật truyện và phản hồi.'), trailing: Text('Mới'))),
      Card(child: ListTile(leading: CircleAvatar(child: Icon(Icons.auto_stories_outlined)), title: Text('Cập nhật truyện'), subtitle: Text('Theo dõi truyện yêu thích để xem thông báo chương mới trong phiên bản tiếp theo.'))),
      SizedBox(height: 12),
      Text('Đây là dữ liệu minh họa. Hộp thư nhiều thiết bị cần được lưu trên Spring Boot/PostgreSQL.', style: TextStyle(color: Colors.grey)),
    ]),
  );
}

class AuthorApplicationScreen extends StatefulWidget {
  const AuthorApplicationScreen({super.key});
  @override
  State<AuthorApplicationScreen> createState() => _AuthorApplicationScreenState();
}

class _AuthorApplicationScreenState extends State<AuthorApplicationScreen> {
  final _penName = TextEditingController();
  final _experience = TextEditingController();
  bool _agree = false;
  @override
  void dispose() { _penName.dispose(); _experience.dispose(); super.dispose(); }

  Future<void> _submit() async {
    if (_penName.text.trim().isEmpty || !_agree) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập bút danh và đồng ý điều khoản trước khi gửi.')));
      return;
    }
    final auth = context.read<AuthViewModel>();
    final ok = await auth.becomeAuthor(penName: _penName.text.trim(), experience: _experience.text.trim(), termsAccepted: true);
    if (!mounted) return;
    if (ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã kích hoạt quyền AUTHOR. Mỗi truyện mới sẽ cần kiểm duyệt trước khi công khai.')));
      await Navigator.pushReplacement<void, void>(context, MaterialPageRoute<void>(builder: (_) => const AuthorStudioScreen()));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(auth.error ?? 'Không thể đăng ký tác giả.')));
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Trở thành tác giả')),
    body: ListView(padding: const EdgeInsets.all(20), children: [
      const FeatureBanner(icon: Icons.draw_outlined, title: 'Câu chuyện của bạn xứng đáng được kể', subtitle: 'Tạo hồ sơ tác giả và chuẩn bị tác phẩm đầu tiên.'),
      const SizedBox(height: 20),
      TextField(controller: _penName, decoration: const InputDecoration(labelText: 'Bút danh *', border: OutlineInputBorder(), prefixIcon: Icon(Icons.edit_outlined))),
      const SizedBox(height: 14),
      TextField(controller: _experience, maxLines: 4, decoration: const InputDecoration(labelText: 'Giới thiệu kinh nghiệm / ý tưởng', alignLabelWithHint: true, border: OutlineInputBorder())),
      CheckboxListTile(value: _agree, onChanged: (v) => setState(() => _agree = v ?? false), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading, title: const Text('Tôi cam kết tác phẩm là nội dung do mình sáng tác và tuân thủ quy định cộng đồng.')),
      FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.send_outlined), label: const Text('Đăng ký trở thành tác giả')),
      const SizedBox(height: 12),
      const Text('Quyền tác giả được lưu trên máy chủ. Chỉ đăng ký tác giả mới cho phép đăng truyện; mỗi thay đổi truyện sẽ đưa nội dung về hàng chờ kiểm duyệt.', style: TextStyle(color: Colors.grey)),
    ]),
  );
}

class StoryDraftScreen extends StatefulWidget {
  final String storyType;
  const StoryDraftScreen({super.key, required this.storyType});
  @override
  State<StoryDraftScreen> createState() => _StoryDraftScreenState();
}

class _StoryDraftScreenState extends State<StoryDraftScreen> {
  final _title = TextEditingController();
  final _summary = TextEditingController();
  final _content = TextEditingController();
  List<Map<String, dynamic>> _drafts = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _loadDrafts(); }
  @override
  void dispose() { _title.dispose(); _summary.dispose(); _content.dispose(); super.dispose(); }

  Future<void> _loadDrafts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('story_drafts') ?? '[]';
    try { _drafts = (jsonDecode(raw) as List).map((e) => Map<String, dynamic>.from(e as Map)).toList(); } catch (_) { _drafts = []; }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveDraft() async {
    if (_title.text.trim().isEmpty || _content.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng nhập tên tác phẩm và nội dung.')));
      return;
    }
    final draft = <String, dynamic>{'id': DateTime.now().millisecondsSinceEpoch, 'type': widget.storyType, 'title': _title.text.trim(), 'summary': _summary.text.trim(), 'content': _content.text.trim(), 'updatedAt': DateTime.now().toIso8601String()};
    final prefs = await SharedPreferences.getInstance();
    _drafts = [draft, ..._drafts];
    await prefs.setString('story_drafts', jsonEncode(_drafts));
    _title.clear(); _summary.clear(); _content.clear();
    if (mounted) { setState(() {}); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu bản nháp trên thiết bị.'))); }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text('Sáng tác ${widget.storyType.toLowerCase()}')),
    body: ListView(padding: const EdgeInsets.all(18), children: [
      FeatureBanner(icon: widget.storyType == 'Truyện chat' ? Icons.chat_bubble_outline : Icons.menu_book_outlined, title: 'Không gian sáng tác', subtitle: 'Phác thảo ý tưởng trước khi xuất bản.'),
      const SizedBox(height: 18),
      TextField(controller: _title, decoration: const InputDecoration(labelText: 'Tên tác phẩm *', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _summary, maxLines: 2, decoration: const InputDecoration(labelText: 'Giới thiệu ngắn', border: OutlineInputBorder())),
      const SizedBox(height: 12),
      TextField(controller: _content, minLines: 8, maxLines: 14, decoration: InputDecoration(labelText: widget.storyType == 'Truyện chat' ? 'Nội dung hội thoại *' : 'Nội dung chương đầu *', alignLabelWithHint: true, border: const OutlineInputBorder())),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _saveDraft, icon: const Icon(Icons.save_outlined), label: const Text('Lưu bản nháp')),
      const Divider(height: 32),
      Text('Bản nháp của tôi (${_drafts.where((d) => d['type'] == widget.storyType).length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      if (_loading) const LinearProgressIndicator(),
      if (!_loading && _drafts.where((d) => d['type'] == widget.storyType).isEmpty) const ListTile(leading: Icon(Icons.drafts_outlined), title: Text('Chưa có bản nháp')),
      ..._drafts.where((d) => d['type'] == widget.storyType).map((d) => Card(child: ListTile(leading: const Icon(Icons.description_outlined), title: Text('${d['title']}'), subtitle: Text('Lưu lúc ${((d['updatedAt'] ?? '') as String).replaceFirst('T', ' ').split('.').first}'), trailing: IconButton(icon: const Icon(Icons.delete_outline), onPressed: () async { _drafts.removeWhere((item) => item['id'] == d['id']); final prefs = await SharedPreferences.getInstance(); await prefs.setString('story_drafts', jsonEncode(_drafts)); if (mounted) setState(() {}); })))),
      const SizedBox(height: 12),
      const Text('Bản hiện tại lưu nháp trên thiết bị; xuất bản công khai cần API tác giả, kiểm duyệt nội dung và mô hình dữ liệu truyện/episode trên backend.', style: TextStyle(color: Colors.grey)),
    ]),
  );
}

class DailyPerksScreen extends StatefulWidget {
  const DailyPerksScreen({super.key});
  @override
  State<DailyPerksScreen> createState() => _DailyPerksScreenState();
}

class _DailyPerksScreenState extends State<DailyPerksScreen> {
  bool _checkedIn = false;
  int _tickets = 0;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (mounted) setState(() { _checkedIn = prefs.getString('daily_checkin_date') == today; _tickets = prefs.getInt('demo_reading_tickets') ?? 3; });
  }
  Future<void> _checkIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('daily_checkin_date', DateTime.now().toIso8601String().substring(0, 10));
    _tickets += 1; await prefs.setInt('demo_reading_tickets', _tickets);
    if (mounted) setState(() => _checkedIn = true);
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Phúc lợi độc giả')), body: ListView(padding: const EdgeInsets.all(20), children: [
    const FeatureBanner(icon: Icons.card_giftcard_outlined, title: 'Mỗi ngày một niềm vui', subtitle: 'Điểm danh, theo dõi thành tích và nhận phần thưởng demo.'),
    const SizedBox(height: 18),
    Card(child: ListTile(leading: const Icon(Icons.confirmation_num_outlined, color: Color(0xff6f42c1), size: 34), title: const Text('Phiếu đọc thử nghiệm'), subtitle: const Text('Chỉ là số dư demo lưu trên máy này.'), trailing: Text('$_tickets', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)))),
    const SizedBox(height: 12),
    FilledButton.icon(onPressed: _checkedIn ? null : _checkIn, icon: Icon(_checkedIn ? Icons.check_circle : Icons.today_outlined), label: Text(_checkedIn ? 'Đã điểm danh hôm nay' : 'Điểm danh nhận 1 phiếu demo')),
    const SizedBox(height: 16),
    const Text('Phúc lợi thật cần được tính và lưu trên máy chủ để tránh việc tự sửa số dư trên thiết bị.', style: TextStyle(color: Colors.grey)),
  ]));
}

class AvatarCenterScreen extends StatefulWidget {
  const AvatarCenterScreen({super.key});
  @override
  State<AvatarCenterScreen> createState() => _AvatarCenterScreenState();
}
class _AvatarCenterScreenState extends State<AvatarCenterScreen> {
  final _avatars = const ['🌙', '🐱', '🐼', '🦊', '🐰', '🐉', '🌸', '⭐', '🦋', '🐻', '🪐', '🍀'];
  String _selected = '🌙';
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async { if (mounted) setState(() => _selected = context.read<ProfileOfflineViewModel>().avatarEmoji); }
  Future<void> _select(String avatar) async { await context.read<ProfileOfflineViewModel>().setAvatar(avatar); if (mounted) setState(() => _selected = avatar); }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Trung tâm Avatar')), body: ListView(padding: const EdgeInsets.all(20), children: [
    Center(child: CircleAvatar(radius: 48, backgroundColor: const Color(0xfff1eaff), child: Text(_selected, style: const TextStyle(fontSize: 42)))),
    const SizedBox(height: 18), const Text('Chọn avatar', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    const SizedBox(height: 18), GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 4, mainAxisSpacing: 12, crossAxisSpacing: 12, children: _avatars.map((a) => InkWell(onTap: () => _select(a), borderRadius: BorderRadius.circular(16), child: Container(decoration: BoxDecoration(color: _selected == a ? const Color(0xffeee2ff) : Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(16), border: Border.all(color: _selected == a ? const Color(0xff6f42c1) : Colors.transparent, width: 2)), child: Center(child: Text(a, style: const TextStyle(fontSize: 32)))))).toList()),
    const SizedBox(height: 16), const Text('Avatar đang lưu cục bộ trên thiết bị. Muốn đồng bộ nhiều thiết bị cần lưu avatar vào hồ sơ người dùng trên backend.', style: TextStyle(color: Colors.grey)),
  ]));
}

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});
  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}
class _FeedbackScreenState extends State<FeedbackScreen> {
  final _message = TextEditingController();
  String _type = 'Góp ý chức năng';
  @override
  void dispose() { _message.dispose(); super.dispose(); }
  Future<void> _save() async {
    if (_message.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập nội dung phản hồi trước.'))); return; }
    final prefs = await SharedPreferences.getInstance();
    final rows = prefs.getStringList('feedback_drafts') ?? [];
    rows.insert(0, jsonEncode({'type': _type, 'message': _message.text.trim(), 'createdAt': DateTime.now().toIso8601String()}));
    await prefs.setStringList('feedback_drafts', rows);
    _message.clear();
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu phản hồi cục bộ. Chưa gửi lên đội ngũ vận hành.')));
  }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Phản hồi ý kiến')), body: ListView(padding: const EdgeInsets.all(20), children: [
    const FeatureBanner(icon: Icons.feedback_outlined, title: 'Ý kiến của bạn rất quan trọng', subtitle: 'Báo lỗi hoặc đề xuất cải thiện trải nghiệm đọc.'),
    const SizedBox(height: 18), DropdownButtonFormField<String>(value: _type, decoration: const InputDecoration(labelText: 'Loại phản hồi', border: OutlineInputBorder()), items: const [DropdownMenuItem(value: 'Góp ý chức năng', child: Text('Góp ý chức năng')), DropdownMenuItem(value: 'Báo lỗi', child: Text('Báo lỗi')), DropdownMenuItem(value: 'Nội dung truyện', child: Text('Nội dung truyện'))], onChanged: (v) => setState(() => _type = v ?? _type)),
    const SizedBox(height: 12), TextField(controller: _message, minLines: 5, maxLines: 8, decoration: const InputDecoration(labelText: 'Nội dung *', alignLabelWithHint: true, border: OutlineInputBorder())),
    const SizedBox(height: 12), FilledButton.icon(onPressed: _save, icon: const Icon(Icons.send_outlined), label: const Text('Lưu phản hồi')),
    const SizedBox(height: 8), const Text('Trong bản demo phản hồi được lưu trên thiết bị, chưa có API gửi cho quản trị viên.', style: TextStyle(color: Colors.grey)),
  ]));
}

class FeatureBanner extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  const FeatureBanner({required this.icon, required this.title, required this.subtitle});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff5f36a6), Color(0xff9a72cf)]), borderRadius: BorderRadius.circular(22)), child: Row(children: [Icon(icon, color: Colors.white, size: 42), const SizedBox(width: 16), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 19)), const SizedBox(height: 6), Text(subtitle, style: const TextStyle(color: Colors.white70))]))]));
}


class ModeratorDashboardScreen extends StatefulWidget {
  const ModeratorDashboardScreen({super.key});
  @override
  State<ModeratorDashboardScreen> createState() => _ModeratorDashboardScreenState();
}

class _ModeratorDashboardScreenState extends State<ModeratorDashboardScreen> {
  Map<String, dynamic> _queue = const {};
  bool _loading = true;
  String? _error;
  @override
  void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try { _queue = await context.read<RemoteDataSource>().getModerationQueue(); }
    catch (e) { _error = e.toString(); }
    if (mounted) setState(() => _loading = false);
  }
  Future<void> _preview(Map<String,dynamic> comic) async {
    final id = int.tryParse('${comic['id']}') ?? 0;
    try {
      final data = await context.read<RemoteDataSource>().getModerationPreview(id);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ModerationPreviewScreen(preview: data)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không mở được nội dung xem trước: $e')));
    }
  }

  Future<void> _previewChapter(Map<String,dynamic> chapter) async {
    final id = int.tryParse('${chapter['id']}') ?? 0;
    if (id <= 0) return;
    try {
      final data = await context.read<RemoteDataSource>().getModerationChapterPreview(id);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => ModerationChapterPreviewScreen(preview: data)));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không mở được nội dung chương: $e')));
    }
  }

  Future<void> _chapterAction(Map<String,dynamic> chapter, String action, {String rating='ALL_AGES'}) async {
    final id = int.tryParse('${chapter['id']}') ?? 0;
    if (id <= 0) return;
    final reason = TextEditingController();
    if (action == 'AGE_RESTRICT' || action == 'HIDE' || action == 'REJECT') {
      final isAge = action == 'AGE_RESTRICT';
      final isHide = action == 'HIDE';
      final confirmed = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
        title: Text(isAge ? 'Xác nhận giới hạn tuổi $rating' : isHide ? 'Ẩn chương' : 'Từ chối chương'),
        content: TextField(controller: reason, maxLines: 4, decoration: const InputDecoration(labelText: 'Lý do / căn cứ sau khi đọc nội dung *', alignLabelWithHint: true, border: OutlineInputBorder())),
        actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Hủy')), FilledButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Xác nhận'))],
      ));
      if (confirmed != true) { reason.dispose(); return; }
      if (reason.text.trim().isEmpty) {
        reason.dispose();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Nhập lý do kiểm duyệt trước khi tiếp tục.')));
        return;
      }
    }
    try {
      await context.read<RemoteDataSource>().decideChapter(chapterId: id, action: action, ageRating: rating, reason: reason.text.trim());
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã lưu quyết định kiểm duyệt chương.')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể xử lý chương: $e')));
    }
    reason.dispose();
  }

  Future<void> _comicAction(Map<String,dynamic> comic, String action, {String rating='ALL_AGES'}) async {
    final id = int.tryParse('${comic['id']}') ?? 0;
    final reason = TextEditingController();
    if (action == 'REJECT' || action == 'HIDE' || action == 'AGE_RESTRICT') {
      final confirmed = await showDialog<bool>(context: context, builder: (context) => AlertDialog(title: Text(action == 'AGE_RESTRICT' ? 'Giới hạn độ tuổi' : action == 'HIDE' ? 'Ẩn truyện' : 'Từ chối truyện'), content: TextField(controller: reason, maxLines: 3, decoration: const InputDecoration(labelText: 'Lý do / căn cứ', border: OutlineInputBorder())), actions: [TextButton(onPressed: () => Navigator.pop(context,false), child: const Text('Huỷ')), FilledButton(onPressed: () => Navigator.pop(context,true), child: const Text('Xác nhận'))]));
      if (confirmed != true) { reason.dispose(); return; }
    }
    try { await context.read<RemoteDataSource>().decideComic(comicId:id, action:action, ageRating:rating, reason:reason.text.trim()); await _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể xử lý: $e'))); }
    reason.dispose();
  }
  Future<void> _reportAction(Map<String,dynamic> report, String action) async {
    final id = int.tryParse('${report['id']}') ?? 0;
    try { await context.read<RemoteDataSource>().decideReport(reportId:id, action:action, note:'Đã xử lý từ bảng kiểm duyệt.'); await _load(); }
    catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể cập nhật báo cáo: $e'))); }
  }
  @override
  Widget build(BuildContext context) {
    final chapters = (_queue['chapters'] as List? ?? const []).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    final comics = (_queue['comics'] as List? ?? const []).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    final reports = (_queue['reports'] as List? ?? const []).map((e)=>Map<String,dynamic>.from(e as Map)).toList();
    return Scaffold(appBar: AppBar(title: const Text('Trung tâm kiểm duyệt'), actions:[IconButton(tooltip:'Làm mới', onPressed:_load, icon:const Icon(Icons.refresh)), IconButton(tooltip:'Đăng xuất', onPressed:()=>logoutAndReturnToLogin(context), icon:const Icon(Icons.logout))]), body: _loading ? const Center(child:CircularProgressIndicator()) : _error != null ? ListView(padding:const EdgeInsets.all(20), children:[Text('Không tải được dữ liệu: $_error'), FilledButton(onPressed:_load, child:const Text('Thử lại'))]) : RefreshIndicator(onRefresh:_load, child:ListView(padding:const EdgeInsets.all(16), children:[
      Text('Chương chờ kiểm duyệt (${chapters.length})', style:Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      if(chapters.isEmpty) const ListTile(title:Text('Không có chương cần duyệt.')),
      ...chapters.map((chapter)=>Card(child:Padding(padding:const EdgeInsets.all(12), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Text('${chapter['comicTitle'] ?? 'Không tên'} · Chương ${chapter['chapterNumber'] ?? ''}: ${chapter['title'] ?? ''}', style:const TextStyle(fontWeight:FontWeight.bold)),
        const SizedBox(height:4),
        Text('Tác giả: ${chapter['author'] ?? ''} · ${chapter['contentType'] == 'TEXT' ? 'Truyện chữ · ${chapter['textLength'] ?? 0} ký tự' : 'Truyện hình · ${chapter['pageCount'] ?? 0} trang'}'),
        Text('Đề xuất: ${chapter['suggestedAgeRating'] ?? 'ALL_AGES'} · Trạng thái: ${chapter['status'] ?? 'PENDING'}'),
        if('${chapter['reviewNotes'] ?? ''}'.trim().isNotEmpty) Text('Ghi chú: ${chapter['reviewNotes']}'),
        const SizedBox(height:8),
        Wrap(spacing:8,runSpacing:4,children:[
          OutlinedButton.icon(onPressed:()=>_previewChapter(chapter), icon:const Icon(Icons.visibility_outlined), label:const Text('Đọc / xem nội dung')),
          PopupMenuButton<String>(onSelected:(rating) => _chapterAction(chapter, rating == 'ALL_AGES' ? 'APPROVE' : 'AGE_RESTRICT', rating:rating), itemBuilder:(_) => const [
            PopupMenuItem(value:'ALL_AGES', child:Text('Duyệt mọi lứa tuổi')),
            PopupMenuItem(value:'13+', child:Text('Duyệt và giới hạn 13+')),
            PopupMenuItem(value:'16+', child:Text('Duyệt và giới hạn 16+')),
            PopupMenuItem(value:'18+', child:Text('Duyệt và giới hạn 18+')),
          ], child:const Chip(avatar:Icon(Icons.verified_outlined, size:18), label:Text('Duyệt / giới hạn tuổi'))),
          TextButton(onPressed:()=>_chapterAction(chapter,'REJECT'), child:const Text('Từ chối')),
          TextButton(onPressed:()=>_chapterAction(chapter,'HIDE'), child:const Text('Ẩn')),
        ]),
      ])))),
      if(comics.isNotEmpty) ...[
        const SizedBox(height:20),
        Text('Truyện cần xử lý theo quy trình cũ (${comics.length})', style:Theme.of(context).textTheme.titleLarge),
      ],
      ...comics.map((comic)=>Card(child:Padding(padding:const EdgeInsets.all(12), child:Column(crossAxisAlignment:CrossAxisAlignment.start, children:[Text('${comic['title'] ?? 'Không tên'}',style:const TextStyle(fontWeight:FontWeight.bold)), Text('Tác giả: ${comic['author'] ?? ''} · Trạng thái: ${comic['status'] ?? ''}'), if('${comic['reviewNotes'] ?? ''}'.isNotEmpty) Text('Ghi chú cũ: ${comic['reviewNotes']}'), const SizedBox(height:8), Wrap(spacing:8,runSpacing:4,children:[OutlinedButton.icon(onPressed:()=>_preview(comic),icon:const Icon(Icons.visibility_outlined),label:const Text('Xem nội dung')), OutlinedButton(onPressed:()=>_comicAction(comic,'APPROVE'),child:const Text('Duyệt mọi lứa tuổi')), PopupMenuButton<String>(onSelected:(v)=>_comicAction(comic,'AGE_RESTRICT',rating:v), itemBuilder:(_)=>const [PopupMenuItem(value:'13+',child:Text('Giới hạn 13+')),PopupMenuItem(value:'16+',child:Text('Giới hạn 16+')),PopupMenuItem(value:'18+',child:Text('Giới hạn 18+'))], child:const Chip(label:Text('Giới hạn tuổi'))), TextButton(onPressed:()=>_comicAction(comic,'HIDE'),child:const Text('Ẩn')), TextButton(onPressed:()=>_comicAction(comic,'REJECT'),child:const Text('Từ chối'))])])))),
      const SizedBox(height:20), Text('Báo cáo của độc giả (${reports.length})',style:Theme.of(context).textTheme.titleLarge),
      if(reports.isEmpty) const ListTile(title:Text('Không có báo cáo đang mở.')),
      ...reports.map((report) {
        final comicId = report['comicId']?.toString() ?? '?';
        final title = report['comicTitle']?.toString() ?? 'Truyện #$comicId';
        final reason = report['reasonCode']?.toString() ?? '';
        final description = report['description']?.toString() ?? '';
        final status = report['status']?.toString() ?? '';
        return Card(child: ListTile(
          title: Text('$title · $reason'),
          subtitle: Text('$description\nTrạng thái: $status'),
          isThreeLine: true,
          trailing: PopupMenuButton<String>(
            onSelected: (action) => _reportAction(report, action),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'INVESTIGATING', child: Text('Đang xác minh')),
              PopupMenuItem(value: 'RESOLVE', child: Text('Đã xử lý')),
              PopupMenuItem(value: 'DISMISS', child: Text('Bác báo cáo')),
            ],
          ),
        ));
      }),
    ])));
  }
}

class ModerationChapterPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> preview;
  const ModerationChapterPreviewScreen({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final comic = Map<String, dynamic>.from(preview['comic'] as Map? ?? const {});
    final chapter = Map<String, dynamic>.from(preview['chapter'] as Map? ?? const {});
    final pages = (chapter['pages'] as List? ?? const []).map((row) => Map<String, dynamic>.from(row as Map)).toList();
    final token = context.read<AuthViewModel>().currentUser?.token ?? '';
    Map<String, String> headersFor(String url) {
      if (token.isEmpty) return const <String, String>{};
      final target = Uri.tryParse(url);
      final api = Uri.tryParse(ApiConstants.baseUrl);
      if (target == null || api == null || target.scheme != api.scheme || target.host != api.host || target.port != api.port) return const <String, String>{};
      return <String, String>{'Authorization': 'Bearer $token'};
    }
    final coverUrl = ApiConstants.resolveMediaUrl('${comic['coverUrl'] ?? ''}');
    final textContent = '${chapter['contentText'] ?? ''}';
    return Scaffold(
      appBar: AppBar(title: const Text('Đọc nội dung để kiểm duyệt'), actions: [IconButton(tooltip: 'Đăng xuất', onPressed: () => logoutAndReturnToLogin(context), icon: const Icon(Icons.logout))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${comic['title'] ?? 'Không tên'}', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Tác giả: ${comic['author'] ?? ''}'),
        const SizedBox(height: 10),
        Text('Chương ${chapter['chapterNumber'] ?? ''}: ${chapter['title'] ?? ''}', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text('Trạng thái: ${chapter['moderationStatus'] ?? ''} · Độ tuổi tác giả đề xuất: ${chapter['suggestedAgeRating'] ?? 'ALL_AGES'}'),
        if ('${comic['description'] ?? ''}'.trim().isNotEmpty) ...[const SizedBox(height: 10), Text('${comic['description']}')],
        if (coverUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Ảnh bìa tham khảo', style: TextStyle(fontWeight: FontWeight.bold)),
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 220), child: Image.network(coverUrl, headers: headersFor(coverUrl), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('Không tải được ảnh bìa.')))),
        ],
        const Divider(height: 28),
        if ('${chapter['contentType'] ?? 'IMAGE'}' == 'TEXT') ...[
          const Text('Nội dung truyện chữ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          if (textContent.trim().isEmpty) const Text('Chương chữ chưa có nội dung.'),
          SelectableText(textContent, style: const TextStyle(height: 1.55, fontSize: 16)),
        ] else ...[
          Text('Nội dung truyện hình (${pages.length} trang)', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          if (pages.isEmpty) const Text('Chưa có trang ảnh để kiểm duyệt.'),
          ...pages.map((page) {
            final url = ApiConstants.resolveMediaUrl('${page['imageUrl'] ?? ''}');
            return Padding(padding: const EdgeInsets.symmetric(vertical: 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Trang ${page['pageNumber'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              if (url.isNotEmpty) Center(child: Image.network(url, width: double.infinity, headers: headersFor(url), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('Không tải được trang ảnh.'))),
            ]));
          }),
        ],
        const SizedBox(height: 16),
        const Text('Hãy đọc/xem toàn bộ nội dung trước khi quyết định độ tuổi và ghi rõ căn cứ khi hạn chế hoặc từ chối.', style: TextStyle(color: Colors.grey, fontSize: 12)),
      ]),
    );
  }
}

class ModerationPreviewScreen extends StatelessWidget {
  final Map<String, dynamic> preview;
  const ModerationPreviewScreen({super.key, required this.preview});

  @override
  Widget build(BuildContext context) {
    final comic = Map<String, dynamic>.from(preview['comic'] as Map? ?? const {});
    final chapters = (preview['chapters'] as List? ?? const [])
        .map((row) => Map<String, dynamic>.from(row as Map)).toList();
    final token = context.read<AuthViewModel>().currentUser?.token ?? '';
    final coverUrl = ApiConstants.resolveMediaUrl('${comic['coverUrl'] ?? ''}');
    Map<String, String> headersFor(String url) {
      if (token.isEmpty) return const <String, String>{};
      final target = Uri.tryParse(url);
      final api = Uri.tryParse(ApiConstants.baseUrl);
      if (target == null || api == null || target.scheme != api.scheme || target.host != api.host || target.port != api.port) {
        // Never forward the user's bearer token to an external image host.
        return const <String, String>{};
      }
      return <String, String>{'Authorization': 'Bearer $token'};
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Xem nội dung kiểm duyệt'), actions: [IconButton(tooltip: 'Đăng xuất', onPressed: () => logoutAndReturnToLogin(context), icon: const Icon(Icons.logout))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${comic['title'] ?? 'Không tên'}', style: Theme.of(context).textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Tác giả: ${comic['author'] ?? ''} · Trạng thái: ${comic['moderationStatus'] ?? ''} · Độ tuổi: ${comic['ageRating'] ?? ''}'),
        if ('${comic['description'] ?? ''}'.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('${comic['description']}'),
        ],
        if (coverUrl.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text('Ảnh bìa', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Center(child: ConstrainedBox(constraints: const BoxConstraints(maxHeight: 280), child: Image.network(coverUrl, headers: headersFor(coverUrl), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('Không tải được ảnh bìa.')))),
        ],
        const SizedBox(height: 18),
        Text('Nội dung chương (${chapters.length})', style: Theme.of(context).textTheme.titleLarge),
        if (chapters.isEmpty) const ListTile(title: Text('Chưa có chương hoặc trang truyện được lưu.')),
        ...chapters.map((chapter) {
          final pages = (chapter['pages'] as List? ?? const []).map((row) => Map<String, dynamic>.from(row as Map)).toList();
          return Card(margin: const EdgeInsets.only(top: 10), child: ExpansionTile(
            initiallyExpanded: chapters.length == 1,
            title: Text('Chương ${chapter['chapterNumber'] ?? ''}: ${chapter['title'] ?? ''}'),
            subtitle: Text('${pages.length} trang'),
            children: [
              if ('${chapter['contentType'] ?? 'IMAGE'}' == 'TEXT' && '${chapter['contentText'] ?? ''}'.trim().isNotEmpty)
                Padding(padding: const EdgeInsets.all(14), child: SelectableText('${chapter['contentText']}')),
              if (pages.isEmpty && '${chapter['contentType'] ?? 'IMAGE'}' != 'TEXT') const ListTile(title: Text('Chương chưa có ảnh trang.')),
              ...pages.map((page) {
                final url = ApiConstants.resolveMediaUrl('${page['imageUrl'] ?? ''}');
                return Padding(padding: const EdgeInsets.fromLTRB(12, 4, 12, 12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Trang ${page['pageNumber'] ?? ''}'),
                  const SizedBox(height: 6),
                  if (url.isNotEmpty) Center(child: Image.network(url, width: double.infinity, headers: headersFor(url), fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Text('Không tải được trang ảnh.'))),
                ]));
              }),
            ],
          ));
        }),
        const SizedBox(height: 14),
      ]),
    );
  }
}

class AdminRoleManagementScreen extends StatefulWidget {
  const AdminRoleManagementScreen({super.key});
  @override
  State<AdminRoleManagementScreen> createState() => _AdminRoleManagementScreenState();
}

class _AdminRoleManagementScreenState extends State<AdminRoleManagementScreen> {
  final TextEditingController _searchController = TextEditingController();
  Timer? _searchDebounce;
  List<Map<String, dynamic>> _users = [];
  bool _loading = true;
  String? _error;
  String _roleFilter = 'ALL';
  int _page = 0;
  int _pageSize = 25;
  int _totalElements = 0;
  int _totalPages = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String _) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 350), () => _load(page: 0));
  }

  Future<void> _load({int? page}) async {
    if (page != null) _page = page;
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final result = await context.read<RemoteDataSource>().getAdminUsersPage(
        search: _searchController.text.trim(),
        role: _roleFilter,
        page: _page,
        size: _pageSize,
      );
      final rows = (result['items'] as List? ?? const [])
          .map((row) => Map<String, dynamic>.from(row as Map))
          .toList();
      final totalPages = int.tryParse('${result['totalPages'] ?? 0}') ?? 0;
      if (rows.isEmpty && totalPages > 0 && _page >= totalPages) {
        await _load(page: totalPages - 1);
        return;
      }
      if (!mounted) return;
      setState(() {
        _users = rows;
        _totalElements = int.tryParse('${result['totalElements'] ?? 0}') ?? 0;
        _totalPages = totalPages;
        _page = int.tryParse('${result['page'] ?? _page}') ?? _page;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _change(Map<String, dynamic> user, String role) async {
    try {
      await context.read<RemoteDataSource>().changeUserRole(
        userId: int.parse('${user['id']}'), role: role,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã cập nhật vai trò.')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không thể đổi vai trò: $e')));
    }
  }

  String _displayRole(dynamic raw) {
    final role = (raw ?? '').toString().toUpperCase();
    return role == 'USER' ? 'READER' : role;
  }

  @override
  Widget build(BuildContext context) {
    final canPrevious = !_loading && _page > 0;
    final canNext = !_loading && _page + 1 < _totalPages;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quản lý tài khoản'),
        actions: [
          IconButton(tooltip: 'Làm mới', onPressed: () => _load(), icon: const Icon(Icons.refresh)),
          IconButton(tooltip: 'Đăng xuất', onPressed: () => logoutAndReturnToLogin(context), icon: const Icon(Icons.logout)),
        ],
      ),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Tìm tài khoản',
              hintText: 'Tên, username hoặc email',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(
                tooltip: 'Xóa tìm kiếm',
                onPressed: () { _searchDebounce?.cancel(); _searchController.clear(); _load(page: 0); },
                icon: const Icon(Icons.close),
              ),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Row(children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _roleFilter,
                decoration: const InputDecoration(labelText: 'Vai trò', border: OutlineInputBorder(), isDense: true),
                items: const [
                  DropdownMenuItem(value: 'ALL', child: Text('Tất cả vai trò')),
                  DropdownMenuItem(value: 'READER', child: Text('Reader')),
                  DropdownMenuItem(value: 'AUTHOR', child: Text('Author')),
                  DropdownMenuItem(value: 'MODERATOR', child: Text('Moderator')),
                ],
                onChanged: (value) { setState(() => _roleFilter = value ?? 'ALL'); _load(page: 0); },
              ),
            ),
            const SizedBox(width: 12),
            DropdownButton<int>(
              value: _pageSize,
              items: const [10, 25, 50, 100].map((size) => DropdownMenuItem(value: size, child: Text('$size / trang'))).toList(),
              onChanged: (value) { if (value != null) { setState(() => _pageSize = value); _load(page: 0); } },
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Align(alignment: Alignment.centerLeft, child: Text('$_totalElements tài khoản', style: Theme.of(context).textTheme.bodyMedium)),
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        if (_error != null)
          Expanded(child: Center(child: Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [Text('Không thể tải tài khoản: $_error', textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: () => _load(), child: const Text('Thử lại'))]))))
        else if (!_loading && _users.isEmpty)
          const Expanded(child: Center(child: Text('Không tìm thấy tài khoản phù hợp.')))
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
              itemCount: _users.length,
              itemBuilder: (context, index) {
                final user = _users[index];
                final role = _displayRole(user['role']);
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: CircleAvatar(child: Icon(role == 'MODERATOR' ? Icons.shield_outlined : role == 'AUTHOR' ? Icons.draw_outlined : Icons.person_outline)),
                    title: Text('${user['name'] ?? user['username'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
                    subtitle: Text('${user['email'] ?? ''}\n@${user['username'] ?? ''} · $role', maxLines: 2, overflow: TextOverflow.ellipsis),
                    isThreeLine: true,
                    trailing: PopupMenuButton<String>(
                      tooltip: 'Thay đổi vai trò',
                      onSelected: (value) => _change(user, value),
                      itemBuilder: (_) => [
                        if (role != 'READER') const PopupMenuItem(value: 'READER', child: Text('Đặt Reader')),
                        if (role != 'MODERATOR') const PopupMenuItem(value: 'MODERATOR', child: Text('Cấp Moderator')),
                      ],
                      child: const Padding(padding: EdgeInsets.all(8), child: Icon(Icons.more_vert)),
                    ),
                  ),
                );
              },
            ),
          ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              IconButton(tooltip: 'Trang trước', onPressed: canPrevious ? () => _load(page: _page - 1) : null, icon: const Icon(Icons.chevron_left)),
              Text(_totalPages == 0 ? 'Trang 0/0' : 'Trang ${_page + 1}/$_totalPages'),
              IconButton(tooltip: 'Trang sau', onPressed: canNext ? () => _load(page: _page + 1) : null, icon: const Icon(Icons.chevron_right)),
            ]),
          ),
        ),
      ]),
    );
  }
}

