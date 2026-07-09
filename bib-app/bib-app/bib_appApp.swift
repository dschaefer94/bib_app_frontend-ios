//
//  bib_appApp.swift
//  bib-app
//
//  Created by Daniel Schäfer / PBD2H24A on 28.05.26.
//

import SwiftUI
import CoreText

@main
struct bib_appApp: App {
    private let dataController = Shared.item.dataController

    init() {
        FontRegistrar.registerInter()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.viewContext)
                .font(.interBody)
                .tint(AppStyle.orange)
        }
    }
}

private enum FontRegistrar {
    static func registerInter() {
        guard let fontURL = Bundle.main.url(forResource: "Inter", withExtension: "ttf") else {
            return
        }

        CTFontManagerRegisterFontsForURL(fontURL as CFURL, .process, nil)
    }
}
