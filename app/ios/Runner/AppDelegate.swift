import Flutter
import GoogleMaps
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // The Maps key comes from the app (main.dart), which gets it from .env as
    // a dart-define, the same source Android uses. Dart sends it before the
    // first map is created; GMSServices needs it before any GMSMapView.
    guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "DadliplugMapsKey")
    else { return }
    let channel = FlutterMethodChannel(
      name: "dadliplug/maps",
      binaryMessenger: registrar.messenger()
    )
    channel.setMethodCallHandler { call, result in
      guard call.method == "setApiKey", let key = call.arguments as? String, !key.isEmpty
      else {
        result(FlutterMethodNotImplemented)
        return
      }
      GMSServices.provideAPIKey(key)
      result(nil)
    }
  }
}
