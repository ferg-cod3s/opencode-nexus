import SwiftUI
import Foundation
import UIKit
@testable import OpenCodeNexus

@MainActor
func evaluateBody<V: View>(_ view: V) {
    let controller = UIHostingController(rootView: view)
    controller.view.frame = CGRect(x: 0, y: 0, width: 390, height: 844)

    let window = UIWindow(frame: controller.view.frame)
    window.rootViewController = controller
    window.makeKeyAndVisible()

    controller.view.setNeedsLayout()
    controller.view.layoutIfNeeded()

    RunLoop.current.run(until: Date().addingTimeInterval(0.05))
}

func testRespondJSON(_ json: String, statusCode: Int = 200) -> (HTTPURLResponse, Data) {
    let response = HTTPURLResponse(url: URL(string: "http://opencode.test")!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
    return (response, Data(json.utf8))
}
