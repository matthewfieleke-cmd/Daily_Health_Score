import XCTest
@testable import DailyHealthScore

final class CoachCalculatorTests: XCTestCase {
    func test_arithmeticWithUnitsPercentAndParentheses() throws {
        XCTAssertEqual(try CoachCalculator.evaluate("250 + 230 + 100"), 580)
        XCTAssertEqual(try CoachCalculator.evaluate("250 kcal + 230 kcal + 100 kcal"), 580)
        XCTAssertEqual(try CoachCalculator.evaluate("20 / 50 * 100"), 40)
        XCTAssertEqual(try CoachCalculator.evaluate("15% of 200"), 30)
        XCTAssertEqual(try CoachCalculator.evaluate("(5 + 7 + 4) * 1"), 16)
        XCTAssertEqual(try CoachCalculator.evaluate("1.4 x 84"), 117.6, accuracy: 0.0001)
        XCTAssertEqual(try CoachCalculator.evaluate("2 ^ 3"), 8)
        XCTAssertEqual(try CoachCalculator.evaluate("-3 + 5"), 2)
        XCTAssertEqual(try CoachCalculator.evaluate("1,250 / 2"), 625)
    }

    func test_errorsAreReportedNotGuessed() {
        XCTAssertThrowsError(try CoachCalculator.evaluate("10 / 0"))
        XCTAssertThrowsError(try CoachCalculator.evaluate(""))
        XCTAssertThrowsError(try CoachCalculator.evaluate("(2 + 3"))
        XCTAssertThrowsError(try CoachCalculator.evaluate("2 + $"))
        XCTAssertTrue(CoachCalculator.answer("abc").contains("Could not evaluate"))
        XCTAssertEqual(CoachCalculator.answer("580 / 2000 * 100"), "580 / 2000 * 100 = 29")
        XCTAssertEqual(CoachCalculator.format(12.5), "12.5")
        XCTAssertEqual(CoachCalculator.format(12.0), "12")
        XCTAssertEqual(CoachCalculator.format(1.333333), "1.33")
    }
}

final class CoachFoodDataTests: XCTestCase {
    private let usdaJSON = """
    {"totalHits": 2, "foods": [
      {"fdcId": 1, "description": "CLIF BAR, OATMEAL RAISIN WALNUT", "dataType": "Branded", "brandOwner": "CLIF BAR & COMPANY", "brandName": "CLIF",
       "servingSize": 68.0, "servingSizeUnit": "g", "householdServingFullText": "1 BAR",
       "foodNutrients": [
         {"nutrientId": 1008, "nutrientName": "Energy", "nutrientNumber": "208", "unitName": "KCAL", "value": 368},
         {"nutrientId": 1003, "nutrientName": "Protein", "nutrientNumber": "203", "unitName": "G", "value": 14.7},
         {"nutrientId": 1079, "nutrientName": "Fiber, total dietary", "nutrientNumber": "291", "unitName": "G", "value": 7.4},
         {"nutrientId": 2000, "nutrientName": "Total Sugars", "nutrientNumber": "269", "unitName": "G", "value": 29.4},
         {"nutrientId": 1235, "nutrientName": "Added Sugars", "nutrientNumber": "539", "unitName": "G", "value": 20.6}
       ]},
      {"fdcId": 2, "description": "Beans, black, mature seeds, cooked, boiled, without salt", "dataType": "SR Legacy",
       "foodNutrients": [
         {"nutrientNumber": "208", "value": 132},
         {"nutrientNumber": "203", "value": 8.86},
         {"nutrientNumber": "291", "value": 8.7}
       ]}
    ]}
    """

    func test_usdaBrandedRowsScaleToTheLabelServing() {
        let facts = USDAFoodParser.facts(fromSearchJSON: Data(usdaJSON.utf8))
        XCTAssertEqual(facts.count, 2)
        let clif = facts[0]
        XCTAssertEqual(clif.name, "Clif Bar, Oatmeal Raisin Walnut")
        XCTAssertEqual(clif.brand, "Clif")
        XCTAssertEqual(clif.servingDescription, "1 BAR (68 g)")
        XCTAssertEqual(clif.calories ?? 0, 250.2, accuracy: 0.11)
        XCTAssertEqual(clif.proteinGrams ?? 0, 10.0, accuracy: 0.11)
        XCTAssertEqual(clif.fiberGrams ?? 0, 5.0, accuracy: 0.11)
        XCTAssertEqual(clif.totalSugarGrams ?? 0, 20.0, accuracy: 0.11)
        XCTAssertEqual(clif.addedSugarGrams ?? 0, 14.0, accuracy: 0.11)
        XCTAssertTrue(clif.line.contains("g added"))
        XCTAssertTrue(clif.line.contains("USDA FoodData Central (Branded)"))

        let beans = facts[1]
        XCTAssertEqual(beans.servingDescription, "")
        XCTAssertTrue(beans.line.contains("per 100 g"))
        XCTAssertEqual(beans.fiberGrams, 8.7)
        XCTAssertNil(beans.addedSugarGrams)
    }

    func test_openFoodFactsPrefersServingValuesWhenPresent() {
        let json = """
        {"products": [
          {"product_name": "Wildberry Protein Oats", "brands": "Seven Sundays, Other", "serving_size": "45 g",
           "nutriments": {"energy-kcal_100g": 400, "energy-kcal_serving": 180, "proteins_serving": 10, "fiber_serving": 5, "sugars_serving": 6, "fat_100g": 8}},
          {"product_name": "", "nutriments": {}}
        ]}
        """
        let facts = OpenFoodFactsParser.facts(fromSearchJSON: Data(json.utf8))
        XCTAssertEqual(facts.count, 1)
        XCTAssertEqual(facts[0].brand, "Seven Sundays")
        XCTAssertEqual(facts[0].servingDescription, "45 g")
        XCTAssertEqual(facts[0].calories, 180)
        XCTAssertEqual(facts[0].proteinGrams, 10)
        XCTAssertEqual(facts[0].fatGrams, 8, "Falls back to per-100 g when no serving value exists")
        XCTAssertEqual(facts[0].source, "Open Food Facts")
    }

    func test_formattedResultsTellTheModelWhatToDoWithThem() {
        XCTAssertTrue(CoachFoodService.formatted([], query: "unicorn bar").contains("label them approximate"))
        let fact = CoachFoodFact(name: "Oats", brand: "", servingDescription: "40 g", calories: 150, proteinGrams: 5, fiberGrams: 4, totalSugarGrams: 1, addedSugarGrams: nil, fatGrams: nil, carbGrams: nil, source: "USDA FoodData Central")
        let text = CoachFoodService.formatted([fact], query: "oats")
        XCTAssertTrue(text.contains("1. Oats — per 40 g: 150 kcal · 5 g protein · 4 g fiber · 1 g sugars"))
        XCTAssertTrue(text.contains("calculator"))
    }

    func test_urlsCarryOnlyTheFoodName() {
        let url = CoachFoodService.usdaSearchURL(query: "clif oatmeal raisin walnut", key: "TESTKEY")
        XCTAssertEqual(url?.host, "api.nal.usda.gov")
        XCTAssertTrue(url?.query?.contains("api_key=TESTKEY") == true)
        XCTAssertTrue(url?.query?.contains("query=clif%20oatmeal%20raisin%20walnut") == true)
        XCTAssertEqual(CoachFoodService.openFoodFactsSearchURL(query: "oats")?.host, "world.openfoodfacts.org")
        XCTAssertEqual(CoachSecrets.usdaKey(bundle: Bundle(for: CoachFoodDataTests.self)), CoachSecrets.usdaDemoKey)
    }

    func test_pubMedParsing() {
        let search = """
        {"esearchresult": {"count": "2", "idlist": ["12345678", "23456789"]}}
        """
        XCTAssertEqual(PubMedParser.ids(fromSearchJSON: Data(search.utf8)), ["12345678", "23456789"])
        let abstracts = """
        1. J Nutr. 2020 Jan;150(1):1-10.

        Dietary fiber and satiety: a systematic review.

        Fiber intake was associated with greater fullness across 22 trials.

        PMID: 12345678


        2. Appetite. 2019;140:1-9.

        Breakfast composition and morning hunger.

        Protein and fiber at breakfast reduced mid-morning hunger.

        PMID: 23456789
        """
        let records = PubMedParser.records(fromAbstractText: abstracts)
        XCTAssertEqual(records.count, 2)
        XCTAssertTrue(records[0].contains("PMID: 12345678"))
        XCTAssertTrue(records[1].contains("Breakfast composition"))
    }
}

final class BodyTrendTests: XCTestCase {
    private var calendar: Calendar!
    private var now: Date!

    override func setUp() {
        super.setUp()
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/Chicago")!
        calendar = cal
        now = cal.date(from: DateComponents(year: 2026, month: 9, day: 20, hour: 8))!
    }

    private func sample(daysAgo: Int, kg: Double) -> BodyWeightSample {
        BodyWeightSample(date: calendar.date(byAdding: .day, value: -daysAgo, to: now)!, kilograms: kg)
    }

    func test_trendUsesSevenDayAveragesAndANoiseBand() {
        var weights: [BodyWeightSample] = []
        for day in 0..<90 {
            // Gradual loss of about 1.2 kg over 84 days with a daily wobble:
            // 0.4 kg over four weeks (inside the noise band), 1.2 kg over twelve.
            let base = 86.0 - Double(day) * (1.2 / 84)
            let wobble = day % 2 == 0 ? 0.3 : -0.3
            weights.append(sample(daysAgo: 90 - day, kg: base + wobble))
        }
        let trend = BodyTrend.build(from: BodyMeasurements(weights: weights, heightMeters: 1.80), now: now, calendar: calendar)!
        XCTAssertEqual(trend.direction4w, .steady, "Under half a kilogram over four weeks is inside the noise band")
        XCTAssertEqual(trend.direction12w, .down)
        XCTAssertEqual(trend.bmi ?? 0, 26.2, accuracy: 0.4)
        XCTAssertEqual(trend.readingCount, 90)
        XCTAssertTrue(trend.promptBlock.contains("seven-day average"))
        XCTAssertTrue(trend.promptBlock.contains("Steady over the last four weeks"))
        XCTAssertTrue(trend.promptBlock.contains("Down about"))
        XCTAssertTrue(trend.promptBlock.contains("screening number"))
    }

    func test_staleAndSparseDataSaySo() {
        let stale = BodyTrend.build(
            from: BodyMeasurements(weights: [sample(daysAgo: 30, kg: 84)], heightMeters: nil),
            now: now, calendar: calendar
        )!
        XCTAssertTrue(stale.promptBlock.contains("30 days old"))
        XCTAssertTrue(stale.promptBlock.contains("Not enough readings"))
        XCTAssertNil(stale.bmi)
        XCTAssertNil(BodyTrend.build(from: BodyMeasurements(), now: now, calendar: calendar))
        let bmiOnly = BodyTrend.build(from: BodyMeasurements(latestBMISample: 24.2), now: now, calendar: calendar)!
        XCTAssertEqual(bmiOnly.bmi, 24.2)
        XCTAssertTrue(bmiOnly.promptBlock.contains("in the usual range"))
    }

    func test_bmiBandsAreLabelsNotVerdicts() {
        XCTAssertEqual(BodyTrend.bmiBand(17.9), "below the usual range")
        XCTAssertEqual(BodyTrend.bmiBand(22), "in the usual range")
        XCTAssertEqual(BodyTrend.bmiBand(27.9), "in the overweight screening range")
        XCTAssertEqual(BodyTrend.bmiBand(31), "in the obesity screening range")
    }
}

final class CoachReplyShapingTests: XCTestCase {
    func test_shapesFollowTheQuestion() {
        XCTAssertEqual(CoachReplyShape.detect(message: "Is the breakfast I described a healthy breakfast?", intent: .education), .evaluation)
        XCTAssertEqual(CoachReplyShape.detect(message: "How do I increase the likelihood I make the healthier choice?", intent: .planning), .howTo)
        XCTAssertEqual(CoachReplyShape.detect(message: "Help me set a goal around an evening walk.", intent: .planning), .howTo)
        XCTAssertEqual(CoachReplyShape.detect(message: "I’ve been doing better recently with not bringing work home.", intent: .general), .winReport)
        XCTAssertEqual(CoachReplyShape.detect(message: "There’s a breakfast I like to do that includes oats and tea.", intent: .general), .statement)
        XCTAssertEqual(CoachReplyShape.detect(message: "I find myself feeling insecure about work.", intent: .support), .feeling)
        XCTAssertEqual(CoachReplyShape.detect(message: "How did this week go for me?", intent: .dataLookup), .data)
        XCTAssertEqual(CoachReplyShape.detect(message: "Thanks, that helped.", intent: .smallTalk), .smallTalk)
        XCTAssertEqual(CoachReplyShape.detect(message: "Should I take magnesium for sleep?", intent: .education), .general)
    }

    func test_reasoningDepthScalesWithTheShape() {
        XCTAssertEqual(CoachReplyShape.howTo.reasoningDepth, .deep)
        XCTAssertEqual(CoachReplyShape.evaluation.reasoningDepth, .deep)
        XCTAssertEqual(CoachReplyShape.feeling.reasoningDepth, .moderate)
        XCTAssertEqual(CoachReplyShape.smallTalk.reasoningDepth, .light)
        XCTAssertEqual(CoachReplyShape.data.reasoningDepth, .light)
        XCTAssertTrue(CoachReplyShape.howTo.hint.contains("four numbered levers"))
    }

    func test_repetitionGuardListsEarlierSuggestions() {
        let earlier = [
            "You've built a morning routine. You could try swapping one bar for a cup of cooked beans. This keeps your rhythm.",
            "Breakfast is repeatable. You could keep the oats and tea but swap one bar for a cup of cooked beans or add chia seeds."
        ]
        let lines = CoachRepetitionGuard.alreadySuggested(in: earlier)
        XCTAssertEqual(lines.count, 2)
        XCTAssertTrue(lines.contains { $0.contains("swap one bar for a cup of cooked beans or add chia") })
        XCTAssertTrue(CoachRepetitionGuard.promptBlock(in: earlier)?.hasPrefix("ALREADY SUGGESTED IN THIS CHAT") == true)
        XCTAssertNil(CoachRepetitionGuard.promptBlock(in: ["Good morning."]))
    }

    func test_polishStripsTokensAndCapsRunawayLength() {
        XCTAssertEqual(CoachReplyPolish.polish("Fiber is at 7 g — BELOW GOAL by 33 g today."), "Fiber is at 7 g by 33 g today.")
        let paragraph = Array(repeating: "Ten words in this sentence to fill space right here.", count: 12).joined(separator: " ")
        let long = Array(repeating: paragraph, count: 6).joined(separator: "\n\n")
        XCTAssertGreaterThan(CoachReplyPolish.wordCount(long), 600)
        let polished = CoachReplyPolish.polish(long)
        XCTAssertLessThanOrEqual(CoachReplyPolish.wordCount(polished), CoachCharter.maxReplyWords)
        XCTAssertTrue(polished.contains("\n\n"), "Paragraph breaks survive the cut")
        let short = "Yes — mostly.\n\n- one\n- two"
        XCTAssertEqual(CoachReplyPolish.polish(short), short)
    }
}

final class CoachEvalPromptsTests: XCTestCase {
    func test_setCoversTheShapesAndExports() {
        XCTAssertEqual(CoachEvalPrompts.all.count, 10)
        XCTAssertEqual(Set(CoachEvalPrompts.all.map(\.id)).count, 10)
        XCTAssertTrue(CoachEvalPrompts.all.allSatisfy { !$0.rubric.isEmpty })
        let result = CoachEvalResult(promptID: "stress-numbing", reply: "**Yes.**", tier: .privateCloud, shape: .howTo, memoryNotes: ["add · Likes & staples · stated: Yoga"], seconds: 12.3)
        let export = CoachEvalPrompts.export(results: [result])
        XCTAssertTrue(export.contains("## Stress numbing and Clash Royale"))
        XCTAssertTrue(export.contains("Model: privateCloud · shape: howTo · 12.3s"))
        XCTAssertTrue(export.contains("- [ ] "))
        XCTAssertTrue(export.contains("- add · Likes & staples · stated: Yoga"))
    }
}
