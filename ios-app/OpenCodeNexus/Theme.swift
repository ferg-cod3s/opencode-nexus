import SwiftUI

enum Theme {
    static let interactiveBlue = Color("InteractiveBlue")
    static let textStrong = Color("TextStrong")
    static let textBase = Color("TextBase")
    static let textWeak = Color("TextWeak")
    static let backgroundBase = Color("BackgroundBase")
    static let surfaceRaised = Color("SurfaceRaised")
    static let border = Color("Border")
    static let borderWeak = Color("BorderWeak")
    static let buttonPrimaryBG = Color("ButtonPrimaryBG")
    static let buttonPrimaryText = Color("ButtonPrimaryText")
    static let errorCritical = Color("ErrorCritical")
    static let success = Color("Success")
    static let brandYuzu = Color("BrandYuzu")

    static let tokenKeyword = Color("InteractiveBlue")
    static let tokenString = Color("Success")
    static let tokenComment = Color("TextWeak")
    static let tokenNumber = Color("BrandYuzu")
    static let tokenType = Color.purple.opacity(0.8)

    static func borderOverlay(radius: CGFloat = 6) -> some View {
        RoundedRectangle(cornerRadius: radius)
            .stroke(borderWeak, lineWidth: 1)
    }
}
