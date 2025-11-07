import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/channel.dart';

class FavoritesService {
  static const String _favoritesKey = 'favorite_channels';
  static List<Channel> _favoriteChannels = [];
  static bool _isLoaded = false;

  // Cargar favoritos desde SharedPreferences
  static Future<void> loadFavorites() async {
    if (_isLoaded) return;
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = prefs.getStringList(_favoritesKey) ?? [];
      
      _favoriteChannels = favoritesJson.map((jsonStr) {
        final map = json.decode(jsonStr) as Map<String, dynamic>;
        return Channel.fromJson(map);
      }).toList();
      
      _isLoaded = true;
      print('✅ Favoritos cargados: ${_favoriteChannels.length} canales');
    } catch (e) {
      print('❌ Error al cargar favoritos: $e');
      _favoriteChannels = [];
    }
  }

  // Guardar favoritos en SharedPreferences
  static Future<void> _saveFavorites() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final favoritesJson = _favoriteChannels.map((channel) {
        return json.encode(channel.toJson());
      }).toList();
      
      await prefs.setStringList(_favoritesKey, favoritesJson);
      print('✅ Favoritos guardados: ${_favoriteChannels.length} canales');
    } catch (e) {
      print('❌ Error al guardar favoritos: $e');
    }
  }

  // Verificar si un canal es favorito
  static bool isFavorite(Channel channel) {
    return _favoriteChannels.any((fav) => fav.streamUrl == channel.streamUrl);
  }

  // Añadir canal a favoritos
  static Future<void> addFavorite(Channel channel) async {
    if (!isFavorite(channel)) {
      _favoriteChannels.add(channel);
      await _saveFavorites();
      print('❤️ Canal añadido a favoritos: ${channel.name}');
    }
  }

  // Eliminar canal de favoritos
  static Future<void> removeFavorite(Channel channel) async {
    _favoriteChannels.removeWhere((fav) => fav.streamUrl == channel.streamUrl);
    await _saveFavorites();
    print('💔 Canal eliminado de favoritos: ${channel.name}');
  }

  // Alternar favorito
  static Future<bool> toggleFavorite(Channel channel) async {
    if (isFavorite(channel)) {
      await removeFavorite(channel);
      return false;
    } else {
      await addFavorite(channel);
      return true;
    }
  }

  // Obtener lista de favoritos
  static List<Channel> getFavorites() {
    return List.from(_favoriteChannels);
  }

  // Limpiar todos los favoritos
  static Future<void> clearFavorites() async {
    _favoriteChannels.clear();
    await _saveFavorites();
    print('🗑️ Todos los favoritos eliminados');
  }
}
