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
         {"nutrientNumber": "291", "value": 8.7},
         {"nutrientNumber": "304", "value": 70},
         {"nutrientNumber": "306", "value": 355},
         {"nutrientNumber": "307", "value": 1}
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
        XCTAssertEqual(beans.magnesiumMg, 70)
        XCTAssertTrue(beans.line.contains("70 mg magnesium"))
        XCTAssertTrue(beans.line.contains("355 mg potassium"))
        XCTAssertNil(clif.magnesiumMg, "Minerals appear only when the source lists them")
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
        let missing = CoachFoodService.formatted([], query: "unicorn bar")
        XCTAssertTrue(missing.contains("No database match"))
        XCTAssertTrue(missing.contains("Do not invent label values"))
        XCTAssertTrue(missing.contains("label or a photo"))
        XCTAssertFalse(missing.lowercased().contains("estimate"))
        let unavailable = CoachFoodService.formatted([], query: "unicorn bar", failures: ["USDA: HTTP 429 rate limited", "Open Food Facts: timed out"])
        XCTAssertTrue(unavailable.contains("Food lookup unavailable"))
        XCTAssertTrue(unavailable.contains("HTTP 429 rate limited"))
        XCTAssertTrue(unavailable.contains("Say the database did not respond"))
        XCTAssertTrue(unavailable.contains("Do not invent label values"))
        XCTAssertEqual(CoachFoodService.FetchFailure.http(429).description, "HTTP 429 rate limited")
        XCTAssertEqual(CoachFoodService.FetchFailure.http(503).description, "HTTP 503")
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
        XCTAssertTrue(bmiOnly.promptBlock.contains("BMI about 24.2."))
    }

    /// Kilograms stay canonical; the words follow the unit the person weighs in.
    func test_weightSpeaksInThePersonsUnit() {
        var measurements = BodyMeasurements(weights: [sample(daysAgo: 0, kg: 122.1)], heightMeters: 1.83)
        measurements.unit = .pounds
        let pounds = BodyTrend.build(from: measurements, now: now, calendar: calendar)!
        XCTAssertEqual(pounds.unit, .pounds)
        XCTAssertTrue(pounds.promptBlock.contains("269.2 lb"), pounds.promptBlock)
        XCTAssertFalse(pounds.promptBlock.contains("kg"))
        XCTAssertTrue(pounds.promptBlock.contains("Speak in pounds"))
        XCTAssertEqual(pounds.bmi ?? 0, 36.5, accuracy: 0.1, "BMI is unit-free")

        measurements.unit = .kilograms
        let kilos = BodyTrend.build(from: measurements, now: now, calendar: calendar)!
        XCTAssertTrue(kilos.promptBlock.contains("122.1 kg"))
        XCTAssertTrue(kilos.promptBlock.contains("Speak in kilograms"))

        var withPerson = measurements
        withPerson.ageYears = 43
        withPerson.biologicalSex = "male"
        let person = BodyTrend.build(from: withPerson, now: now, calendar: calendar)!
        XCTAssertTrue(person.promptBlock.contains("Person: age 43, male per Health"))
        XCTAssertTrue(person.promptBlock.contains("never guess an age"))
        let ageOnly = BodyTrend.build(from: BodyMeasurements(ageYears: 43), now: now, calendar: calendar)
        XCTAssertNotNil(ageOnly, "Age alone is worth carrying")
        XCTAssertFalse(ageOnly!.promptBlock.contains("Speak in"), "No weight, no unit sentence")

        XCTAssertEqual(BodyMassUnit.preferred(for: Locale(identifier: "en_US")), .pounds)
        XCTAssertEqual(BodyMassUnit.preferred(for: Locale(identifier: "de_DE")), .kilograms)
        XCTAssertEqual(BodyMassUnit.pounds.text(fromKilograms: 0.5), "1.1 lb")
    }

    /// BMI is handed over as a number. Naming a screening band, or warning that
    /// the number is blind to muscle, is interpretation the coach can do itself.
    func test_bmiIsHandedOverAsANumber() {
        var measurements = BodyMeasurements(weights: [sample(daysAgo: 0, kg: 122.1)], heightMeters: 1.83)
        measurements.unit = .pounds
        let block = BodyTrend.build(from: measurements, now: now, calendar: calendar)!.promptBlock
        XCTAssertTrue(block.contains("BMI about 36.5."), block)
        XCTAssertFalse(block.lowercased().contains("screening"))
        XCTAssertFalse(block.lowercased().contains("obesity"))
        XCTAssertFalse(block.lowercased().contains("verdict"))
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

    /// The eval run routed three prompts wrong; the classifier's intent must not
    /// override what the words plainly say.
    func test_shapesSurviveAWrongIntent() {
        let win = "I’ve been doing better recently with not bringing work home. I am a family medicine physician. I’m getting my notes and patient messages all taken care of while at work."
        XCTAssertEqual(CoachReplyShape.detect(message: win, intent: .dataLookup), .winReport)
        let insecure = "I find myself feeling insecure about work. My office manager is moving to a different clinic."
        XCTAssertEqual(CoachReplyShape.detect(message: insecure, intent: .general), .feeling)
        XCTAssertEqual(CoachReplyShape.detect(message: "How did this week go for me?", intent: .planning), .data)
        XCTAssertEqual(CoachReplyShape.detect(message: "Show me my sleep this week", intent: .dataLookup), .data)
        XCTAssertEqual(CoachReplyShape.detect(message: "This week was rough at the clinic.", intent: .dataLookup), .statement)
        let numb = "I feel chronic stress and I think I’m using that to numb myself a bit. How do I increase the likelihood I make the healthier choice?"
        XCTAssertEqual(CoachReplyShape.detect(message: numb, intent: .planning), .howTo, "A how-do-I with a feeling in it is still a how-do-I")
    }

    /// The model sometimes starts the next structured field inside the message.
    func test_polishDropsLeakedOutputFields() {
        let leaked = "Thanks, Matt — that gives me a clear picture. Who's at home and who matters most to you?\n\nmemoryUpdates: [{"
        XCTAssertEqual(CoachReplyPolish.polish(leaked), "Thanks, Matt — that gives me a clear picture. Who's at home and who matters most to you?")
        XCTAssertEqual(CoachReplyPolish.stripLeakedFields("Good morning.\ngoalCheckIn: null\ngoalProposal: {"), "Good morning.")
        XCTAssertEqual(CoachReplyPolish.stripLeakedFields("message: Yes — mostly."), "Yes — mostly.")
        XCTAssertEqual(CoachReplyPolish.stripLeakedFields("Here is the message: be kind to yourself."), "Here is the message: be kind to yourself.", "A word mid-sentence is not a field")
        XCTAssertEqual(CoachReplyPolish.stripLeakedFields("Two lines.\n\nSecond paragraph."), "Two lines.\n\nSecond paragraph.")
    }

    /// Structured claims need the person's words behind them.
    func test_goalCheckInNeedsCompletionLanguage() {
        XCTAssertFalse(CoachGoalCheckInRequest.claimsCompletion("I want to set a SMART goal to do Brilliant app every morning. Do I already have one?"))
        XCTAssertFalse(CoachGoalCheckInRequest.claimsCompletion("How is my walking goal going?"))
        XCTAssertTrue(CoachGoalCheckInRequest.claimsCompletion("I did my puzzles this morning."))
        XCTAssertTrue(CoachGoalCheckInRequest.claimsCompletion("Walked with Maureen after dinner, can you log it?"))
        XCTAssertTrue(CoachGoalCheckInRequest.claimsCompletion("Finished the notes before leaving today"))
    }

    func test_proposalThatChangesNothingIsNotAProposal() {
        let goal = CoachTestFixtures.goal(text: "Do Brilliant app logic puzzles for 10 minutes in the mornings.")
        let same = CoachGoalProposal.make(
            operation: "update", goalID: goal.id.uuidString, specificText: goal.specificText,
            targetCount: goal.targetCount, theme: goal.relevantTheme.rawValue, daysFromToday: nil, goals: [goal]
        )
        XCTAssertNotNil(same)
        XCTAssertEqual(same?.isNoOp, true)
        let changed = CoachGoalProposal.make(
            operation: "update", goalID: goal.id.uuidString, specificText: nil,
            targetCount: goal.targetCount + 2, theme: nil, daysFromToday: nil, goals: [goal]
        )
        XCTAssertEqual(changed?.isNoOp, false)
    }

    func test_errorsAreClassifiedByWhatTheFrameworkSays() {
        XCTAssertTrue(FoundationModelsCoach.isContextOverflow(FakeOverflowError()))
        XCTAssertFalse(FoundationModelsCoach.isContentDecline(FakeOverflowError()))
        XCTAssertTrue(FoundationModelsCoach.isContentDecline(FakeRefusedError()))
        XCTAssertFalse(FoundationModelsCoach.isContextOverflow(FakeNetworkError()))
        XCTAssertTrue(FoundationModelsCoach.describe(FakeOverflowError()).contains("FakeOverflowError"), "The type or case name survives")
        XCTAssertTrue(FoundationModelsCoach.describe(FakeOverflowError()).contains("4097 tokens"))
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
        XCTAssertEqual(CoachEvalPrompts.all.count, 13)
        XCTAssertEqual(Set(CoachEvalPrompts.all.map(\.id)).count, 13)
        XCTAssertEqual(CoachEvalPrompts.all.filter { $0.id.hasPrefix("general-") }.count, 3, "General knowledge is measured, not noticed")
        XCTAssertTrue(CoachEvalPrompts.all.allSatisfy { !$0.rubric.isEmpty })
        let result = CoachEvalResult(promptID: "stress-numbing", reply: "**Yes.**", tier: .privateCloud, shape: .howTo, memoryNotes: ["add · Likes & staples · stated: Yoga"], seconds: 12.3)
        let export = CoachEvalPrompts.export(results: [result])
        XCTAssertTrue(export.contains("## Stress numbing and Clash Royale"))
        XCTAssertTrue(export.contains("Model: privateCloud · shape: howTo · 12.3s · 1 words"))
        XCTAssertTrue(export.contains("- [ ] "))
        let fellBack = CoachEvalResult(promptID: "data-question", reply: "7.1", tier: .onDevice, shape: .data, memoryNotes: [], seconds: 9.9, fallbackReason: "GenerationError.rateLimited")
        XCTAssertTrue(CoachEvalPrompts.export(results: [fellBack]).contains("Fell back to on-device because: GenerationError.rateLimited"))
        let drafted = CoachEvalResult(promptID: "goal-conversation", reply: "Here is a draft.", tier: .privateCloud, shape: .howTo, memoryNotes: [], seconds: 10, draft: "create: Walk with Maureen after dinner × 3")
        XCTAssertTrue(CoachEvalPrompts.export(results: [drafted]).contains("Draft: create: Walk with Maureen after dinner × 3"))
        XCTAssertTrue(export.contains("- add · Likes & staples · stated: Yoga"))
    }
}

struct FakeOverflowError: LocalizedError {
    var errorDescription: String? { "Content contains 4097 tokens, which exceeds the maximum allowed context size of 4096." }
}

struct FakeRefusedError: LocalizedError {
    var errorDescription: String? { "The model refused to answer." }
}

struct FakeNetworkError: LocalizedError {
    var errorDescription: String? { "The Internet connection appears to be offline." }
}

/// The model asks; the app validates. These are the guards under the action tools.
@MainActor
final class CoachLiveContextTests: XCTestCase {
    func test_rememberKeepsOnlyValidGroundedNotes() async {
        let live = CoachLiveContext()
        live.personsWords = "Call me Matt. I am a Family Medicine physician. I work Monday, Tuesday, Wednesday, Friday."
        XCTAssertEqual(
            live.remember(operation: "add", section: "aboutYou", text: "Family Medicine physician; clinic days Monday, Tuesday, Wednesday, Friday as of September 2026.", replaces: "", basis: "stated"),
            "Kept."
        )
        XCTAssertTrue(live.remember(operation: "add", section: "patterns", text: "Finds tracking food helpful for staying steady.", replaces: "", basis: "inferred").hasPrefix("Not kept: notes must come from"))
        XCTAssertTrue(live.remember(operation: "zap", section: "aboutYou", text: "Family Medicine physician.", replaces: "", basis: "stated").hasPrefix("Not kept: the note needs"))
        XCTAssertEqual(live.pendingMemoryUpdates.count, 1)
        live.beginTurn()
        XCTAssertTrue(live.pendingMemoryUpdates.isEmpty)
    }

    func test_checkInNeedsCompletionLanguageAndARealGoal() async {
        let live = CoachLiveContext()
        let goal = CoachTestFixtures.goal(text: "walk after dinner")
        live.goals = [goal]
        live.personsWords = "Do I already have a walking goal?"
        XCTAssertTrue(live.logCheckIn(goalID: goal.id.uuidString, when: "today", note: "").hasPrefix("Not offered: the person has not said"))
        live.personsWords = "I walked after dinner tonight, can you log it?"
        XCTAssertTrue(live.logCheckIn(goalID: UUID().uuidString, when: "today", note: "").hasPrefix("Not offered: use an exact goalID"))
        XCTAssertEqual(live.logCheckIn(goalID: goal.id.uuidString, when: "today", note: "by the pond"), "Ready for them to confirm. It is not logged yet.")
        XCTAssertEqual(live.pendingCheckIn?.goalId, goal.id)
    }

    func test_proposalsAreValidatedAndNoOpsRefused() async {
        let live = CoachLiveContext()
        let goal = CoachTestFixtures.goal(text: "Do Brilliant app logic puzzles for 10 minutes in the mornings.")
        live.goals = [goal]
        let same = live.propose(operation: "update", goalID: goal.id.uuidString, specificText: goal.specificText, targetCount: goal.targetCount, theme: goal.relevantTheme.rawValue, daysFromToday: nil, personalReason: nil, cue: nil, expectedBarriers: nil, fallbackAction: nil)
        XCTAssertTrue(same.hasPrefix("Not drafted: that is the goal exactly"))
        XCTAssertNil(live.pendingProposal)
        let created = live.propose(operation: "create", goalID: nil, specificText: "Walk with Maureen after dinner", targetCount: 3, theme: "marriage", daysFromToday: 14, personalReason: "connection", cue: "after dinner", expectedBarriers: nil, fallbackAction: "five minutes outside")
        XCTAssertTrue(created.hasPrefix("One draft is on screen"))
        XCTAssertEqual(live.pendingProposal?.edit.specificText, "Walk with Maureen after dinner")
        XCTAssertFalse(live.proposalRejected)
        let replaced = live.propose(operation: "create", goalID: nil, specificText: "Finish each note before the next patient", targetCount: 5, theme: "career", daysFromToday: 7, personalReason: nil, cue: nil, expectedBarriers: nil, fallbackAction: "one note")
        XCTAssertTrue(replaced.hasPrefix("Replaced the earlier draft"))
        XCTAssertEqual(live.pendingProposal?.edit.specificText, "Finish each note before the next patient")
        XCTAssertFalse(replaced.contains("Walk with Maureen"))
        let broken = live.propose(operation: "create", goalID: nil, specificText: nil, targetCount: nil, theme: nil, daysFromToday: nil, personalReason: nil, cue: nil, expectedBarriers: nil, fallbackAction: nil)
        XCTAssertTrue(broken.hasPrefix("Not drafted: a new goal needs"))
        XCTAssertTrue(broken.contains("already on screen is unchanged"))
        XCTAssertFalse(live.proposalRejected)
        XCTAssertEqual(live.pendingProposal?.edit.specificText, "Finish each note before the next patient")
        live.beginTurn()
        let alone = live.propose(operation: "create", goalID: nil, specificText: nil, targetCount: nil, theme: nil, daysFromToday: nil, personalReason: nil, cue: nil, expectedBarriers: nil, fallbackAction: nil)
        XCTAssertTrue(alone.hasPrefix("Not drafted: a new goal needs"))
        XCTAssertFalse(alone.contains("unchanged"))
        XCTAssertTrue(live.proposalRejected)
        XCTAssertNil(live.pendingProposal)
    }

    func test_toolNamesIncludeTheActions() async {
        for name in ["rememberAboutPerson", "proposeSMARTGoal", "logGoalCheckIn", "lookupTodayHealth", "lookupWhatWeRemember"] {
            XCTAssertTrue(CoachSessionTools.toolNames.contains(name), name)
        }
    }

    func test_toolTraceKeepsOnlyMeaningfulArgumentsAndOutcome() async {
        let live = CoachLiveContext()
        live.log(
            "lookupFood",
            detail: "  Seven Sundays\n\"Wildberry\" Protein Oats  ",
            outcome: "match"
        )
        live.log("lookupTodayHealth", outcome: "success")
        XCTAssertEqual(
            live.toolLog,
            [
                "lookupFood(\"Seven Sundays 'Wildberry' Protein Oats\") → match",
                "lookupTodayHealth → success"
            ]
        )
    }

    func test_personLookupScopesNotesAndRecentChatsToItsTopic() async {
        let live = CoachLiveContext()
        live.memoryItems = [
            CoachMemoryItem(category: .routines, content: "Uses an AI scribe to finish patient notes at work.", provenance: .coachRecorded),
            CoachMemoryItem(category: .likes, content: "Likes Wildberry Protein Oats.", provenance: .coachRecorded)
        ]
        live.recentConversations = """
        - Today: "Patient confidence" — Felt more confident while seeing patients.
        - Yesterday: "Breakfast" — Compared two oat products.
        """
        let payload = live.personPayload(topic: "patients at work")
        XCTAssertTrue(payload.contains("AI scribe"))
        XCTAssertTrue(payload.contains("Patient confidence"))
        XCTAssertFalse(payload.contains("Wildberry"))
        XCTAssertFalse(payload.contains("\"Breakfast\""))
    }
}
