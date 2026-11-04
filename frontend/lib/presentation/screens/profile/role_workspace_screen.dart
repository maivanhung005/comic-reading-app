import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../data/datasources/remote/remote_data_source.dart';
import '../../viewmodels/auth_viewmodel.dart';
import 'feature_center_screen.dart';
import '../../navigation/auth_navigation.dart';

/// Dedicated landing space for Moderator and Admin. Reader routes are not
/// exposed from these operational consoles.
class RoleWorkspaceScreen extends StatefulWidget {
  const RoleWorkspaceScreen({super.key});

  @override
  State<RoleWorkspaceScreen> createState() => _RoleWorkspaceScreenState();
}

class _RoleWorkspaceScreenState extends State<RoleWorkspaceScreen> {
  bool _loading = true;
  String? _error;
  int _userCount = 0;
  int _moderatorCount = 0;
  List<Map<String, dynamic>> _comics = [];
  List<Map<String, dynamic>> _reports = [];

  String get _role => (context.read<AuthViewModel>().currentUser?.role ?? '').toUpperCase();
  bool get _isAdmin => _role == 'ADMIN';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (mounted) setState(() { _loading = true; _error = null; });
    try {
      final api = context.read<RemoteDataSource>();
      final queue = await api.getModerationQueue();
      final comics = (queue['comics'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      final reports = (queue['reports'] as List? ?? const []).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      var userCount = 0;
      var moderatorCount = 0;
      if (_isAdmin) {
        final summary = await api.getAdminSummary();
        userCount = int.tryParse('${summary['totalUsers'] ?? 0}') ?? 0;
        moderatorCount = int.tryParse('${summary['moderatorCount'] ?? 0}') ?? 0;
      }
      if (!mounted) return;
      setState(() { _comics = comics; _reports = reports; _userCount = userCount; _moderatorCount = moderatorCount; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openModeration() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ModeratorDashboardScreen())).then((_) => _load());
  }

  void _openRoleManagement() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const AdminRoleManagementScreen())).then((_) => _load());
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final user = auth.currentUser;
    final role = (user?.role ?? '').toUpperCase();
    if (user == null || (role != 'ADMIN' && role != 'MODERATOR')) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final isAdmin = role == 'ADMIN';
    final title = isAdmin ? 'Bảng điều khiển Admin' : 'Trung tâm Moderator';
    final subtitle = isAdmin
        ? 'Quản trị tài khoản, phân quyền và giám sát kiểm duyệt Smart Story.'
        : 'Xử lý hàng chờ truyện, báo cáo vi phạm và giới hạn độ tuổi.';

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: [IconButton(tooltip: 'Làm mới dữ liệu', onPressed: _load, icon: const Icon(Icons.refresh)), IconButton(tooltip: 'Đăng xuất', onPressed: () => logoutAndReturnToLogin(context), icon: const Icon(Icons.logout))]),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 30), children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(gradient: LinearGradient(colors: isAdmin ? const [Color(0xff202a44), Color(0xff4e5b82)] : const [Color(0xff4b2b72), Color(0xff8154ba)]), borderRadius: BorderRadius.circular(22)),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [Icon(isAdmin ? Icons.admin_panel_settings : Icons.fact_check_outlined, size: 34, color: Colors.white), const Spacer(), Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5), decoration: BoxDecoration(color: Colors.white.withOpacity(.15), borderRadius: BorderRadius.circular(30)), child: Text(role, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, letterSpacing: 1)))]),
              const SizedBox(height: 14),
              Text('Xin chào, ${user.name.isNotEmpty ? user.name : user.username}', style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              Text(subtitle, style: const TextStyle(color: Colors.white70, height: 1.4)),
            ]),
          ),
          const SizedBox(height: 20),
          Text(isAdmin ? 'Tổng quan hệ thống' : 'Tổng quan kiểm duyệt', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (_loading) const LinearProgressIndicator(),
          if (!_loading && _error != null) Card(child: Padding(padding: const EdgeInsets.all(14), child: Column(children: [Text('Chưa tải được dữ liệu từ Backend: $_error', textAlign: TextAlign.center), const SizedBox(height: 8), OutlinedButton(onPressed: _load, child: const Text('Thử lại'))]))),
          if (!_loading && _error == null) GridView.count(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 1.6, children: [
            _MetricCard(icon: Icons.pending_actions, title: 'Truyện chờ duyệt', value: '${_comics.length}', color: Colors.orange),
            _MetricCard(icon: Icons.flag_outlined, title: 'Báo cáo mở', value: '${_reports.length}', color: Colors.redAccent),
            if (isAdmin) _MetricCard(icon: Icons.people_alt_outlined, title: 'Tài khoản', value: '$_userCount', color: Colors.blue),
            if (isAdmin) _MetricCard(icon: Icons.shield_outlined, title: 'Moderator', value: '$_moderatorCount', color: Colors.deepPurple),
          ]),
          const SizedBox(height: 20),
          Text('Công cụ quản lý', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _WorkspaceAction(icon: Icons.fact_check_outlined, title: 'Trung tâm kiểm duyệt', subtitle: 'Duyệt truyện, xem nội dung, xử lý báo cáo và đánh giá độ tuổi', onTap: _openModeration),
          if (isAdmin) ...[
            const SizedBox(height: 10),
            _WorkspaceAction(icon: Icons.manage_accounts_outlined, title: 'Quản trị tài khoản', subtitle: 'Cấp hoặc thu hồi quyền Moderator; đưa tài khoản về Reader', onTap: _openRoleManagement),
          ],
        ]),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const _MetricCard({required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Icon(icon, color: color, size: 25), const Spacer(), Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)), Text(title, style: Theme.of(context).textTheme.bodySmall, maxLines: 2, overflow: TextOverflow.ellipsis)])));
}

class _WorkspaceAction extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  const _WorkspaceAction({required this.icon, required this.title, required this.subtitle, required this.onTap});

  @override
  Widget build(BuildContext context) => Card(child: ListTile(onTap: onTap, leading: CircleAvatar(child: Icon(icon)), title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle), isThreeLine: true, trailing: const Icon(Icons.chevron_right)));
}
