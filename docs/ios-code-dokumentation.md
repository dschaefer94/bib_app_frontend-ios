# iOS-Frontend: Code-Dokumentation

Diese Dokumentation beschreibt den aktuellen Swift-/SwiftUI-Code des iOS-Frontends in `frontends/ios`. Sie deckt Architektur, Entities, Schnittstellen, Datenfluss, `Shared.swift`, Views sowie alle relevanten State- und Binding-Variablen ab.

## 1. Architekturüberblick

Das Frontend ist eine lokal persistierende SwiftUI-App mit Core Data als Single Source of Truth für Kalenderdaten. Die UI liest fast ausschließlich aus Core Data; Netzwerkzugriffe werden über `DataController` ausgelöst und die Ergebnisse anschließend in das lokale Modell geschrieben.

### Zentrale Bausteine

| Datei | Rolle |
| --- | --- |
| `bib-app/bib-app/bib_appApp.swift` | App-Einstieg, Font-Registrierung, Injektion des Core-Data-Contexts |
| `bib-app/Shared.swift` | Singleton für globale Bereitstellung des `DataController` |
| `bib-app/DataController.swift` | Netzwerkzugriff, JSON-Decoding, Core-Data-Persistenz, Fetching, Markieren von Änderungen als gelesen |
| `bib-app/Calendar*`, `CalendarEvent*`, `OriginalEvent*`, `User*` | Core-Data-Entities |
| `bib-app/bib-app/ContentView.swift` | Root-View, Tab-Navigation, zentrale Filter- und Ableitungslogik |
| `bib-app/bib-app/TodayViews.swift` | Today-, Exams- und Changes-Tab |
| `bib-app/bib-app/WeekScheduleViews.swift` | Wochenraster, Legende, Datumsnavigation |
| `bib-app/bib-app/EventViews.swift` | Event-Karten, Änderungsdarstellung, Detailscreen, fachliche Event-Helfer |
| `bib-app/bib-app/ProfileView.swift` | lokaler Profil-Screen mit Demo-/Platzhalterzustand |
| `bib-app/bib-app/AppStyle.swift` | Farb- und Typografie-System |
| `openapi.yaml` | fachliche API-Beschreibung für Kalender und Profil |

## 2. App-Start und globale Abhängigkeiten

### `bib_appApp.swift`

Der Einstiegspunkt ist `@main struct bib_appApp: App`.

Verantwortung:

1. Erzeugt keinen eigenen `DataController`, sondern verwendet `Shared.item.dataController`.
2. Registriert beim Start die Schriftart `Inter`.
3. Injiziert `dataController.viewContext` via `.environment(\.managedObjectContext, ...)` in die gesamte View-Hierarchie.
4. Setzt globale UI-Defaults über `.font(.interBody)` und `.tint(AppStyle.orange)`.

### `Shared.swift`

`Shared` ist ein `@MainActor`-Singleton:

```swift
final class Shared {
    static let item = Shared()
    let dataController: DataController
}
```

Rolle:

- zentrale, globale Zugriffsstelle auf die Persistenz- und Importlogik,
- vermeidet mehrfache `DataController`-Instanzen,
- wird sowohl beim App-Start als auch direkt aus UI-Komponenten verwendet.

Aktuelle Verwendung:

- `bib_appApp.swift`: stellt `viewContext` bereit,
- `ContentView.importCalendar()`: startet den Kalenderimport,
- `EventNavigationRow` und `ChangeEventNavigationRow`: markieren Events per Swipe als gelesen.

**Wichtig:** Der Singleton koppelt Views direkt an Infrastruktur. Für die aktuelle App ist das pragmatisch und übersichtlich, aber es ist kein strikt entkoppeltes Dependency-Injection-Design.

## 3. Datenmodell / Entities

### 3.1 Core-Data-Entities

#### `Calendar`

| Property | Typ | Bedeutung |
| --- | --- | --- |
| `timestamp` | `Date?` | Zeitpunkt des importierten Kalenderstands |
| `events` | `NSSet?` | 1:n-Beziehung zu `CalendarEvent` |

Funktion:

- repräsentiert einen importierten Kalenderstand,
- wird vor jedem neuen Import zusammen mit allen alten Events gelöscht und neu aufgebaut,
- `ContentView` sortiert Kalender absteigend nach `timestamp` und verwendet den neuesten Stand.

#### `CalendarEvent`

| Property | Typ | Bedeutung |
| --- | --- | --- |
| `category` | `String?` | fachliche Kategorie, z. B. Klausur oder Selbstlernzeit |
| `descriptions` | `String?` | Beschreibungstext des Termins |
| `end` | `Date?` | Ende des Termins |
| `id` | `UUID?` | serverseitige oder ersetzte Event-ID |
| `label` | `String?` | Änderungslabel, z. B. neu / geändert / gelöscht |
| `lecturer` | `String?` | backendgelieferter Dozent, optional |
| `location` | `String?` | Roh-Raumangabe |
| `read` | `Bool` | UI-Status für bearbeitete Änderungen |
| `start` | `Date?` | Start des Termins |
| `summary` | `String?` | Haupttitel / Rohzusammenfassung |
| `updatedAt` | `Date?` | backendgelieferter Änderungszeitpunkt, optional |
| `calendar` | `Calendar?` | Rückbezug zum Kalender |
| `originalEvent` | `OriginalEvent?` | alter Stand bei Änderungen |

Fachliche Bedeutung:

- zentrales UI-Modell für alle Tabs,
- wird in `EventViews.swift` stark über berechnete Properties angereichert,
- enthält sowohl Stundenplantermine als auch Prüfungen, Ferien, bib-Events und Change-Einträge.

Wichtige abgeleitete Properties aus `EventViews.swift`:

| Property | Zweck |
| --- | --- |
| `previewTitle` | Anzeige-Titel für Kacheln und Listen |
| `subjectColor` | deterministische Farbe aus `summary`, `category` oder `label` |
| `categoryBorderStyle` | visuelle Kategorisierung (Klausur, Selbstlernzeit, Ferien, bib-Event) |
| `isExam` | filtert Klausuren |
| `isBibEvent` | erkennt bib-Events |
| `isHolidayEvent` | erkennt Ferien anhand des Backendwerts |
| `displayCategory` | UI-geeignete Kategorienbezeichnung aus `category` |
| `formattedLocation` | getrimmte Raumdarstellung aus `location` |
| `isVisibleInSchedule` | blendet gelöschte und bereits gelesene Events aus dem Stundenplan aus |
| `canBeMarkedAsRead` | steuert Swipe-Aktion |
| `hasChangeLabel` | bestimmt, ob ein Event im Changes-Tab auftaucht |
| `isChangedEvent` | erkennt geänderte Termine |
| `unreadChangeColor` | Farbcodierung ungelesener Änderungen |
| `timeText` | formatierte Zeitspanne |
| `lecturerText` | direkter, getrimmter Backendwert aus `lecturer` |
| `changeDetails` | Liste fachlicher Änderungen gegenüber `OriginalEvent` |

#### `OriginalEvent`

| Property | Typ | Bedeutung |
| --- | --- | --- |
| `descriptions` | `String?` | alte Beschreibung |
| `end` | `Date?` | altes Ende |
| `location` | `String?` | alter Raum |
| `start` | `Date?` | alter Start |
| `summary` | `String?` | alter Titel |
| `parentEvent` | `CalendarEvent?` | Rückbezug auf das geänderte Event |

Funktion:

- speichert den vorherigen Stand eines geänderten Termins,
- wird nur angelegt, wenn die API `originalEvent` liefert,
- ist die Basis für `changeDetails`, `detailDateText`, `detailTimeText` und `detailLocationText`.

#### `User`

| Property | Typ | Bedeutung |
| --- | --- | --- |
| `email` | `String?` | E-Mail |
| `klasse` | `String?` | Klassenbezeichnung |
| `nachname` | `String?` | Nachname |
| `vorname` | `String?` | Vorname |

Status im aktuellen Code:

- Die Entity ist vorhanden, wird aber aktuell nirgends aktiv gelesen oder geschrieben.
- `ProfileView` arbeitet nicht mit Core Data oder Backend-Daten, sondern mit lokalem `@State`.

### 3.2 Netzwerk-DTOs in `DataController.swift`

#### `CalendarResponse`

| Feld | Typ | Bedeutung |
| --- | --- | --- |
| `timestamp` | `Date` | Zeitstempel des Imports |
| `events` | `[CalendarEventResponse]` | Liste der importierten Events |

#### `CalendarEventResponse`

| Feld | Typ | Bedeutung |
| --- | --- | --- |
| `category` | `String?` | Kategorie |
| `description` | `String?` | Beschreibung |
| `end` | `Date?` | Ende |
| `id` | `UUID?` | Event-ID |
| `label` | `String?` | Änderungslabel |
| `lecturer` | `String?` | optionaler Dozent |
| `location` | `String?` | Raum |
| `originalEvent` | `OriginalEventResponse?` | alter Stand |
| `read` | `Bool?` | Read-Flag vom Backend |
| `start` | `Date?` | Start |
| `summary` | `String?` | Titel |
| `updatedAt` | `Date?` | optionaler Änderungszeitpunkt |

Besonderheit beim Decoding:

- `originalEvent` wird tolerant aus drei möglichen Keys gelesen: `originalEvent`, `original_event`, `oldEvent`.

#### `OriginalEventResponse`

Spiegelt den alten Event-Stand mit `description`, `start`, `end`, `location`, `summary`.

## 4. Schnittstellen / API

### 4.1 Tatsächlich vom iOS-Client verwendete Schnittstelle

`DataController.loadCalendar()` lädt Daten über:

- `URLSession.shared.data(from: Self.calendarURL)`
- `calendarURL = https://testapi.pbd2h24asc.web.bib.de`

Danach erfolgt:

1. HTTP-Response-Prüfung,
2. Statuscode-Prüfung auf `200...299`,
3. Decoding zu `CalendarResponse`,
4. Persistierung in Core Data.

### 4.2 In `openapi.yaml` dokumentierte Endpunkte

| Endpunkt | Zweck | Aktuelle iOS-Nutzung |
| --- | --- | --- |
| `GET /api/calendar` | Stundenplan abrufen | fachlich passend, aber nicht 1:1 wie im Client verdrahtet |
| `GET /api/profile/me` | Profil abrufen | aktuell ungenutzt |
| `POST /api/profile/update-klasse` | Klasse aktualisieren | aktuell ungenutzt |

### 4.3 Verbleibende Abweichungen zwischen OpenAPI und Client-Code

#### Kalender-Response-Form

`openapi.yaml` beschreibt für `GET /api/calendar` grob:

- `success: boolean`
- `data: CalendarEvent[]`
- `timestamp: string`

Der iOS-Client erwartet dagegen direkt:

- `timestamp`
- `events`

Es gibt im Client **kein** Decoding für:

- ein `success`-Flag,
- ein `data`-Array als Wrapper.

#### Feldnamen

- `category`, `lecturer` und `updatedAt` sind jetzt zwischen OpenAPI und Swift-Modell ausgerichtet.
- Für `originalEvent` ist der Client weiterhin robuster und akzeptiert mehrere Key-Varianten.

#### Profil-Schnittstellen

- Die OpenAPI beschreibt bereits Profilendpunkte und JWT-Authentifizierung.
- Im aktuellen SwiftUI-Code existiert dafür noch keine Client-Integration.
- `ProfileView` ist momentan ein lokaler Platzhalter-Screen.

### 4.4 Fehlerbehandlung

`CalendarImportError` kapselt drei Fehlerfälle:

| Fehler | Bedeutung |
| --- | --- |
| `invalidResponse` | keine HTTP-Antwort |
| `httpStatus(Int)` | nicht erfolgreicher Statuscode |
| `invalidDate(String)` | Datum konnte nicht geparst werden |

Im UI wird der Fehler in `ContentView.importCalendar()` derzeit vereinfacht zu:

- `errorMessage = "Du scheinst offline zu sein."`

Dadurch gehen detailliertere Serverfehler in der Oberfläche aktuell verloren.

## 5. Persistenz- und Importlogik

### `DataController`

`DataController` ist `@MainActor` und kapselt die komplette Datenhaltung.

Verantwortung:

1. Initialisiert `NSPersistentContainer(name: "Model")`.
2. Lädt den Store und setzt ihn bei inkompatiblem Altschema hart zurück.
3. Aktiviert `automaticallyMergesChangesFromParent`.
4. Lädt Kalenderdaten vom Server.
5. Löscht vor jedem Import alle bestehenden `Calendar`, `CalendarEvent` und `OriginalEvent`.
6. Schreibt die neue Antwort vollständig in Core Data.
7. Bietet `fetchCalendars()`, `save()` und `markAsRead(_:)`.

### JSON-Dateiverarbeitung

Der Decoder unterstützt zwei Datumsformate:

1. Unix-Timestamps als `Double`
2. ISO-8601-Strings mit oder ohne Fractional Seconds

### Speichermodell beim Import

Beim Import wird **kein inkrementelles Update** durchgeführt. Stattdessen:

1. Alle alten Kalenderdaten löschen
2. Einen neuen `Calendar` erzeugen
3. Für jedes DTO ein neues `CalendarEvent` erzeugen
4. Optional ein `OriginalEvent` anlegen
5. `save()` ausführen

Folgen:

- Die Persistenz ist einfach und konsistent.
- Historie über mehrere Kalenderstände wird nicht behalten.
- `read`-Status alter Events geht bei jedem vollständigen Reimport verloren, sofern das Backend ihn nicht erneut liefert.
- Nach inkompatiblen Schemaänderungen darf der lokale Store verworfen und neu aufgebaut werden.

## 6. Datenfluss Ende-zu-Ende

### 6.1 Beim App-Start

1. `bib_appApp` startet.
2. `Shared.item.dataController` wird erzeugt.
3. Wenn ein alter Core-Data-Store nicht mehr zum Modell passt, wird er gelöscht und neu erstellt.
4. `viewContext` wird in den SwiftUI-Environment geschrieben.
5. `ContentView` kann per `@FetchRequest` auf gespeicherte Kalender zugreifen.

### 6.2 Beim Kalenderimport

1. `TodayView` zeigt den Toolbar-Refresh-Button.
2. Der Button ruft die Closure `importCalendar()` aus `ContentView` auf.
3. `ContentView` setzt `isLoading = true` und löscht `errorMessage`.
4. In einem `Task { @MainActor in ... }` wird `Shared.item.dataController.loadCalendar()` ausgeführt.
5. `DataController` lädt, decodiert und speichert neue Daten.
6. Der `@FetchRequest` in `ContentView` reagiert auf die Core-Data-Änderungen.
7. Alle abgeleiteten Arrays und Optionalwerte in `ContentView` werden neu berechnet.
8. Die Tabs rendern auf Basis des aktualisierten Models neu.

### 6.3 Bei Änderungen / Gelesen-Status

1. `EventNavigationRow` oder `ChangeEventNavigationRow` zeigen eine Swipe-Aktion, wenn `event.canBeMarkedAsRead == true`.
2. Die Swipe-Aktion ruft `Shared.item.dataController.markAsRead(event)` auf.
3. `read` wird auf `true` gesetzt und gespeichert.
4. Dadurch ändern sich u. a.:
   - `unreadChangeColor`,
   - `isVisibleInSchedule`,
   - Sichtbarkeit im Changes-/Schedule-Kontext.

### 6.4 Ableitungen in `ContentView`

`ContentView` transformiert rohe Persistenzdaten in UI-spezifische Teilmengen:

| Ableitung | Bedeutung |
| --- | --- |
| `storedEvents` | alle Events aus allen gespeicherten Kalendern, nach Start sortiert |
| `allEvents` | `storedEvents`, gefiltert auf `isVisibleInSchedule` |
| `latestCalendarTimestamp` | Zeitstempel des neuesten Kalenders |
| `todaysEvents` | heutige Events aus `allEvents` |
| `currentEvent` | aktuell laufendes Event |
| `nextEvent` | nächstes Event ab jetzt |
| `laterTodayEvents` | spätere Events nach `nextEvent` |
| `upcomingExams` | künftige Klausuren |
| `changeEvents` | Events mit Change-Label |

## 7. Views und View-Hierarchie

## 7.1 Root und Navigation

### `ContentView`

Rolle:

- Root-Container der App,
- hält den UI-Zustand,
- entscheidet, welcher Tab angezeigt wird,
- bereitet Event-Slices für Unterviews auf.

State und Datenquellen:

| Property | Wrapper | Zweck |
| --- | --- | --- |
| `calendars` | `@FetchRequest` | reaktive Datenquelle aus Core Data |
| `isLoading` | `@State` | steuert ProgressView beim Refresh |
| `errorMessage` | `@State` | Fehlermeldung im Today-Tab |
| `selectedTab` | `@State` | aktiver Bottom-Menu-Tab |
| `selectedWeekDate` | `@State` | aktuell angezeigte Woche |

Tab-Mapping:

| Tab | Ziel-View |
| --- | --- |
| `.today` | `TodayView` |
| `.changes` | `ChangesView` |
| `.week` | `WeekScheduleView` |
| `.exams` | `ExamsView` |
| `.profile` | `ProfileView` |

Besonderheiten:

- `select(_:)` setzt beim Wechsel zur Wochenansicht `selectedWeekDate` auf `Date()` zurück.
- Die Bottom-Navigation ist keine `TabView`, sondern eine eigene `HStack`-Leiste mit `BottomMenuButton`.

### `BottomMenuButton`

Kleine Hilfs-View für die untere Navigation.

Input:

- `tab`
- `isSelected`
- `action`

Lokaler Zustand:

- keiner

## 7.2 Tages-, Klausur- und Änderungsansichten

### `TodayView`

Input:

| Property | Typ | Zweck |
| --- | --- | --- |
| `calendarTimestamp` | `Date?` | Anzeige des Kalenderstands |
| `currentEvent` | `CalendarEvent?` | aktueller Kurs |
| `nextEvent` | `CalendarEvent?` | nächster Kurs |
| `laterTodayEvents` | `[CalendarEvent]` | restliche Tagesliste |
| `isLoading` | `Bool` | Toolbar-Spinner |
| `errorMessage` | `String?` | Inline-Fehleranzeige |
| `importCalendar` | `() -> Void` | Callback für Refresh |

Lokaler Zustand:

- keiner

Verhalten:

- rendert drei fachliche Sektionen: aktuelles Fach, nächstes Fach, Kurse danach,
- zeigt bei leerem Zustand Platzhaltertexte,
- zeigt unten den Zeitstempel des letzten Kalenderimports,
- delegiert Event-Darstellung an `EventNavigationRow`.

### `ExamsView`

Input:

- `events: [CalendarEvent]`

Lokaler Zustand:

- keiner

Verhalten:

- zeigt `upcomingExams` als Liste,
- nutzt `EventNavigationRow` mit Datum und Today-Details.

### `ChangesView`

Input:

- `events: [CalendarEvent]`

Lokaler Zustand:

- keiner

Verhalten:

- zeigt alle Events mit Änderungslabel,
- nutzt `ChangeEventNavigationRow`.

## 7.3 Wochenansicht

### `WeekScheduleView`

Input:

| Property | Typ | Zweck |
| --- | --- | --- |
| `events` | `[CalendarEvent]` | sichtbare Stundenplan-Events |
| `selectedWeekDate` | `@Binding Date` | aktuell fokussierte Woche |

Lokaler Zustand:

- keiner

Abgeleitete Daten:

- `daysInSelectedWeek`: Montag bis Freitag der aktiven Woche,
- `weekTitle`: Datumsbereich im Header,
- `events(on:)`: alle Events, die in einen Kalendertag fallen.

Verhalten:

- zeigt Header mit Woche vor/zurück,
- rendert ein 5x5-Raster anhand von `ScheduleBlock`,
- ergänzt eine Legende für Kategorien und Labels.

### `ScheduleBlock`

Enum für fünf Unterrichtsblöcke:

1. 08:00-09:30
2. 09:50-11:20
3. 11:30-13:00
4. 13:45-15:15
5. 15:30-17:00

`contains(_:)` ordnet ein Event einem Block zu. Ferien-Vertreterevents werden bewusst immer dem ersten Block zugeordnet, damit sie im Raster sichtbar sind.

### Weitere Wochen-Views

| View | Aufgabe | State |
| --- | --- | --- |
| `WeekScheduleGrid` | Layout und Größenberechnung des Rasters | keiner |
| `WeekDayHeader` | Wochentag + Datum pro Spalte | keiner |
| `WeekBlockCell` | Zellhintergrund und Event-Platzierung | keiner |
| `WeekEventLink` | Navigation zur Detailansicht | keiner |
| `WeekDayColumn` | alternative Spalten-Darstellung, im aktuellen Flow nicht verwendet | keiner |
| `WeekEventTile` | kompakte Event-Kachel | keiner |
| `ScheduleLegendView` | Erläuterung visueller Semantik | keiner |
| `LegendColumn` / `LegendItem` | Hilfsviews für die Legende | keiner |
| `DateNavigationHeader` | Vor-/Zurück-Buttons plus Titel | keiner |

## 7.4 Event-bezogene Views

### `EventChangeDetail`

Ein einfaches UI-Modell für eine einzelne Änderung:

- `title`
- `systemImage`
- `oldValue`
- `currentValue`

### `ChangeEventNavigationRow`

Rolle:

- visuelle Karte für Events im Changes-Tab,
- zeigt optional eine Liste fachlicher Deltas aus `event.changeDetails`.

Verhalten:

- navigiert zu `EventDetailView`,
- zeigt farbige Hintergründe und Overlays abhängig von Kategorie und Label,
- bietet Swipe-Aktion zum Abhaken ungelesener Änderungen.

Lokaler Zustand:

- keiner

### `ChangeDetailRow`

Zeigt eine einzelne Änderung als `alt -> neu`.

### `EventNavigationRow`

Wiederverwendbare Event-Karte für Today- und Exams-Tab.

Konfigurationsparameter:

- `event`
- `showsDate`
- `showsTodayDetails`
- `addsVerticalSpacing`

Lokaler Zustand:

- keiner

### `StripedOverlay`

Zeichnet diagonale Streifen zur Kennzeichnung ungelesener Änderungen.

### `EventRow`

Zeigt die textuelle Zusammenfassung eines Events:

- `previewTitle`
- optional Datum
- optional Uhrzeit
- optional Dozent aus `lecturer`
- optional Ort aus `location`

### `EventDetailView`

Detailscreen für ein einzelnes Event.

Rolle:

- zeigt den aktuellen Event-Stand,
- visualisiert bei geänderten Events die Differenz in Datum, Zeit und Raum als `alt -> neu`,
- zeigt optional die Beschreibung.

Input:

- `event: CalendarEvent`

Lokaler Zustand:

- keiner

Wichtige Ableitungen:

| Property | Zweck |
| --- | --- |
| `detailTimeText` | zeigt ggf. alte und neue Zeit |
| `detailDateText` | zeigt ggf. altes und neues Datum |
| `detailLocationText` | zeigt ggf. alten und neuen Raum |
| `detailUpdatedAtText` | zeigt den backendgelieferten Änderungszeitpunkt |
| `currentDateText` / `currentTimeText` | Fallback ohne Delta |

### `DetailRow`

Generische Zeile für Label/Wert-Paare im Detailscreen.

## 7.5 Profilansicht

### `ProfileView`

State:

| Property | Wrapper | Initialwert | Zweck |
| --- | --- | --- | --- |
| `firstName` | `@State` | `"Max"` | lokaler Vorname |
| `lastName` | `@State` | `"Mustermann"` | lokaler Nachname |
| `selectedClass` | `@State` | `"Q1"` | lokal gewählte Klasse |

Zusätzliche Konstanten:

- `availableClasses`: feste Auswahlliste für den Picker.

Verhalten:

- zeigt Avatar aus Initialen,
- generiert `fullName` und `initials` aus lokalem State,
- enthält Formularfelder für persönliche Daten,
- signalisiert im Bereich "Konto", dass AWS Cognito und ID-Token später angebunden werden sollen.

**Aktueller Stand:** Es gibt noch keine echte Anbindung an `User`, OpenAPI-Profilendpunkte oder Authentifizierung.

### `ProfileTextFieldRow`

Hilfs-View für rechtsbündige Textfelder.

Input:

| Property | Typ |
| --- | --- |
| `title` | `String` |
| `systemImage` | `String` |
| `text` | `@Binding String` |

## 8. State-, Binding- und Fetch-Übersicht

### Lokaler UI-State

| Owner | Wrapper | Name | Bedeutung |
| --- | --- | --- | --- |
| `ContentView` | `@State` | `isLoading` | Refresh läuft |
| `ContentView` | `@State` | `errorMessage` | Fehleranzeige |
| `ContentView` | `@State` | `selectedTab` | aktiver Bereich |
| `ContentView` | `@State` | `selectedWeekDate` | gewählte Woche |
| `ProfileView` | `@State` | `firstName` | lokaler Vorname |
| `ProfileView` | `@State` | `lastName` | lokaler Nachname |
| `ProfileView` | `@State` | `selectedClass` | lokale Klassenwahl |

### Bindings

| Owner | Wrapper | Name | Quelle |
| --- | --- | --- | --- |
| `WeekScheduleView` | `@Binding` | `selectedWeekDate` | aus `ContentView` |
| `ProfileTextFieldRow` | `@Binding` | `text` | aus `ProfileView` |

### Reaktive Persistenzanbindung

| Owner | Wrapper | Name | Bedeutung |
| --- | --- | --- | --- |
| `ContentView` | `@FetchRequest` | `calendars` | geladenen Kalenderstand beobachten |

## 9. Styling und UI-Konventionen

### `AppStyle.swift`

`AppStyle` zentralisiert:

- Markenfarben (`orange`, `teal`, `lime`, `magenta`, `blue`, `yellow`),
- Systemflächen (`background`, `surface`, `elevatedSurface`),
- Textfarben,
- `brandGradient`,
- `subjectPalette`,
- Farbauswahl für Fächer über `subjectColor(for:)`.

Zusätzlich definiert die Datei:

- `Color.init(hex:)` für hexadezimale Farben,
- die komplette `Inter`-Typografie über `Font`-Extensions.

Bedeutung für den Rest des Codes:

- Alle größeren Views verwenden konsistent `AppStyle.background`, `AppStyle.surface` und die Inter-Fonts.
- Event-Kacheln und Legenden leiten ihr Erscheinungsbild fast vollständig aus `AppStyle` und den `CalendarEvent`-Helfern ab.

## 10. Technische Beobachtungen und Grenzen

1. **Direkter Singleton-Zugriff aus Views:** einfach, aber eng gekoppelt.
2. **Profil noch nicht integriert:** UI vorhanden, Datenfluss zum Backend fehlt.
3. **Kalender-Wrapper weiter abweichend:** OpenAPI beschreibt weiterhin `success`/`data`, der Client erwartet direkt `timestamp`/`events`.
4. **Vollständiger Reimport statt Delta-Update:** robust, aber ohne Historie.
5. **Fehleranzeige im UI stark vereinfacht:** alle Importfehler erscheinen derzeit als Offline-Hinweis.
6. **`WeekDayColumn` aktuell ungenutzt:** vorhanden, aber nicht im aktiven Rendering-Pfad von `WeekScheduleView`.

## 11. Kurzfazit

Das iOS-Frontend ist aktuell klar um einen einfachen Fluss gebaut: **API laden -> Core Data überschreiben -> `@FetchRequest` aktualisiert `ContentView` -> Tabs filtern und rendern Events**. Die meiste Fachlogik steckt nicht im Networking, sondern in den berechneten `CalendarEvent`-Properties und in den von `ContentView` abgeleiteten Event-Slices.
