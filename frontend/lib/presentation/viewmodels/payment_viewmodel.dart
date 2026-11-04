import 'package:flutter/foundation.dart';
import '../../domain/entities/comic_entity.dart';
import '../../domain/usecases/payment_usecases.dart';

class PaymentViewModel extends ChangeNotifier {
  final GetUnlockedChaptersUseCase getUnlockedUseCase;
  final CreatePaymentUseCase createPaymentUseCase;
  PaymentViewModel({required this.getUnlockedUseCase, required this.createPaymentUseCase});

  Set<int> _unlockedIds = {};
  Set<int> get unlockedIds => _unlockedIds;
  bool _isProcessing = false;
  bool get isProcessing => _isProcessing;
  String? _error;
  String? get error => _error;

  Future<void> loadUnlocked(int userId) async {
    _unlockedIds = await getUnlockedUseCase(userId);
    notifyListeners();
  }

  bool isUnlocked(ChapterEntity chapter) => !chapter.isVip || _unlockedIds.contains(chapter.id);

  Future<bool> pay({required int userId, required int chapterId, required int amount, required String method}) async {
    _isProcessing = true; _error = null; notifyListeners();
    try {
      final ok = await createPaymentUseCase(userId: userId, chapterId: chapterId, amount: amount, method: method);
      if (ok) {
        _unlockedIds = await getUnlockedUseCase(userId);
        // A successful server payment should normally appear in the list immediately.
        _unlockedIds.add(chapterId);
        return true;
      }
      _error = 'Máy chủ chưa xác nhận thanh toán. Kiểm tra backend và PostgreSQL rồi thử lại.';
      return false;
    } catch (e) {
      _error = 'Không thể xử lý thanh toán: $e';
      return false;
    } finally { _isProcessing = false; notifyListeners(); }
  }
}

