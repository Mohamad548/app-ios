import Flutter
import MessageUI
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var smsPendingResult: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    let messenger = engineBridge.applicationRegistrar.messenger()

    let inbox = FlutterEventChannel(name: "sim800/sms_inbox", binaryMessenger: messenger)
    inbox.setStreamHandler(EmptySmsInboxHandler())

    let channel = FlutterMethodChannel(name: "sim800/sms", binaryMessenger: messenger)
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(FlutterError(code: "GONE", message: "AppDelegate released", details: nil))
        return
      }
      switch call.method {
      case "canSend":
        result(MFMessageComposeViewController.canSendText())

      case "canReceive":
        // iOS apps cannot register for SMS inbox callbacks.
        result(false)

      case "shouldShowRationale":
        result(false)

      case "requestPermission":
        result(MFMessageComposeViewController.canSendText())

      case "requestReceivePermission":
        result(false)

      case "openAppSettings":
        if let url = URL(string: UIApplication.openSettingsURLString) {
          UIApplication.shared.open(url, options: [:], completionHandler: nil)
          result(true)
        } else {
          result(false)
        }

      case "send":
        self.handleSend(call: call, result: result)

      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private func handleSend(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard let args = call.arguments as? [String: Any],
          let number = args["number"] as? String,
          let message = args["message"] as? String,
          !number.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
          !message.isEmpty
    else {
      result(FlutterError(code: "ARGS", message: "number or message is empty", details: nil))
      return
    }

    guard MFMessageComposeViewController.canSendText() else {
      result(
        FlutterError(
          code: "UNAVAILABLE",
          message: "This device cannot send SMS (Messages / SIM required)",
          details: nil
        )
      )
      return
    }

    guard smsPendingResult == nil else {
      result(
        FlutterError(
          code: "BUSY",
          message: "Another SMS compose sheet is already open",
          details: nil
        )
      )
      return
    }

    guard let presenter = topViewController() else {
      result(
        FlutterError(
          code: "NO_VC",
          message: "No view controller to present Messages",
          details: nil
        )
      )
      return
    }

    smsPendingResult = result

    let composer = MFMessageComposeViewController()
    composer.messageComposeDelegate = self
    composer.recipients = [number]
    composer.body = message
    presenter.present(composer, animated: true)
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    let windows = scenes.flatMap(\.windows)
    let key = windows.first(where: \.isKeyWindow) ?? windows.first
    var vc = key?.rootViewController
    while let presented = vc?.presentedViewController {
      vc = presented
    }
    return vc
  }
}

extension AppDelegate: MFMessageComposeViewControllerDelegate {
  func messageComposeViewController(
    _ controller: MFMessageComposeViewController,
    didFinishWith result: MessageComposeResult
  ) {
    controller.dismiss(animated: true) { [weak self] in
      guard let self else { return }
      let pending = self.smsPendingResult
      self.smsPendingResult = nil
      switch result {
      case .sent:
        pending?(true)
      case .cancelled:
        pending?(false)
      case .failed:
        pending?(
          FlutterError(code: "SEND_FAILED", message: "Messages failed to send", details: nil)
        )
      @unknown default:
        pending?(false)
      }
    }
  }
}

/// iOS cannot stream inbox SMS; keep EventChannel so Dart subscribe is a no-op.
private final class EmptySmsInboxHandler: NSObject, FlutterStreamHandler {
  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    return nil
  }
}
