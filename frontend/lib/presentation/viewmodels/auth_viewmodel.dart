import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/errors/api_exception.dart';
import '../../domain/entities/user_entity.dart';
import '../../domain/usecases/auth_usecases.dart';

class AuthViewModel extends ChangeNotifier {
  final LoginUseCase loginUseCase;
  final RegisterUseCase registerUseCase;
  final VerifyEmailUseCase verifyEmailUseCase;
  final BecomeAuthorUseCase becomeAuthorUseCase;
  final RefreshCurrentUserUseCase refreshCurrentUserUseCase;
  final FlutterSecureStorage secureStorage;

  AuthViewModel({required this.loginUseCase, required this.registerUseCase, required this.verifyEmailUseCase, required this.becomeAuthorUseCase, required this.refreshCurrentUserUseCase, required this.secureStorage});

  UserEntity? _currentUser;
  UserEntity? get currentUser => _currentUser;
  bool _isLoading = false;
  bool get isLoading => _isLoading;
  bool _isInitializing = true;
  bool get isInitializing => _isInitializing;
  String? _error;
  String? get error => _error;

  void clearError() {
    if (_error == null) return;
    _error = null;
    notifyListeners();
  }

  Future<void> restoreSession() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getInt('user_id');
      final email = prefs.getString('user_email');
      final name = prefs.getString('user_name');
      final token = await secureStorage.read(key: 'auth_token');
      if (id != null && email != null && name != null && token != null && token.isNotEmpty) {
        final cachedRole = (prefs.getString('user_role') ?? 'READER').toUpperCase();
        _currentUser = UserEntity(
          id: id, email: email, name: name,
          username: prefs.getString('user_username') ?? '',
          birthDate: prefs.getString('user_birth_date') ?? '',
          gender: prefs.getString('user_gender') ?? '',
          avatar: prefs.getString('user_avatar') ?? '',
          role: cachedRole == 'USER' ? 'READER' : cachedRole, token: token,
        );
        // Refresh role from the server: an Admin role change/revocation should update the UI
        // after session restore, while local cached data remains available if offline.
        try {
          final freshUser = await refreshCurrentUserUseCase();
          if (freshUser.id == id && freshUser.token.isNotEmpty) {
            _currentUser = freshUser;
            await secureStorage.write(key: 'auth_token', value: freshUser.token);
            await prefs.setString('user_email', freshUser.email);
            await prefs.setString('user_name', freshUser.name);
            await prefs.setString('user_username', freshUser.username);
            await prefs.setString('user_birth_date', freshUser.birthDate);
            await prefs.setString('user_gender', freshUser.gender);
            await prefs.setString('user_avatar', freshUser.avatar);
            await prefs.setString('user_role', freshUser.role);
          }
        } catch (error) {
          // A connection failure may be temporary, so retain a cached session offline.
          // A 401 means the JWT is expired/invalid (often because the local JWT_SECRET changed);
          // never keep presenting a stale role screen in that case.
          if (error is ApiException && error.statusCode == 401) {
            for (final key in ['user_id', 'user_email', 'user_name', 'user_username', 'user_birth_date', 'user_gender', 'user_avatar', 'user_role']) {
              await prefs.remove(key);
            }
            await secureStorage.delete(key: 'auth_token');
            _currentUser = null;
          }
        }
      }
    } catch (_) {
      _currentUser = null;
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  Future<bool> login(String identifier, String password) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final user = await loginUseCase(identifier.trim(), password);
      if (user.id <= 0 || user.token.isEmpty) {
        throw const ApiException('Máy chủ không trả về thông tin tài khoản hợp lệ.');
      }
      _currentUser = user;
      await secureStorage.write(key: 'auth_token', value: user.token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', user.id);
      await prefs.setString('user_email', user.email);
      await prefs.setString('user_name', user.name);
      await prefs.setString('user_username', user.username);
      await prefs.setString('user_birth_date', user.birthDate);
      await prefs.setString('user_gender', user.gender);
      await prefs.setString('user_avatar', user.avatar);
      await prefs.setString('user_role', user.role);
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : 'Không thể đăng nhập: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> register({required String name, required String username, required String email, required String password, required String birthDate, required String gender}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await registerUseCase(name: name, username: username, email: email, password: password, birthDate: birthDate, gender: gender);
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : 'Không thể đăng ký: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> verifyEmail(String email, String code) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await verifyEmailUseCase(email, code);
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : 'Không thể xác minh email: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> becomeAuthor({required String penName, required String experience, required bool termsAccepted}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final user = await becomeAuthorUseCase(penName: penName, experience: experience, termsAccepted: termsAccepted);
      if (user.id <= 0 || user.token.isEmpty || user.role.toUpperCase() != 'AUTHOR') {
        throw const ApiException('Máy chủ không trả về quyền tác giả hợp lệ.');
      }
      _currentUser = user;
      await secureStorage.write(key: 'auth_token', value: user.token);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', user.id);
      await prefs.setString('user_email', user.email);
      await prefs.setString('user_name', user.name);
      await prefs.setString('user_username', user.username);
      await prefs.setString('user_birth_date', user.birthDate);
      await prefs.setString('user_gender', user.gender);
      await prefs.setString('user_avatar', user.avatar);
      await prefs.setString('user_role', user.role);
      return true;
    } catch (e) {
      _error = e is ApiException ? e.message : 'Không thể kích hoạt quyền tác giả: $e';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in ['user_id', 'user_email', 'user_name', 'user_username', 'user_birth_date', 'user_gender', 'user_avatar', 'user_role']) {
      await prefs.remove(key);
    }
    await secureStorage.delete(key: 'auth_token');
    _currentUser = null;
    _error = null;
    notifyListeners();
  }
}
