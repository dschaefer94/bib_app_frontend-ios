//
//  bib_appApp.swift
//  bib-app
//
//  Created by Daniel Schäfer / PBD2H24A on 28.05.26.
//

import SwiftUI

@main
struct bib_appApp: App {
    private let dataController = Shared.item.dataController

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, dataController.viewContext)
                .font(.interBody)
                .tint(AppStyle.orange)
        }
    }
}
