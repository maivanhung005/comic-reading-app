class UserEntity {
  final int id;
  final String email;
  final String name;
  final String username;
  final String birthDate;
  final String gender;
  final String avatar;
  final String role;
  final String token;

  const UserEntity({
    required this.id,
    required this.email,
    required this.name,
    required this.avatar,
    this.username = '',
    this.birthDate = '',
    this.gender = '',
    this.role = 'READER',
    this.token = '',
  });
}
