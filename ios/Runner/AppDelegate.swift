import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    
    // Method Channel 설정
    let appEnvironmentChannel = FlutterMethodChannel(
      name: "app_environment",
      binaryMessenger: controller.binaryMessenger
    )
    
    appEnvironmentChannel.setMethodCallHandler { (call, result) in
      if call.method == "getAppEnvironment" {
        result(self.getAppEnvironment())
      } else {
        result(FlutterMethodNotImplemented)
      }
    }
    
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  private func getAppEnvironment() -> String {
    #if targetEnvironment(simulator)
    return "simulator"
    #else
    if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL {
      let receiptPath = appStoreReceiptURL.path
      if receiptPath.contains("sandboxReceipt") {
        return "testflight"
      } else if receiptPath.contains("receipt") {
        return "appstore"
      }
    }
    return "unknown"
    #endif
  }
}
