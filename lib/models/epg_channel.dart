import 'package:xml/xml.dart';

class EpgChannel {
  final String id;
  final List<String> displayNames;
  final String? iconUrl;

  EpgChannel({
    required this.id,
    required this.displayNames,
    this.iconUrl,
  });

  factory EpgChannel.fromXml(XmlElement channelElement) {
    final id = channelElement.getAttribute('id') ?? '';
    
    final displayNameElements = channelElement.findElements('display-name');
    final displayNames = displayNameElements
        .map((e) => e.innerText)
        .where((text) => text.isNotEmpty)
        .toList();
    
    final iconElement = channelElement.findElements('icon').firstOrNull;
    final iconUrl = iconElement?.getAttribute('src');
    
    return EpgChannel(
      id: id,
      displayNames: displayNames,
      iconUrl: iconUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'displayNames': displayNames,
      'iconUrl': iconUrl,
    };
  }

  factory EpgChannel.fromJson(Map<String, dynamic> json) {
    return EpgChannel(
      id: json['id'] as String,
      displayNames: List<String>.from(json['displayNames'] as List),
      iconUrl: json['iconUrl'] as String?,
    );
  }
}
