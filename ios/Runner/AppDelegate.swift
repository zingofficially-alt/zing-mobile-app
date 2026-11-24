import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Configure Google Maps
    // Key comes from .env -> Flutter/Secrets.xcconfig -> Info.plist (GMSApiKey).
    if let mapsKey = Bundle.main.object(forInfoDictionaryKey: "GMSApiKey") as? String,
       !mapsKey.isEmpty, !mapsKey.hasPrefix("$(") {
      GMSServices.provideAPIKey(mapsKey)
    } else {
      NSLog("ZING: GOOGLE_MAPS_API_KEY missing. Add it to .env and run `pod install`.")
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
