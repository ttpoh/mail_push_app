
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'dart:ui' as ui;
// import 'package:http/http.dart' as http;

// Future<BitmapDescriptor> createCustomMarker(String imageUrl) async {
//   final http.Response response = await http.get(Uri.parse(imageUrl));
//   final ui.Codec codec = await ui.instantiateImageCodec(response.bodyBytes,
//       targetWidth: 100, targetHeight: 100);
//   final ui.FrameInfo frameInfo = await codec.getNextFrame();
//   final ui.Image image = frameInfo.image;

//   final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
//   if (byteData == null) return BitmapDescriptor.defaultMarker;

//   return BitmapDescriptor.fromBytes(byteData.buffer.asUint8List());
// }
