import Foundation

/// How nutrition earns its 4 points.
enum NutritionMode: String, Codable, CaseIterable, Identifiable, Sendable {
    case fiber
    case foodGroups

    var id: String { rawValue }

    var settingsLabel: String {
        switch self {
        case .fiber: return "Fiber · Apple Health"
        case .foodGroups: return "Food groups · log in the app"
        }
    }

    var cardTitle: String {
        switch self {
        case .fiber: return "Fiber"
        case .foodGroups: return "Food groups"
        }
    }
}

/// One saved food-group day. `isLogged` distinguishes “never opened” (0 points)
/// from “saved with every stepper at zero” (the limit points are still there).
struct FoodGroupServings: Equatable, Codable, Sendable {
    var vegetables: Int = 0
    var fruit: Int = 0
    var wholeGrains: Int = 0
    var legumesNuts: Int = 0
    var fish: Int = 0
    var limited: Int = 0
    var isLogged: Bool = false

    static let maxCount = 20

    static let empty = FoodGroupServings()

    subscript(group: FoodGroup) -> Int {
        get {
            switch group {
            case .vegetables: return vegetables
            case .fruit: return fruit
            case .wholeGrains: return wholeGrains
            case .legumesNuts: return legumesNuts
            case .fish: return fish
            case .limited: return limited
            }
        }
        set {
            let clamped = min(max(newValue, 0), Self.maxCount)
            switch group {
            case .vegetables: vegetables = clamped
            case .fruit: fruit = clamped
            case .wholeGrains: wholeGrains = clamped
            case .legumesNuts: legumesNuts = clamped
            case .fish: fish = clamped
            case .limited: limited = clamped
            }
        }
    }
}

enum FoodGroup: String, CaseIterable, Identifiable, Sendable {
    case vegetables
    case fruit
    case wholeGrains
    case legumesNuts
    case fish
    case limited

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vegetables: return "Vegetables"
        case .fruit: return "Fruit"
        case .wholeGrains: return "Whole grains"
        case .legumesNuts: return "Legumes / nuts"
        case .fish: return "Fish"
        case .limited: return "Foods to limit"
        }
    }

    var hint: String {
        switch self {
        case .vegetables: return "1 fist"
        case .fruit: return "1 fist, or a handful of berries"
        case .wholeGrains: return "1 cupped hand, cooked"
        case .legumesNuts: return "1 cupped hand of beans, or a small handful of nuts"
        case .fish: return "1 palm"
        case .limited: return "1 glass, 1 processed meat, or 1 fast-food meal"
        }
    }

    var target: Int {
        switch self {
        case .vegetables: return 3
        case .fruit: return 2
        case .wholeGrains: return 3
        case .legumesNuts: return 2
        case .fish: return 1
        case .limited: return 0
        }
    }

    /// Eat-more groups. Limit is scored in the other direction.
    var isEatMore: Bool { self != .limited }

    var examples: [String] {
        switch self {
        case .vegetables:
            return [
                "Dark leafy greens, broccoli, cauliflower, purple cabbage, and kale.",
                "A fist of cooked vegetables, or a fist of raw leaves.",
                "Beans belong under Legumes / nuts, not here.",
                "Potatoes are not a vegetable serving."
            ]
        case .fruit:
            return [
                "Berries, a fist of whole fruit, or a handful of berries.",
                "Raisins and canned peaches in heavy syrup still count as a serving.",
                "They do less of the work berries do.",
                "Juice is not a fruit serving."
            ]
        case .wholeGrains:
            return [
                "A cupped hand of cooked oats, brown rice, quinoa, or barley.",
                "One slice of whole-grain bread.",
                "Refined bread and white rice do not count."
            ]
        case .legumesNuts:
            return [
                "A cupped hand of beans or lentils.",
                "A small handful of nuts.",
                "Peanut butter: a small spoon, not a cup."
            ]
        case .fish:
            return [
                "A palm of fish.",
                "Tuna, salmon, sardines, and other fish count.",
                "Chicken and red meat do not count here."
            ]
        case .limited:
            return [
                "One glass or can of a sugary drink.",
                "One serving of processed meat, such as bacon, sausage, or deli meat.",
                "One fast-food or ultra-processed meal."
            ]
        }
    }

    var showsAntioxidantNote: Bool {
        self == .vegetables || self == .fruit
    }

    static let antioxidantNote = "Dark leafy greens, cruciferous vegetables such as broccoli, cauliflower, purple cabbage, and kale, and berries are particularly high in antioxidants, which help our cells stay healthy."
}

enum FoodGroupScore {
    /// Exact points before display rounding. Unlogged days are 0.
    /// A saved day with every stepper at zero is 1, because the limit points remain.
    static func points(_ servings: FoodGroupServings) -> Double {
        guard servings.isLogged else { return 0 }
        let vegetables = fill(servings.vegetables, target: 3) * 1.0
        let fruit = fill(servings.fruit, target: 2) * 0.7
        let grains = fill(servings.wholeGrains, target: 3) * 0.5
        let legumes = fill(servings.legumesNuts, target: 2) * 0.5
        let fish = fill(servings.fish, target: 1) * 0.3
        let limit = max(1.0 - (Double(servings.limited) / 3.0), 0)
        return min(vegetables + fruit + grains + legumes + fish + limit, 4)
    }

    static func groupFill(_ count: Int, group: FoodGroup) -> Double {
        guard group.isEatMore else {
            return max(1.0 - (Double(count) / 3.0), 0)
        }
        return fill(count, target: group.target)
    }

    /// What the ring would show if this draft were saved. Editing does not save.
    static func previewPoints(_ servings: FoodGroupServings) -> Double {
        var logged = servings
        logged.isLogged = true
        return points(logged)
    }

    /// Tile text. Vegetables and grains use thirds. Nothing on a tile is a decimal.
    static func tileLabel(count: Int, group: FoodGroup) -> String {
        switch group {
        case .vegetables, .wholeGrains:
            if count <= 0 { return "0" }
            if count == 1 { return "1/3" }
            if count == 2 { return "2/3" }
            return "Full"
        case .fruit, .legumesNuts:
            if count <= 0 { return "0" }
            if count >= group.target { return "Full" }
            return "\(count) of \(group.target)"
        case .fish:
            return count >= 1 ? "Full" : "0"
        case .limited:
            switch min(max(count, 0), 3) {
            case 0: return "Full"
            case 1: return "2/3"
            case 2: return "1/3"
            default: return "0"
            }
        }
    }

    private static func fill(_ count: Int, target: Int) -> Double {
        guard target > 0 else { return 0 }
        return min(max(Double(count), 0) / Double(target), 1)
    }
}
