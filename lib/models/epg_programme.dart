import 'package:xml/xml.dart';

class EpgProgramme {
  final String channelId;
  final DateTime start;
  final DateTime stop;
  final String title;
  final String? subtitle;
  final String? description;
  final String? category;
  final String? iconUrl;
  final String? rating;
  final String? starRating;

  EpgProgramme({
    required this.channelId,
    required this.start,
    required this.stop,
    required this.title,
    this.subtitle,
    this.description,
    this.category,
    this.iconUrl,
    this.rating,
    this.starRating,
  });

  factory EpgProgramme.fromXml(XmlElement programmeElement) {
    final channelId = programmeElement.getAttribute('channel') ?? '';
    final startStr = programmeElement.getAttribute('start') ?? '';
    final stopStr = programmeElement.getAttribute('stop') ?? '';
    
    final start = _parseEpgDateTime(startStr);
    final stop = _parseEpgDateTime(stopStr);
    
    final titleElement = programmeElement.findElements('title').firstOrNull;
    var title = titleElement?.innerText ?? 'Sin título';
    
    // Limpiar códigos de color del título
    title = _cleanColorCodes(title);
    
    final subtitleElement = programmeElement.findElements('sub-title').firstOrNull;
    var subtitle = subtitleElement?.innerText;
    if (subtitle != null) {
      subtitle = _cleanColorCodes(subtitle);
    }
    
    final descElement = programmeElement.findElements('desc').firstOrNull;
    var description = descElement?.innerText;
    if (description != null) {
      description = _cleanColorCodes(description);
    }
    
    final categoryElement = programmeElement.findElements('category').firstOrNull;
    final category = categoryElement?.innerText;
    
    final iconElement = programmeElement.findElements('icon').firstOrNull;
    final iconUrl = iconElement?.getAttribute('src');
    
    final ratingElement = programmeElement.findElements('rating').firstOrNull;
    final ratingValue = ratingElement?.findElements('value').firstOrNull?.innerText;
    
    final starRatingElement = programmeElement.findElements('star-rating').firstOrNull;
    final starRatingValue = starRatingElement?.findElements('value').firstOrNull?.innerText;
    
    return EpgProgramme(
      channelId: channelId,
      start: start,
      stop: stop,
      title: title,
      subtitle: subtitle,
      description: description,
      category: category,
      iconUrl: iconUrl,
      rating: ratingValue,
      starRating: starRatingValue,
    );
  }

  static DateTime _parseEpgDateTime(String dateTimeStr) {
    try {
      // Formato: 20251028075000 +0100
      if (dateTimeStr.length >= 14) {
        final year = int.parse(dateTimeStr.substring(0, 4));
        final month = int.parse(dateTimeStr.substring(4, 6));
        final day = int.parse(dateTimeStr.substring(6, 8));
        final hour = int.parse(dateTimeStr.substring(8, 10));
        final minute = int.parse(dateTimeStr.substring(10, 12));
        final second = int.parse(dateTimeStr.substring(12, 14));
        
        return DateTime(year, month, day, hour, minute, second);
      }
    } catch (e) {
      // Si hay error, devolver fecha actual
    }
    return DateTime.now();
  }

  static String _cleanColorCodes(String text) {
    // Eliminar códigos de color [COLOR xxx] y [/COLOR]
    return text
        .replaceAll(RegExp(r'\[COLOR\s+\w+\]'), '')
        .replaceAll('[/COLOR]', '')
        .trim();
  }

  bool get isLive {
    final now = DateTime.now();
    return now.isAfter(start) && now.isBefore(stop);
  }

  bool get isUpcoming {
    final now = DateTime.now();
    return now.isBefore(start);
  }

  bool get isPast {
    final now = DateTime.now();
    return now.isAfter(stop);
  }

  Duration get duration {
    return stop.difference(start);
  }

  Duration? get timeUntilStart {
    final now = DateTime.now();
    if (isUpcoming) {
      return start.difference(now);
    }
    return null;
  }

  Duration? get timeRemaining {
    final now = DateTime.now();
    if (isLive) {
      return stop.difference(now);
    }
    return null;
  }

  Map<String, dynamic> toJson() {
    return {
      'channelId': channelId,
      'start': start.toIso8601String(),
      'stop': stop.toIso8601String(),
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'category': category,
      'iconUrl': iconUrl,
      'rating': rating,
      'starRating': starRating,
    };
  }

  factory EpgProgramme.fromJson(Map<String, dynamic> json) {
    return EpgProgramme(
      channelId: json['channelId'] as String,
      start: DateTime.parse(json['start'] as String),
      stop: DateTime.parse(json['stop'] as String),
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      description: json['description'] as String?,
      category: json['category'] as String?,
      iconUrl: json['iconUrl'] as String?,
      rating: json['rating'] as String?,
      starRating: json['starRating'] as String?,
    );
  }
}
