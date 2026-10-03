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

    /// Illustration in the asset catalog. The stored case name stays `fish`.
    var imageName: String {
        switch self {
        case .vegetables: return "FoodGroupVegetables"
        case .fruit: return "FoodGroupFruit"
        case .wholeGrains: return "FoodGroupWholeGrains"
        case .legumesNuts: return "FoodGroupLegumes"
        case .fish: return "FoodGroupProtein"
        case .limited: return "FoodGroupLimited"
        }
    }

    var title: String {
        switch self {
        case .vegetables: return "Vegetables"
        case .fruit: return "Fruit"
        case .wholeGrains: return "Whole grains"
        case .legumesNuts: return "Legumes / nuts"
        case .fish: return "Healthy protein (fish or plant protein)"
        case .limited: return "Foods to limit"
        }
    }

    var hint: String {
        switch self {
        case .vegetables: return "1 fist"
        case .fruit: return "1 fist, or a handful of berries"
        case .wholeGrains: return "1 cupped hand, cooked"
        case .legumesNuts: return "1 cupped hand of beans, or a small handful of nuts"
        case .fish: return "1 palm of fish, tofu, or tempeh"
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

    /// What the info sheet says. Scoring is unchanged; this is the explanation.
    var guide: FoodGroupGuide {
        switch self {
        case .vegetables:
            return FoodGroupGuide(
                summary: "A pattern built around vegetables is one of the most consistent findings in heart and diabetes guidance. On a typical 2,000-calorie day, that is about 3 servings, from more than one color.",
                serving: "One fist of cooked vegetables, or a fist of raw leaves.",
                counts: [
                    "Broccoli, cauliflower, cabbage, kale, and other cruciferous vegetables.",
                    "Leafy greens, peppers, carrots, tomatoes, and other non-starchy vegetables.",
                    "Fresh, frozen, or canned vegetables with no added sauce."
                ],
                doesNotCount: [
                    "White potatoes and fries. Heart guidance does not treat them as the vegetables linked with lower risk.",
                    "Beans, lentils, and peas. Log those under Legumes / nuts.",
                    "Vegetable juice."
                ],
                note: Self.antioxidantNote
            )
        case .fruit:
            return FoodGroupGuide(
                summary: "Whole fruit, about 2 servings a day, is the form these guidelines prefer. The fiber and water are part of why it helps.",
                serving: "One fist of whole fruit, or a handful of berries.",
                counts: [
                    "Berries, apples, pears, citrus, and other whole fruit.",
                    "Frozen fruit with nothing added.",
                    "Raisins and fruit canned in syrup still count. Berries and unsweetened whole fruit do more of the useful work."
                ],
                doesNotCount: [
                    "Juice, including 100% juice. Guidelines treat juice as something to limit, not as a whole-fruit serving.",
                    "Fruit drinks, sweetened smoothies, and fruit snacks."
                ],
                note: Self.antioxidantNote
            )
        case .wholeGrains:
            return FoodGroupGuide(
                summary: "Choose grains that are still whole. A common goal is 2 to 4 servings a day. This log uses 3. Whole grains in place of refined grains improve cholesterol and blood sugar in trials.",
                serving: "One cupped hand of cooked grain, or one slice of whole-grain bread.",
                counts: [
                    "Cooked oats, brown rice, quinoa, barley, or bulgur.",
                    "One slice of bread whose first ingredient is a whole grain.",
                    "Whole-grain pasta, in the same cupped-hand portion."
                ],
                doesNotCount: [
                    "White rice, white bread, and other refined grains.",
                    "A food labeled multigrain or wheat when the first ingredient is not a whole grain."
                ]
            )
        case .legumesNuts:
            return FoodGroupGuide(
                summary: "Beans, lentils, nuts, and seeds are the plant proteins heart guidance puts first. They are their own group here, separate from the vegetable fist and from the healthy-protein palm.",
                serving: "One cupped hand of cooked beans or lentils, or a small handful of nuts. Nut butter is about 2 tablespoons: a small spoon, not a cup.",
                counts: [
                    "Beans, lentils, split peas, and hummus.",
                    "A small handful of unsalted or lightly salted nuts or seeds.",
                    "About 2 tablespoons of peanut butter or another nut butter."
                ],
                doesNotCount: [
                    "The same beans logged again under Healthy protein. Count each food once.",
                    "A cup of nut butter, or nuts coated in candy or sugar."
                ]
            )
        case .fish:
            return FoodGroupGuide(
                summary: "This serving is fish or a plant protein, not poultry or red meat. Heart guidance favors fish or other seafood about twice a week, cooked without frying, and plant proteins such as tofu and tempeh.",
                serving: "One palm, about 3 ounces cooked. Fish, tofu, or tempeh.",
                counts: [
                    "Salmon, sardines, tuna, and other fish, baked, broiled, or grilled.",
                    "Other seafood in the same palm-sized portion.",
                    "Tofu, tempeh, or a palm of edamame when it is not already logged as a legume."
                ],
                doesNotCount: [
                    "Chicken, eggs, and red meat. They are protein, but they are not this serving.",
                    "Fried fish. The benefit seen with fish does not show up when it is fried.",
                    "Beans, lentils, or nuts already logged under Legumes / nuts."
                ]
            )
        case .limited:
            return FoodGroupGuide(
                summary: "These points start yours. Each serving you log gives a third of them back, and three servings remove the point. Heart guidance is most direct about sugary drinks, processed meat, and ultra-processed meals.",
                serving: "One glass or can of a sugary drink, one processed meat, or one fast-food meal.",
                counts: [
                    "One glass or can of soda, sweet tea, or another sugary drink.",
                    "One serving of bacon, sausage, a hot dog, or deli meat.",
                    "One fast-food meal or other ultra-processed meal."
                ],
                doesNotCount: [
                    "Fruit, nuts, beans, or a meal you cooked. Those belong in the groups above.",
                    "Salt and alcohol are worth watching. They are not this counter."
                ]
            )
        }
    }

    static let antioxidantNote = "Dark leafy greens, cruciferous vegetables such as broccoli, cauliflower, purple cabbage, and kale, and berries are particularly high in antioxidants, which help our cells stay healthy."
}

struct FoodGroupGuide: Equatable, Sendable {
    var summary: String
    var serving: String
    var counts: [String]
    var doesNotCount: [String]
    /// Shown only for vegetables and fruit.
    var note: String? = nil
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
