class VideoPlayer {
  final String id;
  final String name;
  final String packageName;
  final String? icon;
  final bool isInstalled;

  VideoPlayer({
    required this.id,
    required this.name,
    required this.packageName,
    this.icon,
    this.isInstalled = false,
  });

  // Reproductores conocidos y populares
  static final List<VideoPlayer> knownPlayers = [
    VideoPlayer(
      id: 'ask',
      name: 'Preguntar siempre',
      packageName: '',
      isInstalled: true, // Siempre disponible
    ),
    VideoPlayer(
      id: 'acestream',
      name: 'Ace Stream',
      packageName: 'org.acestream.media',
    ),
    VideoPlayer(
      id: 'acestream_engine',
      name: 'Ace Stream Engine',
      packageName: 'org.acestream.engine',
    ),
    VideoPlayer(
      id: 'acestream_player',
      name: 'Ace Stream Player',
      packageName: 'org.acestream.media.atv',
    ),
    VideoPlayer(
      id: 'vlc',
      name: 'VLC',
      packageName: 'org.videolan.vlc',
    ),
    VideoPlayer(
      id: 'mx_player',
      name: 'MX Player',
      packageName: 'com.mxtech.videoplayer.ad',
    ),
    VideoPlayer(
      id: 'mx_player_pro',
      name: 'MX Player Pro',
      packageName: 'com.mxtech.videoplayer.pro',
    ),
    VideoPlayer(
      id: 'kodi',
      name: 'Kodi',
      packageName: 'org.xbmc.kodi',
    ),
    VideoPlayer(
      id: 'wiseplay',
      name: 'WisePlay',
      packageName: 'com.wiseplay',
    ),
    VideoPlayer(
      id: 'perfect_player',
      name: 'Perfect Player',
      packageName: 'com.niklabs.pp',
    ),
    VideoPlayer(
      id: 'iptv_smarters',
      name: 'IPTV Smarters Pro',
      packageName: 'com.nst.iptvsmarterstvbox',
    ),
    VideoPlayer(
      id: 'ott_navigator',
      name: 'OTT Navigator',
      packageName: 'studio.scillarium.ottnavigator',
    ),
  ];

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'packageName': packageName,
      'icon': icon,
      'isInstalled': isInstalled,
    };
  }

  factory VideoPlayer.fromJson(Map<String, dynamic> json) {
    return VideoPlayer(
      id: json['id'] as String,
      name: json['name'] as String,
      packageName: json['packageName'] as String,
      icon: json['icon'] as String?,
      isInstalled: json['isInstalled'] as bool? ?? false,
    );
  }

  VideoPlayer copyWith({
    String? id,
    String? name,
    String? packageName,
    String? icon,
    bool? isInstalled,
  }) {
    return VideoPlayer(
      id: id ?? this.id,
      name: name ?? this.name,
      packageName: packageName ?? this.packageName,
      icon: icon ?? this.icon,
      isInstalled: isInstalled ?? this.isInstalled,
    );
  }
}
