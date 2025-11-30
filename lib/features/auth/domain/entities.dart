class UserEntity {
  final int id;
  final String firstName;
  final String lastName;
  final String email;

  UserEntity({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.email,
  });

  factory UserEntity.fromJson(Map<String, dynamic> json) {
    return UserEntity(
      id: json["id"],
      firstName: json["firstName"],
      lastName: json["lastName"],
      email: json["email"],
    );
  }
}
