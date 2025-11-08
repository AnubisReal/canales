class Channel {
  final String name;
  final String logoUrl;
  final String streamUrl;
  final String group;
  final String id;

  Channel({
    required this.name,
    required this.logoUrl,
    required this.streamUrl,
    required this.group,
    required this.id,
  });

  factory Channel.fromM3UEntry(String extinf, String url) {
    // Parse EXTINF line: #EXTINF:-1 tvg-logo="..." tvg-id="..." group-title="...", NAME
    final logoMatch = RegExp(r'tvg-logo="([^"]*)"').firstMatch(extinf);
    final idMatch = RegExp(r'tvg-id="([^"]*)"').firstMatch(extinf);
    final groupMatch = RegExp(r'group-title="([^"]*)"').firstMatch(extinf);
    final nameMatch = RegExp(r', (.+)$').firstMatch(extinf);

    // Usar tvg-id como nombre si está disponible (viene limpio sin sufijos)
    // Si no, usar el nombre del M3U
    final tvgId = idMatch?.group(1)?.trim() ?? '';
    final rawName = nameMatch?.group(1)?.trim() ?? 'Canal Desconocido';
    final cleanName = tvgId.isNotEmpty ? tvgId : rawName;

    return Channel(
      name: cleanName,
      logoUrl: logoMatch?.group(1) ?? '',
      streamUrl: url.trim(),
      group: groupMatch?.group(1) ?? 'Sin Categoría',
      id: tvgId,
    );
  }

  // Serialización para favoritos
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'logoUrl': logoUrl,
      'streamUrl': streamUrl,
      'group': group,
      'id': id,
    };
  }

  factory Channel.fromJson(Map<String, dynamic> json) {
    return Channel(
      name: json['name'] as String,
      logoUrl: json['logoUrl'] as String,
      streamUrl: json['streamUrl'] as String,
      group: json['group'] as String,
      id: json['id'] as String,
    );
  }
}
