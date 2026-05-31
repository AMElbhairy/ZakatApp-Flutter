class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.name,
    this.photoUrl,
    this.accessToken,
  });

  final String id;
  final String email;
  final String name;
  final String? photoUrl;
  final String? accessToken;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? json['sub'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      photoUrl: (json['photoUrl'] ?? json['picture'])?.toString(),
      accessToken: json['accessToken']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sub': id,
      'email': email,
      'name': name,
      'photoUrl': photoUrl,
      'picture': photoUrl,
      'accessToken': accessToken,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? name,
    String? photoUrl,
    String? accessToken,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}
