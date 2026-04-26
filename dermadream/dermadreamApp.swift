//
//  dermadreamApp.swift
//  dermadream
//
//  Created by Naruethai Thongphasook on 12/4/2569 BE.
//

import SwiftUI
import UIKit

@main
struct dermadreamApp: App {
    @StateObject private var appModel = AppModel()
    @StateObject private var engine = DermadreamEngine()

    init() {
        Self.removeNavigationBarHairline()
    }

    /// Hides the default 1pt grey line under the navigation title (e.g. Routine, Shelf diagnostics).
    private static func removeNavigationBarHairline() {
        let cream = UIColor(red: 249 / 255, green: 247 / 255, blue: 242 / 255, alpha: 1)
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = cream
        appearance.shadowColor = .clear
        appearance.shadowImage = UIImage()

        let bar = UINavigationBar.appearance()
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
        bar.compactAppearance = appearance
        bar.compactScrollEdgeAppearance = appearance
        bar.shadowImage = UIImage()
        bar.isTranslucent = false
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appModel)
                .environmentObject(engine)
        }
    }
}
