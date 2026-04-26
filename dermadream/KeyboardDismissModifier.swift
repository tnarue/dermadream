//
//  KeyboardDismissModifier.swift
//  dermadream
//

import SwiftUI
import UIKit

extension View {
    /// Dismisses the iOS keyboard when tapping anywhere on this view.
    func dismissKeyboardOnTap() -> some View {
        simultaneousGesture(
            TapGesture().onEnded {
                UIApplication.shared.sendAction(
                    #selector(UIResponder.resignFirstResponder),
                    to: nil,
                    from: nil,
                    for: nil
                )
            }
        )
    }
}
