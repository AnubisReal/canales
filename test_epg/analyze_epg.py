import requests
import gzip
import xml.etree.ElementTree as ET
from datetime import datetime

# URL del archivo EPG
EPG_URL = "https://raw.githubusercontent.com/davidmuma/EPG_dobleM/master/guiatv_color.xml.gz"

def download_and_decompress_epg():
    """Descarga y descomprime el archivo EPG"""
    print("Descargando archivo EPG...")
    response = requests.get(EPG_URL)
    
    if response.status_code == 200:
        print("Archivo descargado. Descomprimiendo...")
        decompressed_data = gzip.decompress(response.content)
        return decompressed_data.decode('utf-8')
    else:
        print(f"Error al descargar: {response.status_code}")
        return None

def analyze_epg_structure(xml_content):
    """Analiza la estructura del EPG y muestra información detallada"""
    print("\n" + "="*80)
    print("ANÁLISIS DEL ARCHIVO EPG")
    print("="*80)
    
    root = ET.fromstring(xml_content)
    
    # Información general
    print(f"\nElemento raíz: {root.tag}")
    print(f"Atributos del raíz: {root.attrib}")
    
    # Analizar canales
    channels = root.findall('.//channel')
    print(f"\n📺 TOTAL DE CANALES: {len(channels)}")
    print("\n" + "-"*80)
    print("PRIMEROS 5 CANALES (ejemplo):")
    print("-"*80)
    
    for i, channel in enumerate(channels[:5]):
        print(f"\n🔹 Canal {i+1}:")
        print(f"   ID: {channel.get('id')}")
        
        # Obtener información del canal
        display_name = channel.find('display-name')
        icon = channel.find('icon')
        url = channel.find('url')
        
        if display_name is not None:
            print(f"   Nombre: {display_name.text}")
        if icon is not None:
            print(f"   Icono: {icon.get('src')}")
        if url is not None:
            print(f"   URL: {url.text}")
        
        # Mostrar todos los sub-elementos
        print(f"   Sub-elementos: {[child.tag for child in channel]}")
    
    # Analizar programas
    programmes = root.findall('.//programme')
    print(f"\n\n📅 TOTAL DE PROGRAMAS: {len(programmes)}")
    print("\n" + "-"*80)
    print("PRIMEROS 3 PROGRAMAS (ejemplo detallado):")
    print("-"*80)
    
    for i, programme in enumerate(programmes[:3]):
        print(f"\n🔸 Programa {i+1}:")
        print(f"   Canal ID: {programme.get('channel')}")
        print(f"   Inicio: {programme.get('start')}")
        print(f"   Fin: {programme.get('stop')}")
        
        # Información del programa
        title = programme.find('title')
        desc = programme.find('desc')
        category = programme.find('category')
        icon = programme.find('icon')
        rating = programme.find('rating')
        
        if title is not None:
            print(f"   Título: {title.text}")
        if desc is not None:
            desc_text = desc.text[:100] + "..." if desc.text and len(desc.text) > 100 else desc.text
            print(f"   Descripción: {desc_text}")
        if category is not None:
            print(f"   Categoría: {category.text}")
        if icon is not None:
            print(f"   Poster/Icono: {icon.get('src')}")
        if rating is not None:
            rating_value = rating.find('value')
            if rating_value is not None:
                print(f"   Rating: {rating_value.text}")
        
        # Mostrar todos los sub-elementos disponibles
        print(f"   Elementos disponibles: {[child.tag for child in programme]}")
    
    # Estadísticas por canal
    print("\n\n" + "="*80)
    print("ESTADÍSTICAS DE PROGRAMACIÓN POR CANAL")
    print("="*80)
    
    channel_stats = {}
    for programme in programmes:
        channel_id = programme.get('channel')
        if channel_id:
            channel_stats[channel_id] = channel_stats.get(channel_id, 0) + 1
    
    print(f"\nCanales con programación: {len(channel_stats)}")
    print("\nTop 10 canales con más programas:")
    sorted_stats = sorted(channel_stats.items(), key=lambda x: x[1], reverse=True)[:10]
    
    for channel_id, count in sorted_stats:
        # Buscar el nombre del canal
        channel = root.find(f".//channel[@id='{channel_id}']")
        channel_name = "Desconocido"
        if channel is not None:
            display_name = channel.find('display-name')
            if display_name is not None:
                channel_name = display_name.text
        print(f"   {channel_id[:30]:30} ({channel_name[:30]:30}): {count} programas")
    
    # Guardar una muestra del XML para inspección
    print("\n\n💾 Guardando muestra del XML...")
    with open('test_epg/sample_epg.xml', 'w', encoding='utf-8') as f:
        # Guardar solo los primeros canales y programas para inspección
        sample_channels = channels[:10]
        sample_programmes = programmes[:50]
        
        f.write('<?xml version="1.0" encoding="UTF-8"?>\n')
        f.write('<tv>\n')
        f.write('  <!-- MUESTRA DE CANALES -->\n')
        for channel in sample_channels:
            f.write('  ' + ET.tostring(channel, encoding='unicode') + '\n')
        f.write('\n  <!-- MUESTRA DE PROGRAMAS -->\n')
        for programme in sample_programmes:
            f.write('  ' + ET.tostring(programme, encoding='unicode') + '\n')
        f.write('</tv>\n')
    
    print("✅ Muestra guardada en 'test_epg/sample_epg.xml'")
    
    return root

def main():
    # Descargar y descomprimir
    xml_content = download_and_decompress_epg()
    
    if xml_content:
        # Guardar el XML completo
        print("\n💾 Guardando XML completo...")
        with open('test_epg/full_epg.xml', 'w', encoding='utf-8') as f:
            f.write(xml_content)
        print("✅ XML completo guardado en 'test_epg/full_epg.xml'")
        
        # Analizar estructura
        analyze_epg_structure(xml_content)
        
        print("\n\n" + "="*80)
        print("✅ ANÁLISIS COMPLETADO")
        print("="*80)
        print("\nArchivos generados:")
        print("  - test_epg/full_epg.xml (archivo completo)")
        print("  - test_epg/sample_epg.xml (muestra para inspección)")
    else:
        print("❌ No se pudo descargar el archivo EPG")

if __name__ == "__main__":
    main()
