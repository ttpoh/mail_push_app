class TokenModel {
  final String authToken;
  final String fcmToken;

  TokenModel({required this.authToken, required this.fcmToken});

  Map<String, dynamic> toJson() => {
        'auth_token': authToken,
        'fcm_token': fcmToken,
      };
}