import SwiftUI

struct EventChangeDetail: Identifiable {
    let title: String
    let systemImage: String
    let oldValue: String
    let currentValue: String

    var id: String {
        title
    }
}

struct ChangeEventNavigationRow: View {
    let event: CalendarEvent

    var body: some View {
        NavigationLink {
            EventDetailView(event: event)
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                EventRow(event: event, showsDate: true, showsTodayDetails: true)

                if event.isChangedEvent && event.changeDetails.isEmpty {
                    Text("Kein vorheriger Stand gespeichert")
                        .font(.interSubheadline)
                        .foregroundStyle(AppStyle.secondaryText)
                } else if !event.changeDetails.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(event.changeDetails) { detail in
                            ChangeDetailRow(detail: detail)
                        }
                    }
                    .padding(.top, 2)
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(event.subjectColor.opacity(0.16))
            )
            .overlay {
                if let stripeColor = event.unreadChangeColor {
                    StripedOverlay(color: stripeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .overlay {
                if let borderStyle = event.categoryBorderStyle {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            borderStyle.color,
                            style: StrokeStyle(lineWidth: 2, dash: borderStyle.dash)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if event.canBeMarkedAsRead {
                Button {
                    try? Shared.item.dataController.markAsRead(event)
                } label: {
                    Label("Abhaken", systemImage: "checkmark")
                }
                .tint(AppStyle.lime)
            }
        }
    }
}

struct ChangeDetailRow: View {
    let detail: EventChangeDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(detail.title, systemImage: detail.systemImage)
                .font(.interCaption.weight(.semibold))
                .foregroundStyle(AppStyle.blue)

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(detail.oldValue)
                    .foregroundStyle(AppStyle.secondaryText)

                Image(systemName: "arrow.right")
                    .font(.interCaption.weight(.semibold))
                    .foregroundStyle(AppStyle.teal)

                Text(detail.currentValue)
                    .fontWeight(.semibold)
            }
            .font(.interSubheadline)
            .lineLimit(2)
            .minimumScaleFactor(0.85)
        }
    }
}

struct EventNavigationRow: View {
    let event: CalendarEvent
    var showsDate = false
    var showsTodayDetails = false
    var addsVerticalSpacing = false

    var body: some View {
        NavigationLink {
            EventDetailView(event: event)
        } label: {
            EventRow(event: event, showsDate: showsDate, showsTodayDetails: showsTodayDetails)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(event.subjectColor.opacity(0.16))
            )
            .overlay {
                if let stripeColor = event.unreadChangeColor {
                    StripedOverlay(color: stripeColor)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .overlay {
                if let borderStyle = event.categoryBorderStyle {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            borderStyle.color,
                            style: StrokeStyle(lineWidth: 2, dash: borderStyle.dash)
                        )
                }
            }
        }
        .buttonStyle(.plain)
        .listRowInsets(
            EdgeInsets(
                top: addsVerticalSpacing ? 6 : 0,
                leading: 16,
                bottom: addsVerticalSpacing ? 6 : 0,
                trailing: 16
            )
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            if event.canBeMarkedAsRead {
                Button {
                    try? Shared.item.dataController.markAsRead(event)
                } label: {
                    Label("Abhaken", systemImage: "checkmark")
                }
                .tint(AppStyle.lime)
            }
        }
    }
}

struct StripedOverlay: View {
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let spacing: CGFloat = 12
                let size = geometry.size
                var x = -size.height

                while x < size.width {
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x + size.height, y: 0))
                    x += spacing
                }
            }
            .stroke(color.opacity(0.45), lineWidth: 4)
        }
        .allowsHitTesting(false)
    }
}

struct EventRow: View {
    let event: CalendarEvent
    var showsDate = false
    var showsTodayDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.previewTitle)
                .font(.interHeadline)
                .foregroundStyle(AppStyle.primaryText)

            if showsDate, let start = event.start {
                Label(start.formatted(date: .abbreviated, time: .omitted), systemImage: "calendar")
                    .font(.interSubheadline)
                    .foregroundStyle(AppStyle.secondaryText)
            }

            if showsTodayDetails {
                if let timeText = event.timeText {
                    Label(timeText, systemImage: "clock")
                        .font(.interSubheadline)
                        .foregroundStyle(AppStyle.secondaryText)
                }

                if let lecturerText = event.lecturerText {
                    Label(lecturerText, systemImage: "person")
                        .font(.interSubheadline)
                        .foregroundStyle(AppStyle.secondaryText)
                }
            }

            if let location = event.formattedLocation {
                Label(location, systemImage: "mappin")
                    .font(.interSubheadline)
                    .foregroundStyle(AppStyle.secondaryText)
            }
        }
    }
}

extension CalendarEvent {
    var previewTitle: String {
        cleanSummary ?? displayCategory ?? label ?? "Termin"
    }

    var subjectColor: Color {
        AppStyle.subjectColor(for: cleanSummary ?? category ?? label)
    }

    var categoryBorderStyle: (color: Color, dash: [CGFloat])? {
        switch normalizedCategory {
        case "ferien":
            return (AppStyle.lime, [])
        case "bib-event", "bib-events":
            return (AppStyle.yellow, [])
        case "selbstlernzeit":
            return (AppStyle.blue, [6, 4])
        case "klausur":
            return (AppStyle.magenta, [])
        default:
            return nil
        }
    }

    var isExam: Bool {
        normalizedCategory == "klausur"
    }

    var isBibEvent: Bool {
        normalizedCategory == "bib-event" || normalizedCategory == "bib-events"
    }

    var isHolidayEvent: Bool {
        normalizedCategory == "ferien"
    }

    var displayCategory: String? {
        switch normalizedCategory {
        case "bib-event", "bib-events":
            return "bib-Event"
        case "ferien":
            return "Ferien"
        case "selbstlernzeit":
            return "Selbstlernzeit"
        case "klausur":
            return "Klausur"
        case "eigenes-event":
            return "Eigenes Event"
        default:
            return category
        }
    }

    var formattedLocation: String? {
        normalizedText(location)
    }

    var isVisibleInSchedule: Bool {
        !(normalizedLabel == "geloescht" && read)
    }

    var canBeMarkedAsRead: Bool {
        !read && normalizedLabel != nil
    }

    var hasChangeLabel: Bool {
        normalizedLabel != nil
    }

    var isChangedEvent: Bool {
        normalizedLabel == "geaendert"
    }

    var unreadChangeColor: Color? {
        guard !read else {
            return nil
        }

        switch normalizedLabel {
        case "neu":
            return AppStyle.lime
        case "geaendert":
            return AppStyle.orange
        case "geloescht":
            return AppStyle.magenta
        default:
            return nil
        }
    }

    var timeText: String? {
        switch (start, end) {
        case let (start?, end?):
            return "\(start.formatted(date: .omitted, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
        case let (start?, nil):
            return start.formatted(date: .omitted, time: .shortened)
        case let (nil, end?):
            return end.formatted(date: .omitted, time: .shortened)
        case (nil, nil):
            return nil
        }
    }

    var changeDetails: [EventChangeDetail] {
        guard isChangedEvent, let originalEvent else {
            return []
        }

        var details: [EventChangeDetail] = []

        appendChange(
            title: "Raum",
            systemImage: "mappin",
            oldValue: originalEvent.formattedLocation,
            currentValue: formattedLocation,
            to: &details
        )
        appendChange(
            title: "Datum",
            systemImage: "calendar",
            oldValue: originalEvent.changeDateText,
            currentValue: changeDateText,
            to: &details
        )
        appendChange(
            title: "Zeit",
            systemImage: "clock",
            oldValue: originalEvent.changeTimeText,
            currentValue: changeTimeText,
            to: &details
        )
        appendChange(
            title: "Beschreibung",
            systemImage: "doc.text",
            oldValue: nonEmpty(descriptions: originalEvent.descriptions),
            currentValue: nonEmpty(descriptions: descriptions),
            to: &details
        )

        return details
    }

    private var changeTimeText: String? {
        formattedTimeText(start: start, end: end, showsDate: false)
    }

    private var changeDateText: String? {
        formattedDateText(start: start, end: end)
    }

    var lecturerText: String? {
        normalizedText(lecturer)
    }

    private var cleanSummary: String? {
        normalizedText(summary)
    }

    private var normalizedCategory: String? {
        category?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current)
    }

    private var normalizedLabel: String? {
        guard let label = label?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: .current),
              !label.isEmpty else {
            return nil
        }

        switch label {
        case "neu":
            return "neu"
        case "geaendert", "geandert":
            return "geaendert"
        case "geloescht", "geloscht":
            return "geloescht"
        default:
            return nil
        }
    }

}

extension OriginalEvent {
    var formattedLocation: String? {
        normalizedText(location)
    }

    var changeTimeText: String? {
        formattedTimeText(start: start, end: end, showsDate: false)
    }

    var changeDateText: String? {
        formattedDateText(start: start, end: end)
    }

}

private func appendChange(
    title: String,
    systemImage: String,
    oldValue: String?,
    currentValue: String?,
    to details: inout [EventChangeDetail]
) {
    guard let oldValue = normalizedDisplayValue(oldValue),
          let currentValue = normalizedDisplayValue(currentValue),
          oldValue != currentValue else {
        return
    }

    details.append(
        EventChangeDetail(
            title: title,
            systemImage: systemImage,
            oldValue: oldValue,
            currentValue: currentValue
        )
    )
}

private func formattedTimeText(start: Date?, end: Date?, showsDate: Bool) -> String? {
    let dateStyle: Date.FormatStyle.DateStyle = showsDate ? .abbreviated : .omitted

    switch (start, end) {
    case let (start?, end?):
        return "\(start.formatted(date: dateStyle, time: .shortened)) - \(end.formatted(date: .omitted, time: .shortened))"
    case let (start?, nil):
        return start.formatted(date: dateStyle, time: .shortened)
    case let (nil, end?):
        return end.formatted(date: dateStyle, time: .shortened)
    case (nil, nil):
        return nil
    }
}

private func formattedDateText(start: Date?, end: Date?) -> String? {
    guard let date = start ?? end else {
        return nil
    }

    return date.formatted(date: .abbreviated, time: .omitted)
}

private func nonEmpty(descriptions value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else {
        return nil
    }

    return value
}

private func normalizedDisplayValue(_ value: String?) -> String? {
    guard let value = nonEmpty(descriptions: value) else {
        return nil
    }

    return value
        .components(separatedBy: .whitespacesAndNewlines)
        .filter { !$0.isEmpty }
        .joined(separator: " ")
}

private func changedDetailText(oldValue: String?, currentValue: String?) -> String? {
    guard let oldValue = normalizedDisplayValue(oldValue),
          let currentValue = normalizedDisplayValue(currentValue),
          oldValue != currentValue else {
        return nil
    }

    return "\(oldValue) -> \(currentValue)"
}

struct EventDetailView: View {
    let event: CalendarEvent

    var body: some View {
        List {
            Section("Aktueller Stand") {
                DetailRow(title: "Datum", value: detailDateText)
                DetailRow(title: "Zeit", value: detailTimeText)
                DetailRow(title: "Raum", value: detailLocationText)
                DetailRow(title: "Kategorie", value: event.displayCategory)
                DetailRow(title: "Dozent", value: event.lecturerText)
                DetailRow(title: "Label", value: event.label)
                DetailRow(title: "Aktualisiert", value: detailUpdatedAtText)
            }

            if let descriptions = nonEmpty(event.descriptions) {
                Section("Beschreibung") {
                    Text(descriptions)
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(AppStyle.background)
        .font(.interBody)
        .navigationTitle(event.summary ?? event.label ?? "Termin")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var detailTimeText: String? {
        guard event.isChangedEvent else {
            return currentTimeText
        }

        return changedDetailText(
            oldValue: event.originalEvent?.changeTimeText,
            currentValue: formattedTimeText(start: event.start, end: event.end, showsDate: false)
        ) ?? currentTimeText
    }

    private var detailDateText: String? {
        guard event.isChangedEvent else {
            return currentDateText
        }

        return changedDetailText(
            oldValue: event.originalEvent?.changeDateText,
            currentValue: formattedDateText(start: event.start, end: event.end)
        ) ?? currentDateText
    }

    private var detailLocationText: String? {
        guard event.isChangedEvent else {
            return event.formattedLocation
        }

        return changedDetailText(
            oldValue: event.originalEvent?.formattedLocation,
            currentValue: event.formattedLocation
        ) ?? event.formattedLocation
    }

    private var detailUpdatedAtText: String? {
        guard let updatedAt = event.updatedAt else {
            return nil
        }

        return updatedAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var currentDateText: String? {
        formattedDateText(start: event.start, end: event.end)
    }

    private var currentTimeText: String? {
        formattedTimeText(start: event.start, end: event.end, showsDate: false)
    }

    private func nonEmpty(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else {
            return nil
        }

        return value
    }
}

private func normalizedText(_ value: String?) -> String? {
    guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines),
          !value.isEmpty else {
        return nil
    }

    return value
}

struct DetailRow: View {
    let title: String
    let value: String?

    var body: some View {
        if let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty {
            HStack {
                Text(title)
                    .foregroundStyle(AppStyle.secondaryText)
                Spacer()
                Text(value)
                    .foregroundStyle(AppStyle.primaryText)
                    .multilineTextAlignment(.trailing)
            }
        }
    }
}
