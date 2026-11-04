import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../viewmodels/auth_viewmodel.dart';

/// Adds the session token only to media served by this application's API origin.
/// External cover URLs never receive the bearer token.
Map<String, String> secureMediaHeaders(BuildContext context, String imageUrl) {
  final token = context.read<AuthViewModel>().currentUser?.token ?? '';
  if (token.isEmpty) return const <String, String>{};

  final media = Uri.tryParse(ApiConstants.resolveMediaUrl(imageUrl));
  final api = Uri.tryParse(ApiConstants.baseUrl);
  if (media == null || api == null ||
      media.scheme != api.scheme || media.host != api.host || media.port != api.port) {
    return const <String, String>{};
  }
  return <String, String>{'Authorization': 'Bearer $token'};
}
