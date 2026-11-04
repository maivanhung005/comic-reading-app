import '../../domain/entities/user_entity.dart';

class UserModel extends UserEntity {
  const UserModel({
    required super.id,
    required super.email,
    required super.name,
    required super.avatar,
    super.username,
    super.birthDate,
    super.gender,
    super.role,
    super.token,
  });

  factory UserModel.fromAuthResponse(Map<String, dynamic> responseData) {
    final rawUser = Map<String, dynamic>.from(responseData['user'] as Map);
    final rawRole = (rawUser['role'] ?? 'READER').toString().trim().toUpperCase();
    return UserModel(
      id: _int(rawUser['id']),
      email: (rawUser['email'] ?? '').toString(),
      name: (rawUser['name'] ?? '').toString(),
      username: (rawUser['username'] ?? '').toString(),
      birthDate: (rawUser['birthDate'] ?? '').toString(),
      gender: (rawUser['gender'] ?? '').toString(),
      avatar: (rawUser['avatar'] ?? '').toString(),
      role: rawRole == 'USER' ? 'READER' : rawRole,
      token: (responseData['token'] ?? '').toString(),
    );
  }

  static int _int(dynamic value) => value is int ? value : int.tryParse('$value') ?? 0;
}
