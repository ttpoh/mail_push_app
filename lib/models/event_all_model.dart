// lib/ui_kit/app/model/event_all_model.dart
class Event {
  final String image;     // asset 경로
  final String title;     // 제목
  final String date;      // 날짜/시간 문자열
  final String location;  // 보조 텍스트(발신자 등)
  final String price;     // 오른쪽 강조 텍스트(여기선 'NEW' 등)

  Event({
    required this.image,
    required this.title,
    required this.date,
    required this.location,
    required this.price,
  });
}
