import Foundation

/// One food as the Coach receives it: a label's worth of facts per serving.
struct CoachFoodFact: Equatable, Sendable {
    var name: String
    var brand: String
    var servingDescription: String
    var calories: Double?
    var proteinGrams: Double?
    var fiberGrams: Double?
    var totalSugarGrams: Double?
    var addedSugarGrams: Double?
    var fatGrams: Double?
    var carbGrams: Double?
    var saturatedFatGrams: Double? = nil
    var sodiumMg: Double? = nil
    var potassiumMg: Double? = nil
    var calciumMg: Double? = nil
    var ironMg: Double? = nil
    var magnesiumMg: Double? = nil
    var source: String

    var missingCoreNutrients: [String] {
        [
            ("calories", calories),
            ("protein", proteinGrams),
            ("fiber", fiberGrams),
            ("sugars", totalSugarGrams),
            ("fat", fatGrams),
            ("carbohydrate", carbGrams)
        ].compactMap { label, value in value == nil ? label : nil }
    }

    var isPartialLabel: Bool { !missingCoreNutrients.isEmpty }

    /// "Clif Oatmeal Raisin Walnut (Clif Bar) — per 68 g bar: 250 kcal · 10 g protein · 5 g fiber · 20 g sugars (14 g added) · 180 mg sodium — USDA"
    var line: String {
        var parts: [String] = []
        if let calories { parts.append("\(CoachCalculator.format(calories)) kcal") }
        if let proteinGrams { parts.append("\(CoachCalculator.format(proteinGrams)) g protein") }
        if let fiberGrams { parts.append("\(CoachCalculator.format(fiberGrams)) g fiber") }
        if let totalSugarGrams {
            var sugar = "\(CoachCalculator.format(totalSugarGrams)) g sugars"
            if let addedSugarGrams { sugar += " (\(CoachCalculator.format(addedSugarGrams)) g added)" }
            parts.append(sugar)
        } else if let addedSugarGrams {
            parts.append("\(CoachCalculator.format(addedSugarGrams)) g added sugar")
        }
        if let fatGrams {
            var fat = "\(CoachCalculator.format(fatGrams)) g fat"
            if let saturatedFatGrams { fat += " (\(CoachCalculator.format(saturatedFatGrams)) g saturated)" }
            parts.append(fat)
        }
        if let carbGrams { parts.append("\(CoachCalculator.format(carbGrams)) g carbs") }
        for (value, label) in [(sodiumMg, "sodium"), (potassiumMg, "potassium"), (calciumMg, "calcium"), (ironMg, "iron"), (magnesiumMg, "magnesium")] {
            if let value { parts.append("\(CoachCalculator.format(value.rounded())) mg \(label)") }
        }
        let brandText = brand.isEmpty ? "" : " (\(brand))"
        let serving = servingDescription.isEmpty ? "per 100 g" : "per \(servingDescription)"
        let partial = isPartialLabel
            ? " — partial label (missing \(missingCoreNutrients.joined(separator: ", ")))"
            : ""
        return "\(name)\(brandText) — \(serving): \(parts.isEmpty ? "no nutrient values listed" : parts.joined(separator: " · ")) — \(source)\(partial)"
    }
}

/// Parses USDA FoodData Central search results. Branded rows carry label
/// values per serving; Foundation and SR Legacy rows are per 100 g.
enum USDAFoodParser {
    /// Nutrient numbers from the USDA schema.
    private enum Nutrient: String {
        case energy = "208"
        case energyAtwater = "957"
        case protein = "203"
        case fat = "204"
        case carbs = "205"
        case fiber = "291"
        case sugars = "269"
        case addedSugars = "539"
        case saturatedFat = "606"
        case calcium = "301"
        case iron = "303"
        case magnesium = "304"
        case potassium = "306"
        case sodium = "307"
    }

    static func facts(fromSearchJSON data: Data, limit: Int = 3) -> [CoachFoodFact] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let foods = root["foods"] as? [[String: Any]] else { return [] }
        return foods.prefix(limit).compactMap { fact(from: $0) }
    }

    static func fact(from food: [String: Any]) -> CoachFoodFact? {
        guard let description = (food["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !description.isEmpty else { return nil }
        let brand = ((food["brandName"] as? String) ?? (food["brandOwner"] as? String) ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let nutrients = (food["foodNutrients"] as? [[String: Any]]) ?? []
        var per100: [String: Double] = [:]
        for nutrient in nutrients {
            let number: String?
            if let value = nutrient["nutrientNumber"] as? String {
                number = value
            } else if let value = nutrient["nutrientNumber"] as? Int {
                number = String(value)
            } else if let value = nutrient["number"] as? String {
                number = value
            } else {
                number = nil
            }
            guard let number else { continue }
            let amount = (nutrient["value"] as? Double) ?? (nutrient["amount"] as? Double)
                ?? (nutrient["value"] as? Int).map(Double.init) ?? (nutrient["amount"] as? Int).map(Double.init)
            guard let amount else { continue }
            per100[number] = amount
        }
        // Branded label values are expressed per 100 g; scale to the stated serving.
        var servingDescription = ""
        var scale = 1.0
        if let servingSize = food["servingSize"] as? Double, servingSize > 0 {
            let unit = ((food["servingSizeUnit"] as? String) ?? "g").lowercased()
            let household = ((food["householdServingFullText"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if unit == "g" || unit == "ml" || unit == "grm" || unit == "mlt" {
                scale = servingSize / 100
                let unitLabel = unit.hasPrefix("m") ? "ml" : "g"
                servingDescription = household.isEmpty
                    ? "\(CoachCalculator.format(servingSize)) \(unitLabel)"
                    : "\(household) (\(CoachCalculator.format(servingSize)) \(unitLabel))"
            }
        }
        func value(_ nutrient: Nutrient) -> Double? {
            per100[nutrient.rawValue].map { ($0 * scale * 10).rounded() / 10 }
        }
        let calories = value(.energy) ?? value(.energyAtwater)
        let dataType = (food["dataType"] as? String) ?? ""
        let source = dataType.isEmpty ? "USDA FoodData Central" : "USDA FoodData Central (\(dataType))"
        let display = description.count > 4 && description == description.uppercased()
            ? description.capitalized
            : description
        return CoachFoodFact(
            name: display,
            brand: brand.count >= 3 && brand == brand.uppercased() ? brand.capitalized : brand,
            servingDescription: servingDescription,
            calories: calories,
            proteinGrams: value(.protein),
            fiberGrams: value(.fiber),
            totalSugarGrams: value(.sugars),
            addedSugarGrams: value(.addedSugars),
            fatGrams: value(.fat),
            carbGrams: value(.carbs),
            saturatedFatGrams: value(.saturatedFat),
            sodiumMg: value(.sodium),
            potassiumMg: value(.potassium),
            calciumMg: value(.calcium),
            ironMg: value(.iron),
            magnesiumMg: value(.magnesium),
            source: source
        )
    }
}

/// Parses Open Food Facts v2 search results. Values are per 100 g with a
/// per-serving variant when the product lists a serving size.
enum OpenFoodFactsParser {
    static func facts(fromSearchJSON data: Data, limit: Int = 3) -> [CoachFoodFact] {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let products = root["products"] as? [[String: Any]] else { return [] }
        return products.prefix(limit).compactMap { fact(from: $0) }
    }

    static func fact(from product: [String: Any]) -> CoachFoodFact? {
        let name = ((product["product_name"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        let brand = ((product["brands"] as? String) ?? "")
            .split(separator: ",").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? ""
        let nutriments = (product["nutriments"] as? [String: Any]) ?? [:]
        let serving = ((product["serving_size"] as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let hasServing = !serving.isEmpty && nutriments["energy-kcal_serving"] != nil
        func number(_ key: String) -> Double? {
            if let value = nutriments[key] as? Double { return (value * 10).rounded() / 10 }
            if let value = nutriments[key] as? Int { return Double(value) }
            if let text = nutriments[key] as? String, let value = Double(text) { return (value * 10).rounded() / 10 }
            return nil
        }
        func value(_ base: String) -> Double? {
            hasServing ? number("\(base)_serving") : number("\(base)_100g")
        }
        // Open Food Facts lists minerals in grams; the label reads in milligrams.
        func milligrams(_ base: String) -> Double? {
            let key = hasServing ? "\(base)_serving" : "\(base)_100g"
            guard let raw = nutriments[key] else { return nil }
            let grams: Double?
            if let value = raw as? Double { grams = value }
            else if let value = raw as? Int { grams = Double(value) }
            else if let text = raw as? String { grams = Double(text) }
            else { grams = nil }
            return grams.map { ($0 * 1000).rounded() }
        }
        return CoachFoodFact(
            name: name,
            brand: brand,
            servingDescription: hasServing ? serving : "",
            calories: value("energy-kcal"),
            proteinGrams: value("proteins"),
            fiberGrams: value("fiber"),
            totalSugarGrams: value("sugars"),
            addedSugarGrams: value("added-sugars"),
            fatGrams: value("fat"),
            carbGrams: value("carbohydrates"),
            saturatedFatGrams: value("saturated-fat"),
            sodiumMg: milligrams("sodium"),
            potassiumMg: milligrams("potassium"),
            calciumMg: milligrams("calcium"),
            ironMg: milligrams("iron"),
            magnesiumMg: milligrams("magnesium"),
            source: "Open Food Facts"
        )
    }
}

/// Keys the app ships with. Read from a gitignored Secrets.plist so nothing
/// sensitive lives in the repository; DEMO_KEY keeps lookups working without it.
enum CoachSecrets {
    static let usdaDemoKey = "DEMO_KEY"

    static func usdaKey(bundle: Bundle = .main) -> String {
        guard let url = bundle.url(forResource: "Secrets", withExtension: "plist"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let key = (plist["USDAFoodDataKey"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
              !key.isEmpty else {
            return usdaDemoKey
        }
        return key
    }

    static var hasUSDAKey: Bool { usdaKey() != usdaDemoKey }
}
