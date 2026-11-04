import '../repositories/comic_repository.dart';

class GetUnlockedChaptersUseCase { final ComicRepository repository; GetUnlockedChaptersUseCase(this.repository); Future<Set<int>> call(int userId) => repository.getUnlockedChapterIds(userId); }
class CreatePaymentUseCase {
  final ComicRepository repository;
  CreatePaymentUseCase(this.repository);
  Future<bool> call({required int userId, required int chapterId, required int amount, required String method}) =>
      repository.createPayment(userId: userId, chapterId: chapterId, amount: amount, method: method);
}
