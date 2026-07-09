import SwiftUI

struct ProfileView: View {
    @State private var firstName = "Max"
    @State private var lastName = "Mustermann"
    @State private var selectedClass = "Q1"

    private let availableClasses = [
        "EF",
        "Q1",
        "Q2",
        "11A",
        "11B",
        "12A",
        "12B"
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(spacing: 14) {
                        ZStack {
                            Circle()
                                .fill(AppStyle.brandGradient)
                                .frame(width: 86, height: 86)
                                .shadow(color: AppStyle.magenta.opacity(0.22), radius: 12, y: 6)

                            Text(initials)
                                .font(.interTitle.weight(.bold))
                                .foregroundStyle(.white)
                        }

                        VStack(spacing: 4) {
                            Text(fullName)
                                .font(.interTitle3)

                            Label(selectedClass, systemImage: "graduationcap")
                                .font(.interSubheadline)
                                .foregroundStyle(AppStyle.secondaryText)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                }
                .listRowBackground(AppStyle.surface)

                Section("Persönliche Daten") {
                    ProfileTextFieldRow(
                        title: "Vorname",
                        systemImage: "person",
                        text: $firstName
                    )

                    ProfileTextFieldRow(
                        title: "Nachname",
                        systemImage: "person.text.rectangle",
                        text: $lastName
                    )

                    Picker(selection: $selectedClass) {
                        ForEach(availableClasses, id: \.self) { className in
                            Text(className)
                                .tag(className)
                        }
                    } label: {
                        Label("Klasse", systemImage: "rectangle.stack.person.crop")
                    }
                    .pickerStyle(.menu)
                }

                Section("Konto") {
                    Label("AWS Cognito wird später angebunden", systemImage: "cloud")
                        .foregroundStyle(AppStyle.secondaryText)

                    Label("Datenquelle: ID-Token", systemImage: "key")
                        .foregroundStyle(AppStyle.secondaryText)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(AppStyle.background)
            .font(.interBody)
            .navigationTitle("Profil")
        }
    }

    private var fullName: String {
        let name = "\(firstName) \(lastName)"
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return name.isEmpty ? "Profil" : name
    }

    private var initials: String {
        let firstInitial = firstName.first.map(String.init) ?? ""
        let lastInitial = lastName.first.map(String.init) ?? ""
        let value = "\(firstInitial)\(lastInitial)"

        return value.isEmpty ? "?" : value.uppercased()
    }
}

struct ProfileTextFieldRow: View {
    let title: String
    let systemImage: String

    @Binding var text: String

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)

            TextField(title, text: $text)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.words)
        }
    }
}
