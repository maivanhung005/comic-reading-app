import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../viewmodels/auth_viewmodel.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _name = TextEditingController();
  final _username = TextEditingController();
  final _code = TextEditingController();
  final _birthDateText = TextEditingController();
  bool _register = false;
  bool _verifyMode = false;
  bool _hidePassword = true;
  bool _acceptedTerms = false;
  DateTime? _birthDate;
  String? _gender;
  String? _successMessage;

  @override
  void dispose() {
    _email.dispose(); _password.dispose(); _name.dispose(); _username.dispose(); _code.dispose(); _birthDateText.dispose();
    super.dispose();
  }

  Future<void> _pickBirthDate() async {
    FocusScope.of(context).unfocus();
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 18, now.month, now.day),
      firstDate: DateTime(1900),
      lastDate: now,
      helpText: 'Chọn ngày sinh',
    );
    if (picked != null && mounted) {
      setState(() {
        _birthDate = picked;
        _birthDateText.text = '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year.toString().padLeft(4, '0')}';
      });
    }
  }

  DateTime? _parseBirthDate(String value) {
    if (!RegExp(r'^\d{2}/\d{2}/\d{4}$').hasMatch(value)) return null;
    final parts = value.split('/');
    final day = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    final year = int.tryParse(parts[2]);
    if (day == null || month == null || year == null) return null;
    final parsed = DateTime(year, month, day);
    if (parsed.year != year || parsed.month != month || parsed.day != day || parsed.isAfter(DateTime.now())) return null;
    return parsed;
  }

  void _showSocialSetupMessage(String provider) {
    final message = provider == 'khôi phục mật khẩu'
        ? 'Khôi phục mật khẩu qua email cần được cấu hình trong phần dịch vụ tài khoản.'
        : 'Đăng nhập $provider chưa hoạt động vì dự án chưa cấu hình OAuth/Firebase.';
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), duration: const Duration(seconds: 4)));
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<AuthViewModel>();
    final title = _verifyMode ? 'XÁC MINH EMAIL' : _register ? 'TẠO TÀI KHOẢN' : 'CHÀO MỪNG BẠN';
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xff21104a), Color(0xff4a2788), Color(0xff17152b)])),
        child: SafeArea(child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 460), child: Card(
            elevation: 12, clipBehavior: Clip.antiAlias, child: Padding(
              padding: const EdgeInsets.all(24), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Container(width: 82, height: 82, decoration: BoxDecoration(color: const Color(0xfff1eaff), borderRadius: BorderRadius.circular(26)), child: const Icon(Icons.auto_stories_rounded, size: 48, color: Color(0xff6f42c1))),
                const SizedBox(height: 16),
                Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w800, letterSpacing: .5)),
                if (_successMessage != null && !_verifyMode && !_register) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: Colors.green.withOpacity(.08), borderRadius: BorderRadius.circular(8)),
                    child: Row(children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text(_successMessage!, style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600))),
                    ]),
                  ),
                ],
                if (_verifyMode || !_register) ...[
                  const SizedBox(height: 8),
                  Text(
                    _verifyMode ? 'Nhập mã 6 chữ số đã được gửi đến email của bạn.' : 'Khám phá truyện tranh, tiểu thuyết và truyện chat.',
                    textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
                SizedBox(height: _register && !_verifyMode ? 16 : 24),
                if (_verifyMode) ...[
                  Text('Email: ${_email.text.trim()}', style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  TextField(controller: _code, keyboardType: TextInputType.number, maxLength: 6, decoration: const InputDecoration(labelText: 'Mã xác minh', prefixIcon: Icon(Icons.verified_user_outlined), border: OutlineInputBorder())),
                  const SizedBox(height: 8),
                ] else ...[
                  if (_register) ...[
                    TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Tên hiển thị', prefixIcon: Icon(Icons.badge_outlined), border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(controller: _username, decoration: const InputDecoration(labelText: 'Tên đăng nhập', prefixIcon: Icon(Icons.alternate_email), border: OutlineInputBorder())),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _birthDateText,
                      keyboardType: TextInputType.number,
                      inputFormatters: [DayMonthYearInputFormatter()],
                      onChanged: (value) => setState(() => _birthDate = _parseBirthDate(value)),
                      decoration: InputDecoration(
                        labelText: 'Ngày/Tháng/Năm *',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        suffixIcon: IconButton(tooltip: 'Chọn ngày sinh', onPressed: _pickBirthDate, icon: const Icon(Icons.calendar_month_outlined)),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: _gender,
                      decoration: const InputDecoration(labelText: 'Danh xưng *', prefixIcon: Icon(Icons.wc_outlined), border: OutlineInputBorder()),
                      items: const [DropdownMenuItem(value: 'Nam', child: Text('Nam')), DropdownMenuItem(value: 'Nữ', child: Text('Nữ')), DropdownMenuItem(value: 'Khác', child: Text('Khác')), DropdownMenuItem(value: 'Không muốn tiết lộ', child: Text('Không muốn tiết lộ'))],
                      onChanged: (value) => setState(() => _gender = value),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    autocorrect: false,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      labelText: _register ? 'Email' : 'Tên đăng nhập / Email',
                      prefixIcon: Icon(_register ? Icons.email_outlined : Icons.person_outline),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(controller: _password, obscureText: _hidePassword, decoration: InputDecoration(labelText: 'Mật khẩu', helperText: _register ? 'Tối thiểu 12 ký tự' : null, prefixIcon: const Icon(Icons.lock_outline), suffixIcon: IconButton(icon: Icon(_hidePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => _hidePassword = !_hidePassword)), border: const OutlineInputBorder())),
                  if (_register) ...[
                    const SizedBox(height: 8),
                    CheckboxListTile(contentPadding: EdgeInsets.zero, value: _acceptedTerms, onChanged: (v) => setState(() => _acceptedTerms = v ?? false), title: const Text('Tôi đồng ý với điều khoản và chính sách riêng tư', style: TextStyle(fontSize: 12)), controlAffinity: ListTileControlAffinity.leading),
                  ],
                  if (!_register) Align(alignment: Alignment.centerRight, child: TextButton(onPressed: () => _showSocialSetupMessage('khôi phục mật khẩu'), child: const Text('Quên mật khẩu?'))),
                ],
                if (vm.error != null) ...[const SizedBox(height: 10), Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(.08), borderRadius: BorderRadius.circular(8)), child: Text(vm.error!, style: const TextStyle(color: Colors.red)))],
                const SizedBox(height: 16),
                FilledButton(
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16), backgroundColor: const Color(0xff6f42c1)),
                  onPressed: vm.isLoading ? null : () async {
                    final auth = context.read<AuthViewModel>();
                    if (_verifyMode) {
                      final ok = await auth.verifyEmail(_email.text.trim(), _code.text.trim());
                      if (!mounted) return;
                      if (ok) {
                        setState(() {
                          _verifyMode = false;
                          _register = false;
                          _password.clear();
                          _code.clear();
                          _successMessage = 'Đăng ký thành công! Email đã xác minh. Vui lòng đăng nhập.';
                        });
                        auth.clearError();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đăng ký thành công! Vui lòng đăng nhập.')));
                      }
                    } else if (_register) {
                      if (_name.text.trim().isEmpty || _username.text.trim().isEmpty || _birthDate == null || _gender == null || _email.text.trim().isEmpty || _password.text.length < 12 || !_acceptedTerms) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng kiểm tra thông tin bắt buộc, mật khẩu tối thiểu 12 ký tự và điều khoản.')));
                        return;
                      }
                      final ok = await auth.register(name: _name.text.trim(), username: _username.text.trim(), email: _email.text.trim(), password: _password.text, birthDate: '${_birthDate!.year.toString().padLeft(4, '0')}-${_birthDate!.month.toString().padLeft(2, '0')}-${_birthDate!.day.toString().padLeft(2, '0')}', gender: _gender!);
                      if (!mounted) return;
                      if (ok) {
                        setState(() {
                          _verifyMode = true;
                          _code.clear();
                          _successMessage = null;
                        });
                        auth.clearError();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi mã xác minh email. Nhập mã 6 chữ số để hoàn tất đăng ký.')));
                      }
                    } else {
                      await auth.login(_email.text.trim(), _password.text);
                    }
                  },
                  child: vm.isLoading ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(_verifyMode ? 'XÁC MINH EMAIL' : _register ? 'ĐĂNG KÝ' : 'ĐĂNG NHẬP'),
                ),
                if (!_verifyMode && !_register) ...[
                  const SizedBox(height: 16),
                  Row(children: [Expanded(child: Divider(color: Colors.grey.shade400)), Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text('HOẶC', style: TextStyle(color: Colors.grey.shade600, fontSize: 12))), Expanded(child: Divider(color: Colors.grey.shade400))]),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(onPressed: () => _showSocialSetupMessage('Google'), icon: const Icon(Icons.g_mobiledata, size: 28), label: const Text('Tiếp tục với Google')),
                  OutlinedButton.icon(onPressed: () => _showSocialSetupMessage('Facebook'), icon: const Icon(Icons.facebook, color: Color(0xff1877f2)), label: const Text('Tiếp tục với Facebook')),
                ],
                // If SMTP delivered the message but the HTTP response timed out, the account
                // may already be created. Let the user move to verification instead of making
                // them submit the same registration form again (which would be a duplicate).
                if (_register && !_verifyMode && vm.error != null && _email.text.trim().isNotEmpty) ...[
                  const SizedBox(height: 4),
                  OutlinedButton.icon(
                    onPressed: vm.isLoading ? null : () {
                      context.read<AuthViewModel>().clearError();
                      setState(() { _verifyMode = true; _code.clear(); });
                    },
                    icon: const Icon(Icons.verified_user_outlined),
                    label: const Text('Đã nhận mã? Nhập mã xác minh'),
                  ),
                ],
                if (!_verifyMode) TextButton(onPressed: vm.isLoading ? null : () {
                  context.read<AuthViewModel>().clearError();
                  setState(() { _register = !_register; _verifyMode = false; _successMessage = null; });
                }, child: Text(_register ? 'Đã có tài khoản? Đăng nhập' : 'Chưa có tài khoản? Đăng ký ngay')),
                if (_verifyMode) TextButton(onPressed: vm.isLoading ? null : () {
                  context.read<AuthViewModel>().clearError();
                  setState(() { _verifyMode = false; _register = true; });
                }, child: const Text('Quay lại biểu mẫu đăng ký')),
              ]),
            ),
          )),
        ))),
      ),
    );
  }
}

/// Formats numeric input as dd/MM/yyyy while the user types.
class DayMonthYearInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final selectionOffset = newValue.selection.extentOffset.clamp(0, newValue.text.length).toInt();
    final digitsBeforeCursor = newValue.text.substring(0, selectionOffset).replaceAll(RegExp(r'\D'), '').length;
    final digitsOnly = newValue.text.replaceAll(RegExp(r'\D'), '');
    final digits = digitsOnly.length > 8 ? digitsOnly.substring(0, 8) : digitsOnly;
    var formatted = digits;
    if (digits.length > 4) {
      formatted = '${digits.substring(0, 2)}/${digits.substring(2, 4)}/${digits.substring(4)}';
    } else if (digits.length > 2) {
      formatted = '${digits.substring(0, 2)}/${digits.substring(2)}';
    }
    final keptDigitsBeforeCursor = digitsBeforeCursor.clamp(0, digits.length).toInt();
    final insertedSlashes = (keptDigitsBeforeCursor > 2 ? 1 : 0) + (keptDigitsBeforeCursor > 4 ? 1 : 0);
    final cursor = (keptDigitsBeforeCursor + insertedSlashes).clamp(0, formatted.length).toInt();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: cursor),
      composing: TextRange.empty,
    );
  }
}

