////
////  HabitWidgetIntent.swift
////  timerVisual
////
////  Provides widget configuration for selecting a habit snapshot.
////
//
//import AppIntents
//import SharedTimerModels
//
//@available(iOSApplicationExtension 17.0, *)
//public struct HabitWidgetConfigurationIntent: WidgetConfigurationIntent {
//    public static var title: LocalizedStringResource = "Habit Widget"
//    public static var description = IntentDescription("Choose a habit to display on the widget.")
//
//    @Parameter(title: "Habit")
//    public var habit: HabitWidgetEntity?
//
//    public init() {
//        self._habit = Parameter()
//    }
//
//}
//
//@available(iOSApplicationExtension 17.0, *)
//public struct HabitWidgetEntity: AppEntity {
//    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Habit")
//    public static var defaultQuery = HabitWidgetQuery()
//
//    public var id: String
//    public var name: String
////    public var icon: String
//    public var colorHex: String
//
//    public init(id: String, name: String, icon: String, colorHex: String) {
//        self.id = id
//        self.name = name
//        self.icon = icon
//        self.colorHex = colorHex
//    }
//
//    public var displayRepresentation: DisplayRepresentation {
//        DisplayRepresentation(title: LocalizedStringResource(stringLiteral: name), subtitle: LocalizedStringResource(stringLiteral: icon))
//    }
//
//    public static var placeholder: HabitWidgetEntity {
//        HabitWidgetEntity(
//            id: HabitWidgetSnapshot.placeholder.id,
//            name: HabitWidgetSnapshot.placeholder.name,
//            icon: HabitWidgetSnapshot.placeholder.icon,
//            colorHex: HabitWidgetSnapshot.placeholder.colorHex
//        )
//    }
//}
//
//@available(iOSApplicationExtension 17.0, *)
//public struct HabitWidgetQuery: EntityQuery {
//    public init() {
//        
//    }
//    
//    public func entities(for identifiers: [HabitWidgetEntity.ID]) async throws -> [HabitWidgetEntity] {
//        let store = HabitWidgetDataStore()
//        let snapshots = store.loadSnapshots()
//        return snapshots.filter { identifiers.contains($0.id) }.map { HabitWidgetEntity(snapshot: $0) }
//    }
//
//    public func suggestedEntities() async throws -> [HabitWidgetEntity] {
//        let store = HabitWidgetDataStore()
//        return store.loadSnapshots().map { HabitWidgetEntity(snapshot: $0) }
//    }
//}
//
//@available(iOSApplicationExtension 17.0, *)
//private extension HabitWidgetEntity {
//    init(snapshot: HabitWidgetSnapshot) {
//        self.init(id: snapshot.id, name: snapshot.name, icon: snapshot.icon, colorHex: snapshot.colorHex)
//    }
//}
