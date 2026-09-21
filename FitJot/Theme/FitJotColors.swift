import SwiftUI

/// Semantic colors backed by Asset Catalog light/dark variants.
enum FitJotColors {
    static let mainBackground = Color("MainActionBackground")
    static let mainText = Color("MainActionForeground")
    static let secondaryBackground = Color("SecondaryActionBackground")
    static let secondaryText = Color("SecondaryActionForeground")
}

extension View {
    func fitJotMainAction() -> some View {
        buttonStyle(.borderedProminent)
            .tint(FitJotColors.mainBackground)
            .foregroundStyle(FitJotColors.mainText)
            .fontWeight(.bold)
    }

    func fitJotSecondaryAction() -> some View {
        buttonStyle(.borderedProminent)
            .tint(FitJotColors.secondaryBackground)
            .foregroundStyle(FitJotColors.secondaryText)
    }
}
