import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:provider/provider.dart';
import 'core/network/dio_client.dart';
import 'data/datasources/local/local_data_source.dart';
import 'data/datasources/remote/remote_data_source.dart';
import 'data/repositories/comic_repository_impl.dart';
import 'domain/repositories/comic_repository.dart';
import 'domain/usecases/auth_usecases.dart';
import 'domain/usecases/comic_usecases.dart';
import 'domain/usecases/library_usecases.dart';
import 'domain/usecases/offline_usecases.dart';
import 'domain/usecases/payment_usecases.dart';
import 'presentation/screens/auth/auth_screen.dart';
import 'presentation/screens/home/home_screen.dart';
import 'presentation/screens/profile/role_workspace_screen.dart';
import 'presentation/viewmodels/auth_viewmodel.dart';
import 'presentation/viewmodels/home_viewmodel.dart';
import 'presentation/viewmodels/payment_viewmodel.dart';
import 'presentation/viewmodels/profile_offline_viewmodel.dart';
import 'presentation/viewmodels/reader_viewmodel.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const secureStorage = FlutterSecureStorage();
  final local = LocalDataSource();
  final dioClient = DioClient(secureStorage);
  final remote = RemoteDataSource(dioClient);
  final ComicRepository repository = ComicRepositoryImpl(remote: remote, local: local);
  final login = LoginUseCase(repository);
  final register = RegisterUseCase(repository);
  final verifyEmail = VerifyEmailUseCase(repository);
  final becomeAuthor = BecomeAuthorUseCase(repository);
  final refreshCurrentUser = RefreshCurrentUserUseCase(repository);
  final auth = AuthViewModel(loginUseCase: login, registerUseCase: register, verifyEmailUseCase: verifyEmail, becomeAuthorUseCase: becomeAuthor, refreshCurrentUserUseCase: refreshCurrentUser, secureStorage: secureStorage);
  final getComics = GetComicsUseCase(repository);
  final recommendations = GetRecommendationsUseCase(repository);
  final detail = GetComicDetailUseCase(repository);
  final getChapter = GetChapterUseCase(repository);
  final home = HomeViewModel(
    getComicsUseCase: getComics, getRecommendationsUseCase: recommendations,
    getComicDetailUseCase: detail, getChapterUseCase: getChapter,
    getDownloadedChapterUseCase: GetDownloadedChapterUseCase(repository),
    downloadChapterUseCase: DownloadChapterUseCase(repository),
  );
  final getFavorites = GetFavoritesUseCase(repository);
  final toggleFavorite = ToggleFavoriteUseCase(repository);
  final getFollowedAuthors = GetFollowedAuthorsUseCase(repository);
  final toggleFollowAuthor = ToggleFollowAuthorUseCase(repository);
  final getHistory = GetHistoryUseCase(repository);
  final profile = ProfileOfflineViewModel(
    getFavoritesUseCase: getFavorites, toggleFavoriteUseCase: toggleFavorite,
    getFollowedAuthorsUseCase: getFollowedAuthors, toggleFollowAuthorUseCase: toggleFollowAuthor,
    getHistoryUseCase: getHistory, getDownloadsUseCase: GetDownloadedChaptersUseCase(repository), syncPendingChangesUseCase: SyncPendingChangesUseCase(repository),
  );
  final payment = PaymentViewModel(getUnlockedUseCase: GetUnlockedChaptersUseCase(repository), createPaymentUseCase: CreatePaymentUseCase(repository));
  final reader = ReaderViewModel(getChapterUseCase: getChapter, recordReadingUseCase: RecordReadingUseCase(repository));
  await auth.restoreSession();
  await profile.initializeTheme();
  runApp(MultiProvider(providers: [
    Provider<RemoteDataSource>.value(value: remote),
    ChangeNotifierProvider.value(value: auth),
    ChangeNotifierProvider.value(value: home),
    ChangeNotifierProvider.value(value: profile),
    ChangeNotifierProvider.value(value: payment),
    ChangeNotifierProvider.value(value: reader),
  ], child: const SmartComicApp()));
}

class SmartComicApp extends StatelessWidget {
  const SmartComicApp({super.key});
  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileOfflineViewModel>();
    return MaterialApp(
      title: 'Smart Story', debugShowCheckedModeBanner: false,
      themeMode: profile.isDarkMode ? ThemeMode.dark : ThemeMode.light,
      theme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff6f42c1)), useMaterial3: true),
      darkTheme: ThemeData(colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xff8f73d3), brightness: Brightness.dark), useMaterial3: true),
      // Keep one stable root route. Rebuilding this entry point reliably switches
      // between login, reading, and role-specific consoles after login/logout.
      home: const AppEntry(),
    );
  }
}

class AppEntry extends StatelessWidget {
  const AppEntry({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    if (auth.isInitializing) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final user = auth.currentUser;
    if (user == null) return const AuthScreen();

    final role = user.role.toUpperCase();
    if (role == 'ADMIN' || role == 'MODERATOR') {
      return const RoleWorkspaceScreen();
    }
    // AUTHOR intentionally keeps the complete Reader experience; its additional
    // author tools are accessed from the profile's Studio entry.
    return const HomeScreen();
  }
}
