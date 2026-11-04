import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../domain/entities/comic_entity.dart';
import '../../viewmodels/auth_viewmodel.dart';
import '../../navigation/auth_navigation.dart';
import '../../viewmodels/home_viewmodel.dart';
import '../../viewmodels/payment_viewmodel.dart';
import '../../viewmodels/profile_offline_viewmodel.dart';
import '../../widgets/comic_tiles.dart';
import '../detail/comic_detail_screen.dart';
import '../reader/reader_screen.dart';
import '../profile/feature_center_screen.dart';
import '../profile/author_studio_screen.dart';
import '../profile/author_workspace_screens.dart';
import '../profile/author_feedback_read_state.dart';
import '../../../data/datasources/remote/remote_data_source.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;
  int _shelfTab = 0;
  int _followingTab = 0;
  String _selectedGenre = 'Tất cả';
  String _selectedFormat = 'Truyện tranh';
  bool _started = false;
  bool _hasUnreadAuthorFeedback = false;
  Set<int> _unreadAuthorFeedbackComicIds = <int>{};
  Timer? _authorFeedbackTimer;

  static const _genres = ['Tất cả', 'Hành động', 'Trinh thám', 'Lãng mạn', 'Fantasy', 'Học đường', 'Hài hước', 'Phiêu lưu', 'Đời thường'];
  static const _formats = ['Truyện tranh', 'Tiểu thuyết', 'Truyện chat'];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
      // Refresh the author's unread-feedback badge periodically while the app is open.
      _authorFeedbackTimer = Timer.periodic(const Duration(seconds: 45), (_) {
        if (!mounted) return;
        final user = context.read<AuthViewModel>().currentUser;
        if (user != null && user.role.toUpperCase() == 'AUTHOR') {
          _refreshAuthorFeedbackBadge(user.id, user.role);
        }
      });
    }
  }

  @override
  void dispose() {
    _authorFeedbackTimer?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    final user = context.read<AuthViewModel>().currentUser;
    if (user == null) return;
    final profile = context.read<ProfileOfflineViewModel>();
    await profile.loadUserData(user.id);
    if (!mounted) return;
    await context.read<HomeViewModel>().loadHomeData(
      userId: user.id,
      interactedIds: {...profile.favoriteIds, ...profile.history.map((item) => item.comicId)}.toList(),
    );
    if (!mounted) return;
    await _refreshAuthorFeedbackBadge(user.id, user.role);
    if (!mounted) return;
    await context.read<PaymentViewModel>().loadUnlocked(user.id);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final home = context.watch<HomeViewModel>();
    final profile = context.watch<ProfileOfflineViewModel>();
    final pages = [
      _buildRecommendations(context, home, user.id),
      _buildCategories(context, home, user.id),
      _buildFollowing(context, home, profile, user.id),
      _buildShelf(context, home, profile, user.id),
      _buildMe(context, home, profile, user.name, user.username, user.email, user.birthDate, user.gender, user.id),
    ];
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (index) async {
          setState(() => _tab = index);
          if (index == 2 || index == 3) await profile.loadUserData(user.id);
          if (index == 0 || index == 1) await home.loadHomeData(userId: user.id, interactedIds: {...profile.favoriteIds, ...profile.history.map((item) => item.comicId)}.toList());
          if (index == 4 && user.role.toUpperCase() == 'AUTHOR') await _refreshAuthorFeedbackBadge(user.id, user.role);
        },
        destinations: [
          const NavigationDestination(icon: Icon(Icons.auto_awesome_outlined), selectedIcon: Icon(Icons.auto_awesome), label: 'Đề xuất'),
          const NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view_rounded), label: 'Phân loại'),
          const NavigationDestination(icon: Icon(Icons.favorite_border), selectedIcon: Icon(Icons.favorite), label: 'Theo dõi'),
          const NavigationDestination(icon: Icon(Icons.local_library_outlined), selectedIcon: Icon(Icons.local_library), label: 'Tủ sách'),
          NavigationDestination(icon: _tabBadge(Icons.person_outline, _hasUnreadAuthorFeedback && user.role.toUpperCase() == 'AUTHOR'), selectedIcon: _tabBadge(Icons.person, _hasUnreadAuthorFeedback && user.role.toUpperCase() == 'AUTHOR'), label: 'Tôi'),
        ],
      ),
    );
  }

  Widget _buildRecommendations(BuildContext context, HomeViewModel vm, int userId) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(children: [Icon(Icons.auto_stories_rounded, color: Color(0xff7947bd)), SizedBox(width: 8), Text('Smart Story', style: TextStyle(fontWeight: FontWeight.w800))]),
        actions: [IconButton(tooltip: 'Đồng bộ', onPressed: _load, icon: const Icon(Icons.sync))],
      ),
      body: RefreshIndicator(onRefresh: _load, child: ListView(padding: const EdgeInsets.fromLTRB(16, 4, 16, 28), children: [
        TextField(onChanged: vm.updateQuery, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Tìm truyện, tác giả, từ khóa...', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none))),
        const SizedBox(height: 16),
        Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff42206f), Color(0xff8a5ac4)]), borderRadius: BorderRadius.circular(22)), child: Row(children: [
          const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('MỞ RA THẾ GIỚI CỦA BẠN', style: TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.bold)), SizedBox(height: 8), Text('Một câu chuyện mới\nđang chờ bạn.', style: TextStyle(color: Colors.white, fontSize: 22, height: 1.15, fontWeight: FontWeight.w800)), SizedBox(height: 8), Text('Đề xuất theo gu đọc của bạn', style: TextStyle(color: Colors.white70))])),
          SizedBox(width: 92, height: 120, child: DecoratedBox(decoration: BoxDecoration(color: Colors.white.withOpacity(.13), borderRadius: BorderRadius.circular(18)), child: Icon(Icons.auto_awesome, size: 58, color: Colors.amber.shade200))),
        ])),
        const SizedBox(height: 22),
        const _SectionHeading(title: 'Khám phá thể loại', subtitle: 'Tìm đúng thế giới bạn yêu thích'),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 8, children: [
          ActionChip(avatar: const Icon(Icons.bolt, size: 17), label: const Text('Hành động'), onPressed: () => _openCategory('Hành động')),
          ActionChip(avatar: const Icon(Icons.favorite_border, size: 17), label: const Text('Lãng mạn'), onPressed: () => _openCategory('Lãng mạn')),
          ActionChip(avatar: const Icon(Icons.search, size: 17), label: const Text('Trinh thám'), onPressed: () => _openCategory('Trinh thám')),
          ActionChip(avatar: const Icon(Icons.auto_awesome, size: 17), label: const Text('Fantasy'), onPressed: () => _openCategory('Fantasy')),
          ActionChip(avatar: const Icon(Icons.school_outlined, size: 17), label: const Text('Học đường'), onPressed: () => _openCategory('Học đường')),
        ]),
        const SizedBox(height: 24),
        if (vm.isLoading) const LinearProgressIndicator(),
        if (vm.error != null && vm.comics.isEmpty) _errorPanel(vm.error!, _load),
        if (vm.recommendations.isNotEmpty) ...[
          const _SectionHeading(title: 'Dành riêng cho bạn', subtitle: 'Gợi ý dựa trên hoạt động đọc'),
          const SizedBox(height: 12),
          SizedBox(height: 218, child: ListView.separated(scrollDirection: Axis.horizontal, itemCount: vm.recommendations.length, separatorBuilder: (_, __) => const SizedBox(width: 12), itemBuilder: (_, i) => RecommendationCard(comic: vm.recommendations[i], onTap: () => _openComic(context, vm.recommendations[i], userId)))),
          const SizedBox(height: 24),
        ],
        const _SectionHeading(title: 'Đang được quan tâm', subtitle: 'Những bộ truyện độc giả đang khám phá'),
        const SizedBox(height: 12),
        if (vm.filteredComics.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(24), child: Text('Chưa có truyện phù hợp. Hãy thử tải lại dữ liệu.'))),
        ...vm.filteredComics.map((comic) => ComicTile(comic: comic, onTap: () => _openComic(context, comic, userId))),
      ])),
    );
  }

  Widget _buildCategories(BuildContext context, HomeViewModel vm, int userId) {
    final showsComicList = _selectedFormat == 'Truyện tranh';
    final items = _selectedGenre == 'Tất cả' ? vm.comics : vm.comics.where((comic) => comic.tags.any((tag) => tag.toLowerCase() == _selectedGenre.toLowerCase()) || comic.title.toLowerCase().contains(_selectedGenre.toLowerCase())).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('Phân loại'), actions: [IconButton(onPressed: _load, icon: const Icon(Icons.sync))]),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(onChanged: vm.updateQuery, decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Tên truyện, chủ đề, tác giả', filled: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none))),
        const SizedBox(height: 18),
        const Text('Định dạng nội dung', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        Wrap(spacing: 8, children: _formats.map((format) => ChoiceChip(label: Text(format), selected: _selectedFormat == format, onSelected: (_) { setState(() => _selectedFormat = format); })).toList()),
        const SizedBox(height: 20),
        if (showsComicList) ...[
          const Text('Thể loại', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Wrap(spacing: 8, runSpacing: 8, children: _genres.map((genre) => FilterChip(label: Text(genre), selected: _selectedGenre == genre, onSelected: (_) { setState(() => _selectedGenre = genre); })).toList()),
          const SizedBox(height: 18),
          Text('Kết quả (${items.where((c) => vm.query.trim().isEmpty || c.title.toLowerCase().contains(vm.query.toLowerCase()) || c.author.toLowerCase().contains(vm.query.toLowerCase()) || c.tags.any((t) => t.toLowerCase().contains(vm.query.toLowerCase()))).length})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
          const SizedBox(height: 8),
          ...items.where((c) => vm.query.trim().isEmpty || c.title.toLowerCase().contains(vm.query.toLowerCase()) || c.author.toLowerCase().contains(vm.query.toLowerCase()) || c.tags.any((t) => t.toLowerCase().contains(vm.query.toLowerCase()))).map((comic) => ComicTile(comic: comic, onTap: () => _openComic(context, comic, userId))),
        ] else ...[
          Container(padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(20)), child: Column(children: [Icon(_selectedFormat == 'Tiểu thuyết' ? Icons.menu_book : Icons.chat_bubble_outline, size: 44, color: const Color(0xff7947bd)), const SizedBox(height: 12), Text('Không gian ${_selectedFormat.toLowerCase()}', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('Đã có giao diện và công cụ lưu bản nháp. Danh sách tác phẩm đã xuất bản cần được bổ sung mô hình Story/Episode và API trên backend.', textAlign: TextAlign.center), const SizedBox(height: 12), FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StoryDraftScreen(storyType: _selectedFormat == 'Tiểu thuyết' ? 'Tiểu thuyết' : 'Truyện chat'))), child: const Text('Thử sáng tác bản nháp'))])),
        ],
      ]),
    );
  }

  Widget _buildFollowing(BuildContext context, HomeViewModel home, ProfileOfflineViewModel profile, int userId) {
    final followedComics = home.comics.where((comic) => profile.favoriteIds.contains(comic.id)).toList();
    final followedAuthors = profile.followedAuthors.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return Scaffold(
      appBar: AppBar(
        title: const Text('Theo dõi'),
        actions: [IconButton(tooltip: 'Làm mới dữ liệu', onPressed: _load, icon: const Icon(Icons.sync))],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 28), children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xff44236d), Color(0xff8b5bc2)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(children: [
              const Icon(Icons.favorite_rounded, color: Colors.white, size: 35),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Thế giới bạn yêu thích', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 4),
                Text('${followedComics.length} truyện · ${followedAuthors.length} tác giả đang theo dõi', style: const TextStyle(color: Colors.white70, fontSize: 12)),
              ])),
            ]),
          ),
          const SizedBox(height: 18),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment<int>(value: 0, icon: Icon(Icons.favorite_border), label: Text('Truyện yêu thích')),
              ButtonSegment<int>(value: 1, icon: Icon(Icons.person_outline), label: Text('Tác giả')),
            ],
            selected: {_followingTab},
            onSelectionChanged: (selection) => setState(() => _followingTab = selection.first),
          ),
          const SizedBox(height: 18),
          if (profile.isSyncing) const LinearProgressIndicator(),
          if (_followingTab == 0) ...[
            const _SectionHeading(title: 'Truyện yêu thích', subtitle: 'Những bộ truyện bạn đã lưu bằng biểu tượng trái tim'),
            const SizedBox(height: 10),
            if (followedComics.isEmpty)
              _emptyCard(Icons.favorite_border, 'Chưa có truyện yêu thích', 'Mở chi tiết một bộ truyện và chạm biểu tượng trái tim để thêm vào danh sách.'),
            ...followedComics.map((comic) => ComicTile(comic: comic, onTap: () => _openComic(context, comic, userId))),
          ] else ...[
            const _SectionHeading(title: 'Tác giả đang theo dõi', subtitle: 'Theo dõi tác giả để tìm lại các tác phẩm của họ nhanh hơn'),
            const SizedBox(height: 10),
            if (followedAuthors.isEmpty)
              _emptyCard(Icons.person_search_outlined, 'Bạn chưa theo dõi tác giả nào', 'Mở một truyện, nhấn Theo dõi bên cạnh tên tác giả để cập nhật danh sách này.'),
            ...followedAuthors.map((author) {
              final works = home.comics.where((comic) => comic.author.trim().toLowerCase() == author.trim().toLowerCase()).toList();
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ExpansionTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xffefe5ff),
                    child: Text(author.trim().isEmpty ? '?' : author.trim().substring(0, 1).toUpperCase(), style: const TextStyle(color: Color(0xff5a338b), fontWeight: FontWeight.bold)),
                  ),
                  title: Text(author, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('${works.length} tác phẩm trong thư viện'),
                  trailing: IconButton(
                    tooltip: 'Bỏ theo dõi tác giả',
                    icon: const Icon(Icons.person_remove_alt_1_outlined),
                    onPressed: () async {
                      await profile.toggleFollowAuthor(userId, author);
                      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Đã bỏ theo dõi $author.')));
                    },
                  ),
                  children: [
                    if (works.isEmpty)
                      const Padding(padding: EdgeInsets.all(16), child: Text('Chưa có tác phẩm của tác giả này trong danh sách truyện hiện tại.')),
                    ...works.map((comic) => ComicTile(comic: comic, onTap: () => _openComic(context, comic, userId))),
                  ],
                ),
              );
            }),
          ],
        ]),
      ),
    );
  }

  Widget _buildShelf(BuildContext context, HomeViewModel home, ProfileOfflineViewModel profile, int userId) {
    final favorites = home.comics.where((comic) => profile.favoriteIds.contains(comic.id)).toList();
    return Scaffold(appBar: AppBar(title: const Text('Tủ sách của tôi'), actions: [IconButton(tooltip: 'Đồng bộ', onPressed: () => profile.loadUserData(userId), icon: const Icon(Icons.sync))]), body: RefreshIndicator(onRefresh: () => profile.loadUserData(userId), child: ListView(padding: const EdgeInsets.all(16), children: [
      SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
        _ShelfChip(label: 'Đang đọc', selected: _shelfTab == 0, onTap: () => setState(() => _shelfTab = 0)),
        _ShelfChip(label: 'Yêu thích', selected: _shelfTab == 1, onTap: () => setState(() => _shelfTab = 1)),
        _ShelfChip(label: 'Tải offline', selected: _shelfTab == 2, onTap: () => setState(() => _shelfTab = 2)),
        _ShelfChip(label: 'Lịch sử', selected: _shelfTab == 3, onTap: () => setState(() => _shelfTab = 3)),
      ])),
      const SizedBox(height: 18),
      if (_shelfTab == 0) ...[
        const _SectionHeading(title: 'Tiếp tục đọc', subtitle: 'Quay lại nơi bạn dừng lại'),
        if (profile.history.isEmpty) _emptyCard(Icons.history, 'Chưa có lịch sử đọc', 'Mở truyện và đọc ít nhất một trang để lưu tiến độ.'),
        ...profile.history.take(20).map((item) {
          final ComicEntity? comic = _findComic(home.comics, item.comicId);
          return ListTile(leading: const CircleAvatar(child: Icon(Icons.menu_book_outlined)), title: Text(comic?.title ?? 'Truyện #${item.comicId}'), subtitle: Text('Chương ${item.chapterNumber} · Trang ${item.pageNumber}'), trailing: const Icon(Icons.chevron_right), onTap: comic == null ? null : () => _openComic(context, comic, userId));
        }),
      ] else if (_shelfTab == 1) ...[
        const _SectionHeading(title: 'Yêu thích', subtitle: 'Danh sách đồng bộ theo tài khoản'),
        if (favorites.isEmpty) _emptyCard(Icons.favorite_border, 'Tủ yêu thích đang trống', 'Chạm trái tim trong trang chi tiết truyện để lưu lại.'),
        ...favorites.map((comic) => ComicTile(comic: comic, onTap: () => _openComic(context, comic, userId))),
      ] else if (_shelfTab == 2) ...[
        const _SectionHeading(title: 'Đọc offline', subtitle: 'Chương lưu trên thiết bị này'),
        if (profile.downloads.isEmpty) _emptyCard(Icons.download_for_offline_outlined, 'Chưa tải chương nào', 'Vào chi tiết truyện và chọn tải chương để đọc khi mất mạng.'),
        ...profile.downloads.map((row) => ListTile(leading: const Icon(Icons.offline_pin, color: Colors.green), title: Text(row.comicTitle), subtitle: Text('Chương ${row.chapterNumber}: ${row.chapterTitle}'), trailing: const Icon(Icons.play_arrow), onTap: () async {
          try {
            final chapter = await home.loadDownloadedChapter(row.chapterId);
            if (chapter == null || !context.mounted) return;
            final comic = _findComic(home.comics, row.comicId) ?? ComicEntity(id: row.comicId, title: row.comicTitle, author: 'Đang cập nhật', description: '', coverUrl: '');
            await Navigator.push(context, MaterialPageRoute(builder: (_) => ReaderScreen(comic: comic, chapter: chapter, userId: userId)));
            if (context.mounted) await profile.loadUserData(userId);
          } catch (e) { if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Không mở được bản offline: $e'))); }
        })),
      ] else ...[
        const _SectionHeading(title: 'Lịch sử đọc', subtitle: 'Tiến độ đọc được đồng bộ khi có mạng'),
        if (profile.history.isEmpty) _emptyCard(Icons.history, 'Chưa có lịch sử', 'Lịch sử đọc sẽ được thêm sau khi bạn đọc truyện.'),
        ...profile.history.map((item) => ListTile(leading: const Icon(Icons.history), title: Text(_findComic(home.comics, item.comicId)?.title ?? 'Truyện #${item.comicId}'), subtitle: Text('Chương ${item.chapterNumber} · Trang ${item.pageNumber}'))),
      ],
    ])),
    );
  }

  Widget _buildMe(BuildContext context, HomeViewModel home, ProfileOfflineViewModel profile, String name, String username, String email, String birthDate, String gender, int userId) {
    final displayName = name.isNotEmpty ? name : username;
    final role = (context.watch<AuthViewModel>().currentUser?.role ?? 'READER').toUpperCase();
    return Scaffold(appBar: AppBar(title: const Text('Tôi'), actions: [
      IconButton(tooltip: 'Hộp tin nhắn', onPressed: () => _open(context, const InboxScreen()), icon: const Icon(Icons.mark_email_unread_outlined)),
      IconButton(tooltip: 'Cài đặt', onPressed: () => _openSettings(context, profile, userId), icon: const Icon(Icons.settings_outlined)),
    ]), body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 28), children: [
      Container(padding: const EdgeInsets.all(18), decoration: BoxDecoration(gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff35205e), Color(0xff8154ba)]), borderRadius: BorderRadius.circular(22)), child: Column(children: [
        Row(children: [CircleAvatar(radius: 31, backgroundColor: Colors.white, child: Text(profile.avatarEmoji, style: const TextStyle(fontSize: 30))), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(displayName, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)), if (username.isNotEmpty) Text('@$username', style: const TextStyle(color: Colors.white70)), Text(email, style: const TextStyle(color: Colors.white70, fontSize: 12)), if (birthDate.isNotEmpty || gender.isNotEmpty) Text([if (birthDate.isNotEmpty) 'Ngày sinh: $birthDate', if (gender.isNotEmpty) gender].join(' · '), style: const TextStyle(color: Colors.white70, fontSize: 11))])), const Icon(Icons.chevron_right, color: Colors.white70)]),
        const SizedBox(height: 18),
        Row(children: [Expanded(child: _ProfileStat(value: '${profile.favoriteIds.length + profile.followedAuthors.length}', label: 'Theo dõi')), Expanded(child: _ProfileStat(value: '${profile.history.length}', label: 'Lần đọc')), Expanded(child: _ProfileStat(value: 'Lv.${1 + profile.history.length ~/ 5}', label: 'Cấp độ'))]),
        const SizedBox(height: 12),
        Align(alignment: Alignment.centerLeft, child: Text('Vai trò: $role · Thành viên Smart Story', style: const TextStyle(color: Colors.white70, fontSize: 12))),
      ])),
      const SizedBox(height: 22),
      _SectionHeading(
        title: 'Sáng tác & phát triển',
        subtitle: role == 'AUTHOR'
            ? 'Quản lý tác phẩm và tương tác độc giả'
            : 'Đăng ký trở thành tác giả để bắt đầu sáng tác',
      ),
      const SizedBox(height: 12),
      GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 1.32,
        children: [
          if (role == 'AUTHOR') ...[
            _ProfileMenuCard(
              icon: Icons.people_alt_outlined,
              title: 'Người theo dõi',
              subtitle: 'Độc giả quan tâm đến bạn',
              onTap: () => _open(context, const AuthorFollowersScreen()),
            ),
            _ProfileMenuCard(
              icon: Icons.analytics_outlined,
              title: 'Thống kê truyện',
              subtitle: 'Lượt đọc, bình luận, đánh giá',
              onTap: () => _open(context, const AuthorStatisticsScreen()),
            ),
            _ProfileMenuCard(
              icon: Icons.draw_outlined,
              title: 'Studio tác giả',
              subtitle: 'Quản lý truyện và chương',
              showDot: _unreadAuthorFeedbackComicIds.isNotEmpty,
              onTap: () => _open(context, const AuthorStudioScreen()),
            ),
            _ProfileMenuCard(
              icon: Icons.fact_check_outlined,
              title: 'Trạng thái duyệt',
              subtitle: 'Theo dõi chương chờ duyệt',
              onTap: () => _open(context, const AuthorModerationStatusScreen()),
            ),
          ] else ...[
            if (role == 'READER' || role == 'USER')
              _ProfileMenuCard(
                icon: Icons.draw_outlined,
                title: 'Trở thành tác giả',
                subtitle: 'Đăng ký hồ sơ tác giả',
                onTap: () => _open(context, const AuthorApplicationScreen()),
              ),
            _ProfileMenuCard(
              icon: Icons.card_giftcard_outlined,
              title: 'Phúc lợi',
              subtitle: 'Điểm danh và phiếu đọc',
              onTap: () => _open(context, const DailyPerksScreen()),
            ),
          ],
        ],
      ),
      if (role == 'AUTHOR') ...[
        const SizedBox(height: 18),
        const _SectionHeading(title: 'Bản nháp của tôi', subtitle: 'Bản nháp lưu trên thiết bị'),
        const SizedBox(height: 8),
        _FeatureListTile(icon: Icons.menu_book_outlined, title: 'Bản nháp tiểu thuyết', subtitle: 'Tiếp tục viết tiểu thuyết', onTap: () => _open(context, const StoryDraftScreen(storyType: 'Tiểu thuyết'))),
        _FeatureListTile(icon: Icons.chat_bubble_outline, title: 'Bản nháp truyện chat', subtitle: 'Tiếp tục viết truyện chat', onTap: () => _open(context, const StoryDraftScreen(storyType: 'Truyện chat'))),
      ],
      const SizedBox(height: 22),
      const _SectionHeading(title: 'Tài nguyên độc giả', subtitle: 'Vật phẩm và thành tích của bạn'),
      const SizedBox(height: 10),
      _FeatureListTile(icon: Icons.confirmation_num_outlined, title: 'Phiếu đọc truyện', subtitle: 'Xem số phiếu demo', onTap: () => _open(context, const DailyPerksScreen())),
      _FeatureListTile(icon: Icons.face_retouching_natural_outlined, title: 'Trung tâm Avatar', subtitle: 'Chọn hình đại diện', onTap: () => _open(context, const AvatarCenterScreen())),
      _FeatureListTile(icon: Icons.workspace_premium_outlined, title: 'Danh hiệu fan', subtitle: 'Sưu tập danh hiệu theo hoạt động', onTap: () => _open(context, const FeatureInfoScreen(title: 'Danh hiệu fan', icon: Icons.workspace_premium_outlined, description: 'Tôn vinh những độc giả đồng hành lâu dài.', details: ['Fan mới — bắt đầu hành trình đọc', 'Người theo dõi — lưu truyện yêu thích', 'Độc giả chăm chỉ — duy trì lịch sử đọc', 'Danh hiệu thật cần được tính từ dữ liệu máy chủ.']))),
      _FeatureListTile(icon: Icons.mode_comment_outlined, title: 'Bình luận của tôi', subtitle: 'Ý kiến và đánh giá trên truyện', onTap: () => _open(context, const FeatureInfoScreen(title: 'Bình luận của tôi', icon: Icons.mode_comment_outlined, description: 'Bình luận và đánh giá được lưu trên máy chủ, hiển thị tại trang chi tiết từng truyện.', details: ['Mở chi tiết truyện để đọc bình luận và đánh giá.', 'Tài khoản có thể cập nhật đánh giá của mình cho từng truyện.']))),
      _FeatureListTile(icon: Icons.trending_up, title: 'Level của tôi', subtitle: 'Tiến độ hoạt động', onTap: () => _open(context, FeatureInfoScreen(title: 'Level của tôi', icon: Icons.trending_up, description: 'Cấp độ minh họa dựa trên lịch sử đọc hiện tại.', details: ['Số lần đọc đã ghi: ${profile.history.length}', 'Số truyện yêu thích: ${profile.favoriteIds.length}', 'Level và điểm thưởng chính thức nên được tính trên máy chủ.']))),
      const SizedBox(height: 12),
      const _SectionHeading(title: 'Trợ giúp', subtitle: 'Chúng tôi luôn muốn nghe ý kiến của bạn'),
      const SizedBox(height: 8),
      _FeatureListTile(icon: Icons.feedback_outlined, title: 'Phản hồi ý kiến', subtitle: 'Báo lỗi hoặc góp ý chức năng', onTap: () => _open(context, const FeedbackScreen())),
      _FeatureListTile(icon: Icons.info_outline, title: 'Giới thiệu chúng tôi', subtitle: 'Về Smart Story', onTap: () => _open(context, const FeatureInfoScreen(title: 'Giới thiệu Smart Story', icon: Icons.auto_stories_rounded, description: 'Không gian đọc và sáng tác truyện trên di động.', details: ['Gợi ý truyện theo sở thích', 'Theo dõi, tủ sách và đọc offline', 'Không gian sáng tác tiểu thuyết và truyện chat', 'Bản đồ chức năng đang được phát triển trong đồ án.']))),
      const SizedBox(height: 18),
      OutlinedButton.icon(onPressed: () => logoutAndReturnToLogin(context), icon: const Icon(Icons.logout), label: const Text('Đăng xuất')),
    ]));
  }

  void _openCategory(String genre) {
    setState(() { _tab = 1; _selectedGenre = genre; _selectedFormat = 'Truyện tranh'; });
  }

  Future<void> _openSettings(BuildContext context, ProfileOfflineViewModel profile, int userId) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => AppSettingsScreen(
      isDarkMode: profile.isDarkMode,
      onDarkModeChanged: profile.toggleDarkMode,
      onSync: () => profile.loadUserData(userId),
      onLogout: () => logoutAndReturnToLogin(context),
    )));
  }

  Widget _tabBadge(IconData icon, bool showDot) => Stack(clipBehavior: Clip.none, children: [
    Icon(icon),
    if (showDot) Positioned(right: -2, top: -2, child: Container(width: 9, height: 9, decoration: BoxDecoration(color: Colors.red, shape: BoxShape.circle, border: Border.all(color: Theme.of(context).colorScheme.surface, width: 1.5)))),
  ]);

  Future<void> _refreshAuthorFeedbackBadge(int userId, String role) async {
    if (role.toUpperCase() != 'AUTHOR') {
      if (mounted) setState(() { _hasUnreadAuthorFeedback = false; _unreadAuthorFeedbackComicIds = <int>{}; });
      return;
    }
    try {
      final dashboard = await context.read<RemoteDataSource>().getAuthorDashboard();
      final stats = (dashboard['comicStatistics'] as List? ?? const []).map((row) => Map<String, dynamic>.from(row as Map)).toList();
      final unread = <int>{};
      for (final item in stats) {
        final id = int.tryParse('${item['comicId']}');
        if (id != null && await AuthorFeedbackReadState.hasUnread(userId, id, item)) unread.add(id);
      }
      if (mounted) setState(() { _unreadAuthorFeedbackComicIds = unread; _hasUnreadAuthorFeedback = unread.isNotEmpty; });
    } catch (_) {
      // Keep the last known badge if the server is temporarily unavailable.
    }
  }

  Future<void> _open(BuildContext context, Widget page) async {
    await Navigator.push<void>(context, MaterialPageRoute<void>(builder: (_) => page));
    if (!mounted) return;
    final user = context.read<AuthViewModel>().currentUser;
    if (user != null && user.role.toUpperCase() == 'AUTHOR') await _refreshAuthorFeedbackBadge(user.id, user.role);
  }

  Widget _errorPanel(String error, Future<void> Function() retry) => Padding(padding: const EdgeInsets.symmetric(vertical: 24), child: Column(children: [const Icon(Icons.cloud_off, size: 48), const SizedBox(height: 8), Text(error, textAlign: TextAlign.center), const SizedBox(height: 10), OutlinedButton.icon(onPressed: retry, icon: const Icon(Icons.refresh), label: const Text('Thử kết nối lại'))]));

  Widget _emptyCard(IconData icon, String title, String subtitle) => Container(margin: const EdgeInsets.symmetric(vertical: 10), padding: const EdgeInsets.all(22), decoration: BoxDecoration(color: Theme.of(context).colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(18)), child: Column(children: [Icon(icon, size: 38, color: const Color(0xff8054b7)), const SizedBox(height: 10), Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 6), Text(subtitle, textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey))]));

  ComicEntity? _findComic(List<ComicEntity> comics, int id) { for (final comic in comics) { if (comic.id == id) return comic; } return null; }

  void _openComic(BuildContext context, ComicEntity comic, int userId) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => ComicDetailScreen(comic: comic, userId: userId)));
  }
}

class _SectionHeading extends StatelessWidget {
  final String title;
  final String? subtitle;
  const _SectionHeading({required this.title, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
        if (subtitle != null) ...[
          const SizedBox(height: 3),
          Text(subtitle!, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        ],
      ],
    );
  }
}

class _ShelfChip extends StatelessWidget {
  final String label; final bool selected; final VoidCallback onTap;
  const _ShelfChip({required this.label, required this.selected, required this.onTap});
  @override
  Widget build(BuildContext context) => Padding(padding: const EdgeInsets.only(right: 8), child: ChoiceChip(label: Text(label), selected: selected, onSelected: (_) => onTap()));
}

class _ProfileStat extends StatelessWidget {
  final String value; final String label;
  const _ProfileStat({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)), const SizedBox(height: 3), Text(label, style: const TextStyle(color: Colors.white70, fontSize: 11))]);
}

class _PrimaryActionCard extends StatelessWidget {
  final IconData icon; final String label; final Color color; final VoidCallback onTap;
  const _PrimaryActionCard({required this.icon, required this.label, required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => InkWell(onTap: onTap, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.all(14), decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)), child: Row(children: [Icon(icon, color: const Color(0xff4a2a78)), const SizedBox(width: 10), Expanded(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xff39214f))))])));
}

class _ProfileMenuCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool showDot;

  const _ProfileMenuCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.showDot = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const accent = Color(0xff7a4ab5);
    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: accent.withOpacity(.12)),
            color: accent.withOpacity(.035),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(.11),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        alignment: Alignment.center,
                        child: Icon(icon, color: accent, size: 23),
                      ),
                      if (showDot)
                        Positioned(
                          right: -3,
                          top: -3,
                          child: Container(
                            width: 11,
                            height: 11,
                            decoration: BoxDecoration(
                              color: Colors.red,
                              shape: BoxShape.circle,
                              border: Border.all(color: theme.colorScheme.surface, width: 1.5),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_outward_rounded, size: 17, color: theme.colorScheme.onSurfaceVariant.withOpacity(.65)),
                ],
              ),
              const SizedBox(height: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(subtitle, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 11, height: 1.25), maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureListTile extends StatelessWidget {
  final IconData icon; final String title; final String subtitle; final VoidCallback onTap;
  const _FeatureListTile({required this.icon, required this.title, required this.subtitle, required this.onTap});
  @override
  Widget build(BuildContext context) => Card(margin: const EdgeInsets.only(bottom: 6), child: ListTile(leading: Icon(icon, color: const Color(0xff7545ad)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)), subtitle: Text(subtitle), trailing: const Icon(Icons.chevron_right), onTap: onTap));
}

class AppSettingsScreen extends StatefulWidget {
  final bool isDarkMode;
  final ValueChanged<bool> onDarkModeChanged;
  final Future<void> Function() onSync;
  final Future<void> Function() onLogout;
  const AppSettingsScreen({super.key, required this.isDarkMode, required this.onDarkModeChanged, required this.onSync, required this.onLogout});
  @override
  State<AppSettingsScreen> createState() => _AppSettingsScreenState();
}
class _AppSettingsScreenState extends State<AppSettingsScreen> {
  late bool _dark;
  bool _syncing = false;
  @override
  void initState() { super.initState(); _dark = widget.isDarkMode; }
  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: const Text('Cài đặt')), body: ListView(padding: const EdgeInsets.all(16), children: [
    const FeatureBanner(icon: Icons.tune_outlined, title: 'Cá nhân hóa trải nghiệm', subtitle: 'Điều chỉnh giao diện và dữ liệu ứng dụng.'),
    const SizedBox(height: 16),
    SwitchListTile(title: const Text('Chế độ tối'), subtitle: const Text('Dễ đọc trong môi trường thiếu sáng'), secondary: const Icon(Icons.dark_mode_outlined), value: _dark, onChanged: (v) { setState(() => _dark = v); widget.onDarkModeChanged(v); }),
    ListTile(leading: const Icon(Icons.sync), title: const Text('Đồng bộ tủ sách'), subtitle: const Text('Đẩy thao tác chờ và tải lịch sử trên máy chủ'), trailing: _syncing ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.chevron_right), onTap: _syncing ? null : () async { setState(() => _syncing = true); await widget.onSync(); if (mounted) { setState(() => _syncing = false); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã chạy yêu cầu đồng bộ.'))); } }),
    const Divider(),
    const ListTile(leading: Icon(Icons.privacy_tip_outlined), title: Text('Quyền riêng tư'), subtitle: Text('Ngày sinh và danh xưng được lưu trong hồ sơ tài khoản.')),
    const ListTile(leading: Icon(Icons.notifications_outlined), title: Text('Thông báo'), subtitle: Text('Cần bổ sung dịch vụ thông báo đẩy ở giai đoạn tiếp theo.')),
    const SizedBox(height: 16), OutlinedButton.icon(onPressed: () async { await widget.onLogout(); }, icon: const Icon(Icons.logout), label: const Text('Đăng xuất')),
  ]));
}
