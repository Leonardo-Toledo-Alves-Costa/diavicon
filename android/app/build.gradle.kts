import java.io.FileInputStream
import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    id("com.google.gms.google-services")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Dados da chave de publicação.
//
// Ficam em android/key.properties, fora do repositório (já está no
// android/.gitignore) — senha de assinatura nunca entra no código. O arquivo
// de exemplo ao lado mostra o formato; as instruções para criar a chave estão
// em android/ASSINATURA.md.
//
// Sem esse arquivo o build continua funcionando, assinado com a chave de
// depuração: quem for só rodar o app no aparelho não precisa da chave real.
val arquivoDaChave = rootProject.file("key.properties")
val dadosDaChave = Properties().apply {
    if (arquivoDaChave.exists()) FileInputStream(arquivoDaChave).use { load(it) }
}
val temChaveDePublicacao = arquivoDaChave.exists() && dadosDaChave["storeFile"] != null

android {
    namespace = "br.com.asimovjr.diavicon"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_17.toString()
    }

    defaultConfig {
        applicationId = "br.com.asimovjr.diavicon"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    signingConfigs {
        if (temChaveDePublicacao) {
            create("release") {
                keyAlias = dadosDaChave["keyAlias"] as String
                keyPassword = dadosDaChave["keyPassword"] as String
                storeFile = file(dadosDaChave["storeFile"] as String)
                storePassword = dadosDaChave["storePassword"] as String
            }
        }
    }

    buildTypes {
        release {
            // Com a chave configurada, o APK/AAB sai assinado para a loja.
            // Sem ela, cai na chave de depuração — que instala à mão, mas a
            // Play Store recusa.
            signingConfig = if (temChaveDePublicacao) {
                signingConfigs.getByName("release")
            } else {
                signingConfigs.getByName("debug")
            }
        }
    }
}

flutter {
    source = "../.."
}
