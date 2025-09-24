import 'package:flutter/material.dart';
import 'package:mail_push_app/models/event_all_model.dart';

class EventCard extends StatelessWidget {
  final Event event;

  const EventCard({Key? key, required this.event}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListTile(
        leading: SizedBox(
          width: 60,
          height: 60,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.asset(
              event.image,
              fit: BoxFit.cover,
            ),
          ),
        ),
        title: Text(
          event.title,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(event.date),
            Text(event.location),
          ],
        ),
        trailing: Text(
          event.price,
          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple),
        ),
      ),
    );
  }
}
