import UIKit
import Flutter
import GoogleMaps // 1. 👇 ADICIONE ESTE IMPORT 👇

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    
    // 2. 👇 ADICIONE ESTA LINHA COM A SUA CHAVE DO GOOGLE 👇
    GMSServices.provideAPIKey("AIzaSyARjawuJVWAHHtQ1uFbStDmhOLybhuX1zQ")
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}