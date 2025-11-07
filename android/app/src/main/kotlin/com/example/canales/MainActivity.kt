package com.example.canales

import android.content.Intent
import android.net.Uri
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.canales.app/video_intent"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openVideo" -> {
                    val url = call.argument<String>("url")
                    if (url != null) {
                        val success = openVideoWithIntent(url)
                        result.success(success)
                    } else {
                        result.error("INVALID_URL", "URL is null", null)
                    }
                }
                "isAppInstalled" -> {
                    val packageName = call.argument<String>("packageName")
                    if (packageName != null) {
                        val isInstalled = isAppInstalled(packageName)
                        result.success(isInstalled)
                    } else {
                        result.error("INVALID_PACKAGE", "Package name is null", null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun openVideoWithIntent(url: String): Boolean {
        return try {
            val uri = Uri.parse(url)
            
            // Crear Intent principal con múltiples tipos MIME para reproductores de video
            val intent = Intent(Intent.ACTION_VIEW).apply {
                setDataAndType(uri, "video/mp4")  // Tipo genérico que todos los reproductores aceptan
                addCategory(Intent.CATEGORY_DEFAULT)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            }
            
            // Crear lista de Intents alternativos para diferentes reproductores
            val alternativeIntents = mutableListOf<Intent>()
            
            // Intent para VLC
            try {
                val vlcIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "video/*")
                    setPackage("org.videolan.vlc")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                alternativeIntents.add(vlcIntent)
            } catch (e: Exception) { }
            
            // Intent para MX Player
            try {
                val mxIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "video/*")
                    setPackage("com.mxtech.videoplayer.ad")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                alternativeIntents.add(mxIntent)
            } catch (e: Exception) { }
            
            // Intent para Ace Stream
            try {
                val aceIntent = Intent(Intent.ACTION_VIEW).apply {
                    setDataAndType(uri, "video/*")
                    setPackage("org.acestream.media")
                    addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                }
                alternativeIntents.add(aceIntent)
            } catch (e: Exception) { }
            
            // Crear chooser con todos los intents
            val chooser = Intent.createChooser(intent, "Reproducir con...")
            if (alternativeIntents.isNotEmpty()) {
                chooser.putExtra(Intent.EXTRA_INITIAL_INTENTS, alternativeIntents.toTypedArray())
            }
            chooser.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            
            startActivity(chooser)
            true
        } catch (e: Exception) {
            e.printStackTrace()
            false
        }
    }

    private fun isAppInstalled(packageName: String): Boolean {
        return try {
            packageManager.getPackageInfo(packageName, 0)
            true
        } catch (e: Exception) {
            false
        }
    }
}
