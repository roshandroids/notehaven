import Flutter
import UIKit

class SceneDelegate: FlutterSceneDelegate {
  private var pencil: PencilBridge?

  override func scene(
    _ scene: UIScene,
    willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    super.scene(scene, willConnectTo: session, options: connectionOptions)
    if let flutter = window?.rootViewController as? FlutterViewController {
      let bridge = PencilBridge(messenger: flutter.binaryMessenger)
      bridge.attach(to: flutter.view)
      pencil = bridge
    }
  }
}


/// Forwards Apple Pencil double-tap (Pencil 2) and squeeze (Pencil Pro) to Dart.
final class PencilBridge: NSObject, UIPencilInteractionDelegate {
  private let channel: FlutterMethodChannel

  init(messenger: FlutterBinaryMessenger) {
    channel = FlutterMethodChannel(name: "notehaven/pencil", binaryMessenger: messenger)
    super.init()
  }

  func attach(to view: UIView) {
    let interaction = UIPencilInteraction()
    interaction.delegate = self
    view.addInteraction(interaction)
  }

  func pencilInteractionDidTap(_ interaction: UIPencilInteraction) {
    channel.invokeMethod("tap", arguments: nil)
  }

  @available(iOS 17.5, *)
  func pencilInteraction(_ interaction: UIPencilInteraction, didReceiveSqueeze squeeze: UIPencilInteraction.Squeeze) {
    if squeeze.phase == .ended { channel.invokeMethod("squeeze", arguments: nil) }
  }
}
