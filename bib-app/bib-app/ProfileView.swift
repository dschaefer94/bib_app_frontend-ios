import SwiftUI
// Platzhalter, hier kann man einen Identity-Provider verbinden, z.B. Cognito
// gerade aber noch inaktiv, weil Cognito nicht wie geplant funktionieren wollte.
// Anbindung kann aus der aws-Doku gecopy-pastet werden und mit Issuer-URI versehen werden.
// Login-View ebenso, auch wenn fürs Projekt out-of-scope
struct ProfileView: View {
    @State private var firstName = "Daniel"
    @State private var lastName = "Schäfer"
    @State private var selectedClass = "PBD2H24A"

    private let availableClasses = [
        "PBD2H24A",
        "PBS2H24A",
        "PBG2H24A",
        "PBM2H24C",
        "PBM2H24D",
        "DOZREB"
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
                    Label("AWS Cognito kommt noch", systemImage: "cloud")
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
