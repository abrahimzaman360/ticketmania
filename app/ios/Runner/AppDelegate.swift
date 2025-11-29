import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var bleMethodChannel: FlutterMethodChannel?
  private var bleAdvertisingManager: BLEAdvertisingManager?
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    
    // Setup BLE advertising method channel
    if let controller = window?.rootViewController as? FlutterViewController {
      let channel = FlutterMethodChannel(
        name: "com.fishmindlabs.ticketmania/ble_advertising",
        binaryMessenger: controller.binaryMessenger
      )
      
      if #available(iOS 13.0, *) {
        bleAdvertisingManager = BLEAdvertisingManager()
        setupBLEMethodChannel(channel: channel)
      }
    }
    
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
  
  @available(iOS 13.0, *)
  private func setupBLEMethodChannel(channel: FlutterMethodChannel) {
    bleMethodChannel = channel
    
    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let manager = self?.bleAdvertisingManager else {
        result(FlutterError(code: "UNAVAILABLE", message: "BLE advertising manager not available", details: nil))
        return
      }
      
      switch call.method {
      case "startAdvertising":
        guard let args = call.arguments as? [String: Any],
              let ticketIds = args["ticketIds"] as? [String] else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "ticketIds cannot be null or empty", details: nil))
          return
        }
        
        let success = manager.startAdvertising(ticketIds: ticketIds)
        result(success)
        
      case "stopAdvertising":
        manager.stopAdvertising()
        result(true)
        
      case "updateTicketIds":
        guard let args = call.arguments as? [String: Any],
              let ticketIds = args["ticketIds"] as? [String] else {
          result(FlutterError(code: "INVALID_ARGUMENT", message: "ticketIds cannot be null", details: nil))
          return
        }
        
        manager.updateTicketIds(ticketIds: ticketIds)
        result(true)
        
      case "isAdvertising":
        result(manager.isCurrentlyAdvertising())
        
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
