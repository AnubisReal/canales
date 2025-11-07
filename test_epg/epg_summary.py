import xml.etree.ElementTree as ET
from collections import defaultdict
from datetime import datetime

def parse_datetime(dt_str):
    """Convierte el formato de fecha del EPG a datetime"""
    # Formato: 20251028075000 +0100
    return datetime.strptime(dt_str[:14], '%Y%m%d%H%M%S')

def analyze_epg():
    print("="*80)
    print("RESUMEN DEL EPG - Guía de Programación")
    print("="*80)
    
    # Leer el XML
    tree = ET.parse('full_epg.xml')
    root = tree.getroot()
    
    # Obtener canales y programas
    channels = root.findall('.//channel')
    programmes = root.findall('.//programme')
    
    print(f"\n📊 ESTADÍSTICAS GENERALES:")
    print(f"   Total de canales: {len(channels)}")
    print(f"   Total de programas: {len(programmes)}")
    
    # Analizar estructura de canales
    print(f"\n\n📺 ESTRUCTURA DE CANALES:")
    print("-"*80)
    
    channel_info = {}
    for channel in channels[:15]:  # Primeros 15 canales
        channel_id = channel.get('id')
        display_names = [dn.text for dn in channel.findall('display-name')]
        icon = channel.find('icon')
        icon_url = icon.get('src') if icon is not None else None
        
        channel_info[channel_id] = {
            'names': display_names,
            'icon': icon_url
        }
        
        print(f"\n🔹 ID: {channel_id}")
        print(f"   Nombres: {', '.join(display_names[:3])}")
        if icon_url:
            print(f"   Icono: {icon_url}")
    
    # Analizar estructura de programas
    print(f"\n\n📅 ESTRUCTURA DE PROGRAMAS:")
    print("-"*80)
    
    for i, programme in enumerate(programmes[:5]):
        channel_id = programme.get('channel')
        start = programme.get('start')
        stop = programme.get('stop')
        
        title = programme.find('title')
        subtitle = programme.find('sub-title')
        desc = programme.find('desc')
        category = programme.find('category')
        icon = programme.find('icon')
        rating = programme.find('rating/value')
        star_rating = programme.find('star-rating/value')
        
        print(f"\n🔸 Programa {i+1}:")
        print(f"   Canal: {channel_id}")
        print(f"   Inicio: {start}")
        print(f"   Fin: {stop}")
        if title is not None:
            print(f"   Título: {title.text}")
        if subtitle is not None:
            print(f"   Subtítulo: {subtitle.text[:80]}...")
        if desc is not None:
            desc_clean = desc.text.split('\n')[0] if desc.text else ""
            print(f"   Descripción: {desc_clean[:80]}...")
        if category is not None:
            print(f"   Categoría: {category.text}")
        if icon is not None:
            print(f"   Poster: {icon.get('src')}")
        if rating is not None:
            print(f"   Rating: {rating.text}")
        if star_rating is not None:
            print(f"   Valoración: {star_rating.text}")
    
    # Estadísticas por canal
    print(f"\n\n📈 PROGRAMAS POR CANAL:")
    print("-"*80)
    
    channel_programme_count = defaultdict(int)
    for programme in programmes:
        channel_id = programme.get('channel')
        channel_programme_count[channel_id] += 1
    
    # Top 20 canales con más programación
    sorted_channels = sorted(channel_programme_count.items(), key=lambda x: x[1], reverse=True)[:20]
    
    for channel_id, count in sorted_channels:
        # Buscar nombre del canal
        channel = root.find(f".//channel[@id='{channel_id}']")
        if channel is not None:
            display_name = channel.find('display-name')
            name = display_name.text if display_name is not None else channel_id
        else:
            name = channel_id
        
        print(f"   {name[:40]:40} - {count:4} programas")
    
    # Información clave para la integración
    print(f"\n\n🔑 INFORMACIÓN CLAVE PARA INTEGRACIÓN:")
    print("-"*80)
    print("\n✅ Cada canal tiene:")
    print("   - ID único (ej: 'La 1 HD', 'Antena 3 HD')")
    print("   - Múltiples display-name (variantes del nombre)")
    print("   - URL del icono/logo")
    
    print("\n✅ Cada programa tiene:")
    print("   - channel: ID del canal al que pertenece")
    print("   - start/stop: Fecha y hora de inicio/fin")
    print("   - title: Título del programa")
    print("   - sub-title: Información adicional (temporada, episodio, categoría)")
    print("   - desc: Descripción detallada")
    print("   - category: Categoría del programa")
    print("   - icon: URL del poster/imagen del programa")
    print("   - rating: Clasificación por edad")
    print("   - star-rating: Valoración (ej: 6.4/10)")
    
    print("\n\n💡 ESTRATEGIA DE ASOCIACIÓN:")
    print("-"*80)
    print("1. Comparar el nombre del canal de tu app con:")
    print("   - El 'id' del canal en el EPG")
    print("   - Los 'display-name' del canal en el EPG")
    print("   - Usar coincidencia parcial o fuzzy matching")
    print("\n2. Una vez asociado, filtrar programas por 'channel' ID")
    print("\n3. Mostrar programación ordenada por 'start' (fecha/hora)")
    print("\n4. Para cada programa mostrar:")
    print("   - Título, descripción, hora inicio/fin")
    print("   - Poster (icon src)")
    print("   - Categoría, rating, valoración")
    
    print("\n" + "="*80)

if __name__ == "__main__":
    analyze_epg()
