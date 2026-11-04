import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Clears the session and every nested route. AppEntry will render AuthScreen
/// because the signed-in user becomes null.
Future<void> logoutAndReturnToLogin(BuildContext context) async {
  // Capture the Navigator before clearing auth: the current page may be
  // replaced by AppEntry as soon as AuthViewModel notifies its listeners.
  final navigator = Navigator.of(context, rootNavigator: true);
  final auth = context.read<AuthViewModel>();
  await auth.logout();
  if (!navigator.mounted) return;
  navigator.popUntil((route) => route.isFirst);
}
