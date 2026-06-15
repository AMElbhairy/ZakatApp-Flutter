class UserProfile {
  const UserProfile({
    required this.id,
    required this.email,
    required this.displayName,
    required this.provider,
    this.photoUrl,
    this.accessToken,
  });

  final String id;
  final String email;
  final String displayName;
  final String provider;
  final String? photoUrl;
  final String? accessToken;

  String get name => displayName;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: (json['id'] ?? json['sub'] ?? '').toString(),
      email: (json['email'] ?? '').toString(),
      displayName: (json['displayName'] ?? json['name'] ?? '').toString(),
      provider: (json['provider'] ?? 'google').toString(),
      photoUrl: (json['photoUrl'] ?? json['picture'])?.toString(),
      accessToken: json['accessToken']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'sub': id,
      'email': email,
      'displayName': displayName,
      'name': displayName,
      'provider': provider,
      'photoUrl': photoUrl,
      'picture': photoUrl,
      'accessToken': accessToken,
    };
  }

  UserProfile copyWith({
    String? id,
    String? email,
    String? displayName,
    String? provider,
    String? photoUrl,
    String? accessToken,
  }) {
    return UserProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      provider: provider ?? this.provider,
      photoUrl: photoUrl ?? this.photoUrl,
      accessToken: accessToken ?? this.accessToken,
    );
  }
}
