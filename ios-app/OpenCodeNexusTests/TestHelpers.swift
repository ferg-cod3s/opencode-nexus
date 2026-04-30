import SwiftUI
import Foundation
@testable import OpenCodeNexus

@MainActor
func evaluateBody<V: View>(_ view: V) {
    _ = view.body
}
