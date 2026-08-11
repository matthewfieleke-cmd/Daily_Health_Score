import Foundation

/// Curated Lifestyle Medicine reference content for DHS Lifestyle Coach.
///
/// The on-device model is good at phrasing and poor at recalling precise
/// guidance, so expertise lives here rather than in the model's memory.
/// Entries are written to be guideline-aligned and non-prescriptive: they
/// describe general adult wellness evidence, not individualized medical care.
enum CoachKnowledgeTopic: String, CaseIterable, Sendable {
    case nutrition
    case fiber
    case plantForward
    case protein
    case micronutrients
    case hydration
    case sodiumAndSugar
    case ultraProcessed
    case eatingPatterns
    case physicalActivity
    case aerobic
    case strength
    case movementSnacks
    case recovery
    case sleep
    case circadian
    case sleepDisruptors
    case insomnia
    case stress
    case breathing
    case mindfulness
    case dbtSkills
    case socialConnection
    case service
    case substances
    case behaviorChange
    case motivationalInterviewing
    case habits
    case lapses
    case hrv
    case weightNeutral
    case appScoring
}

struct CoachKnowledgeEntry: Equatable, Sendable {
    let id: String
    let topic: CoachKnowledgeTopic
    let title: String
    let keywords: [String]
    let facts: [String]

    var block: String {
        "\(title):\n" + facts.map { "• \($0)" }.joined(separator: "\n")
    }
}

enum LifestyleMedicineKnowledge {
    /// Retrieval budget kept small on purpose: the on-device session context is limited.
    static let defaultCharacterBudget = 1500

    static func retrieve(
        query: String,
        topics: [CoachKnowledgeTopic] = [],
        limit: Int = 4
    ) -> [CoachKnowledgeEntry] {
        let normalized = query.lowercased()
        let boosted = Set(topics)

        let scored = all.map { entry -> (entry: CoachKnowledgeEntry, score: Int) in
            var score = 0
            for keyword in entry.keywords where normalized.contains(keyword) {
                score += keyword.count >= 6 ? 3 : 2
            }
            if boosted.contains(entry.topic) {
                score += 2
            }
            return (entry, score)
        }

        return scored.filter { $0.score > 0 }
            .sorted { lhs, rhs in
                lhs.score == rhs.score ? lhs.entry.id < rhs.entry.id : lhs.score > rhs.score
            }
            .prefix(limit)
            .map { $0.entry }
    }

    static func promptBlock(
        query: String,
        topics: [CoachKnowledgeTopic] = [],
        limit: Int = 4,
        characterBudget: Int = defaultCharacterBudget
    ) -> String {
        let entries = retrieve(query: query, topics: topics, limit: limit)
        guard !entries.isEmpty else { return "" }

        var output = ""
        for entry in entries {
            let candidate = output.isEmpty ? entry.block : output + "\n\n" + entry.block
            if candidate.count > characterBudget { break }
            output = candidate
        }
        return output
    }

    static func topics(for focus: PrimaryFocus) -> [CoachKnowledgeTopic] {
        switch focus {
        case .sleep: return [.sleep, .circadian, .sleepDisruptors]
        case .fiber: return [.fiber, .plantForward, .nutrition]
        case .exercise: return [.physicalActivity, .aerobic, .movementSnacks]
        case .maintain: return [.behaviorChange, .stress, .socialConnection]
        }
    }

    // MARK: - Nutrition

    static let nutritionEntries: [CoachKnowledgeEntry] = [
        CoachKnowledgeEntry(
            id: "fiber-targets",
            topic: .fiber,
            title: "Fiber targets and typical intake",
            keywords: ["fiber", "fibre", "roughage", "how much fiber"],
            facts: [
                "Adequate Intake for fiber is about 14 g per 1,000 calories — roughly 25 g/day for adult women and 38 g/day for adult men; the FDA Daily Value used on labels is 28 g.",
                "Most US adults consume only about 15 g/day, so nearly everyone has room to grow.",
                "Higher fiber intake is associated with lower risk of cardiovascular disease, type 2 diabetes, colorectal cancer, and all-cause mortality in large cohort and meta-analytic data.",
                "Benefits look dose-responsive up to roughly 25–35 g/day; more is not automatically better, and very high intakes can cause GI discomfort."
            ]
        ),
        CoachKnowledgeEntry(
            id: "fiber-types",
            topic: .fiber,
            title: "Types of fiber and what each does",
            keywords: ["soluble", "insoluble", "psyllium", "beta-glucan", "prebiotic", "microbiome", "gut"],
            facts: [
                "Soluble, viscous fibers (oat beta-glucan, psyllium, barley, legumes) bind bile acids and lower LDL cholesterol; about 3 g/day of oat beta-glucan carries an FDA heart-health claim.",
                "Insoluble fiber (wheat bran, vegetable skins, whole grains) adds stool bulk and speeds transit, helping constipation.",
                "Fermentable fibers feed colonic bacteria that produce short-chain fatty acids such as butyrate, the preferred fuel of colon cells.",
                "Plant diversity appears to matter alongside total grams; rotating many plant species supports a more diverse gut microbiome (observational evidence).",
                "Increase fiber gradually over 1–2 weeks and raise fluid intake to limit gas and bloating."
            ]
        ),
        CoachKnowledgeEntry(
            id: "fiber-foods",
            topic: .fiber,
            title: "High-fiber foods with approximate grams",
            keywords: ["beans", "lentils", "legume", "chia", "oats", "berries", "avocado", "fiber food", "high fiber"],
            facts: [
                "Cooked lentils ~15.5 g per cup; black beans ~15 g per cup; chickpeas ~12.5 g per cup — legumes are the highest-yield fiber food.",
                "Chia seeds ~10 g per ounce; ground flaxseed ~8 g per 2 tablespoons.",
                "Raspberries ~8 g per cup; blackberries ~7.6 g per cup; a medium pear with skin ~5.5 g; a medium apple with skin ~4.4 g.",
                "One medium avocado ~10 g; cooked broccoli ~5 g per cup; green peas ~9 g per cup.",
                "Rolled oats ~4 g per half cup dry; whole-wheat pasta ~6 g per cooked cup; almonds ~3.5 g per ounce.",
                "A practical lever: one cup of legumes on most days moves daily fiber more than any single other change."
            ]
        ),
        CoachKnowledgeEntry(
            id: "plant-forward",
            topic: .plantForward,
            title: "Whole-food plant-forward eating",
            keywords: ["plant based", "wfpb", "vegan", "vegetarian", "plant-based", "whole food"],
            facts: [
                "Dietary patterns emphasizing vegetables, fruit, legumes, intact whole grains, nuts, and seeds are consistently associated with lower cardiometabolic risk.",
                "Roughly five servings of produce daily (about 2 fruit + 3 vegetables) is associated with the lowest mortality in pooled cohort data; more than that adds little additional benefit.",
                "Three servings of whole grains per day and about one ounce of nuts per day are each associated with lower cardiovascular risk.",
                "Plant-forward does not require perfection or an all-or-nothing switch; adding plants is usually more sustainable than eliminating foods.",
                "Legumes are the common thread across long-lived populations and are inexpensive, shelf-stable, and fiber-dense."
            ]
        ),
        CoachKnowledgeEntry(
            id: "vegetable-variety",
            topic: .nutrition,
            title: "There is no single healthiest vegetable or fruit",
            keywords: ["healthiest vegetable", "healthiest fruit", "best vegetable", "best fruit", "superfood"],
            facts: [
                "No single vegetable or fruit is 'the healthiest'; variety across colors and families delivers a broader mix of fiber, potassium, folate, carotenoids, and polyphenols.",
                "Leafy greens (spinach, kale, arugula) and cruciferous vegetables (broccoli, Brussels sprouts, cabbage) are unusually nutrient-dense per calorie.",
                "Berries stand out among fruit for polyphenols and fiber per calorie; citrus for vitamin C and flavonoids.",
                "The strongest predictor of benefit is total produce intake and consistency, not choosing an optimal item.",
                "The best vegetable for any given person is often the one they will actually eat regularly and can afford."
            ]
        ),
        CoachKnowledgeEntry(
            id: "protein-basics",
            topic: .protein,
            title: "Protein needs and plant sources",
            keywords: ["protein", "amino acid", "tofu", "tempeh", "soy", "muscle protein"],
            facts: [
                "The RDA is 0.8 g/kg/day; adults doing resistance training and many older adults do better around 1.2–1.6 g/kg/day to support lean mass.",
                "Spreading protein across meals (roughly 25–40 g per meal) supports muscle protein synthesis better than one large evening dose.",
                "Soy foods (tofu, tempeh, edamame) provide all essential amino acids; other plant proteins complement each other across the day without needing to be combined at one meal.",
                "Legumes deliver protein and fiber simultaneously, which is why they anchor most plant-forward patterns.",
                "Higher protein intake supports satiety, which can make other dietary changes easier to sustain."
            ]
        ),
        CoachKnowledgeEntry(
            id: "plant-micronutrients",
            topic: .micronutrients,
            title: "Nutrients to watch on plant-forward diets",
            keywords: ["b12", "vitamin", "iron", "omega", "dha", "supplement", "calcium", "zinc"],
            facts: [
                "Vitamin B12 is not reliably available from unfortified plant foods; people eating strictly plant-based should use a supplement or fortified foods.",
                "Plant (non-heme) iron absorbs better alongside vitamin C–rich foods; tea and coffee at the same meal reduce absorption.",
                "ALA from flax, chia, and walnuts converts inefficiently to EPA/DHA; algal oil is a plant-based option some choose.",
                "Calcium, iodine, zinc, and vitamin D deserve attention in restrictive patterns.",
                "Supplement decisions with medical relevance belong with the person's own clinician or a registered dietitian."
            ]
        ),
        CoachKnowledgeEntry(
            id: "sodium-sugar",
            topic: .sodiumAndSugar,
            title: "Sodium, added sugar, and beverages",
            keywords: ["sodium", "salt", "sugar", "soda", "sweet", "blood pressure"],
            facts: [
                "Dietary guidance caps sodium below 2,300 mg/day; the American Heart Association's ideal target is 1,500 mg/day for most adults.",
                "Most sodium comes from packaged and restaurant food rather than the salt shaker.",
                "Added sugar is recommended below 10% of calories; AHA suggests about 25 g/day for women and 36 g/day for men.",
                "Sugar-sweetened beverages are the single largest source of added sugar for many adults and are weakly satiating.",
                "Reducing sodium and added sugar tends to work better as substitution (swap the item) than as prohibition."
            ]
        ),
        CoachKnowledgeEntry(
            id: "ultra-processed",
            topic: .ultraProcessed,
            title: "Ultra-processed foods",
            keywords: ["processed", "ultra-processed", "junk food", "snack food", "packaged"],
            facts: [
                "In a controlled feeding trial, an ultra-processed diet led people to eat about 500 more calories per day and gain weight versus a matched minimally processed diet.",
                "Ultra-processed intake is associated with higher cardiometabolic risk in cohort studies, though residual confounding is likely.",
                "'Minimally processed' does not mean unprocessed: canned beans, frozen vegetables, and plain whole-grain products are convenient and healthful.",
                "Cost, time, and food access are legitimate constraints; shaming processed food is counterproductive and often classist."
            ]
        ),
        CoachKnowledgeEntry(
            id: "eating-patterns",
            topic: .eatingPatterns,
            title: "Meal timing and eating patterns",
            keywords: ["fasting", "intermittent", "time restricted", "meal timing", "breakfast", "late eating"],
            facts: [
                "Time-restricted eating trials generally show benefits that track with reduced calorie intake rather than timing itself.",
                "Very late large meals are associated with worse glucose handling and can disrupt sleep in some people.",
                "Regular meal rhythm supports appetite regulation better than long gaps followed by large intakes.",
                "Fasting approaches are not appropriate for people with a history of disordered eating, pregnancy, or certain medications."
            ]
        ),
        CoachKnowledgeEntry(
            id: "meal-building",
            topic: .nutrition,
            title: "Building a meal, with concrete examples",
            keywords: ["breakfast", "lunch", "dinner", "meal", "snack", "what should i eat", "what to eat", "recipe"],
            facts: [
                "A meal that holds people over usually pairs protein, fiber, and some fat; that combination slows gastric emptying and blunts the post-meal glucose rise.",
                "High-fiber breakfasts, with rough fiber counts: oats with raspberries, chia, and walnuts (~12–15 g); whole-grain toast with avocado and eggs (~10 g); Greek or soy yogurt with berries and ground flax (~8–10 g); a black bean and vegetable scramble (~10 g).",
                "Breakfast is the most repeatable meal of the day for most people, which makes it the easiest place to close a fiber gap permanently.",
                "Refined low-fiber breakfasts (pastries, most boxed cereals, juice) tend to leave people hungry within about two hours.",
                "Roughly 25–40 g of protein at the first meal supports satiety and muscle protein synthesis; eggs, Greek yogurt, cottage cheese, tofu scramble, or leftover beans all get there.",
                "Batch-cooked components (a pot of grains, a pot of beans, roasted vegetables) turn meal decisions into assembly, which is what makes patterns stick."
            ]
        ),
        CoachKnowledgeEntry(
            id: "hydration",
            topic: .hydration,
            title: "Hydration",
            keywords: ["water", "hydration", "drink", "thirsty", "dehydrated"],
            facts: [
                "There is no universal eight-glasses rule; needs vary with body size, activity, heat, and diet (food contributes ~20% of intake).",
                "Thirst plus pale-yellow urine is an adequate everyday heuristic for most healthy adults.",
                "Fluid matters more when fiber intake rises, during heat, and around exercise.",
                "People with heart, kidney, or liver conditions may have individualized fluid limits set by their clinician."
            ]
        )
    ]

    // MARK: - Physical activity

    static let activityEntries: [CoachKnowledgeEntry] = [
        CoachKnowledgeEntry(
            id: "activity-guidelines",
            topic: .physicalActivity,
            title: "Adult activity guidelines",
            keywords: ["exercise", "workout", "activity", "how much exercise", "guidelines", "minutes"],
            facts: [
                "Adults are advised to get 150–300 minutes of moderate-intensity aerobic activity weekly, or 75–150 minutes vigorous, or an equivalent mix.",
                "Muscle-strengthening activity for all major muscle groups is recommended on 2 or more days per week.",
                "Older adults are additionally advised to include balance training and to stay as active as ability allows.",
                "The largest health return happens when someone moves from near-zero to some activity; 'some is better than none' is literal guideline language.",
                "Daily 30-minute targets are a habit scaffold; the underlying evidence base is weekly, so a light day is not a failure."
            ]
        ),
        CoachKnowledgeEntry(
            id: "aerobic-fitness",
            topic: .aerobic,
            title: "Aerobic training and cardiorespiratory fitness",
            keywords: ["cardio", "aerobic", "running", "walking", "zone 2", "vo2", "endurance", "steps"],
            facts: [
                "Cardiorespiratory fitness is one of the strongest measured predictors of long-term mortality risk, with no observed upper limit of benefit in large cohorts.",
                "Most weekly aerobic volume is best done at conversational (easy) intensity, with a smaller share at higher intensity.",
                "Step-count mortality benefits accrue from roughly 2,700–4,000 steps/day and largely plateau near 6,000–8,000 for adults over 60 and 8,000–10,000 for younger adults.",
                "Brisk walking counts as moderate intensity for most adults — the talk test (can speak, cannot sing) is a practical gauge.",
                "Fitness gains require progressive overload: increase duration or intensity, not both aggressively at once."
            ]
        ),
        CoachKnowledgeEntry(
            id: "walking-vs-running",
            topic: .aerobic,
            title: "Walking versus running",
            keywords: ["walking or running", "running or walking", "run or walk", "walk or run", "running", "jogging", "treadmill", "elliptical", "cycling"],
            facts: [
                "Neither is universally better: both lower cardiovascular and all-cause mortality risk, and which one someone actually keeps doing usually decides the outcome.",
                "Running delivers more cardiorespiratory benefit per minute — guidelines count one minute of vigorous activity as roughly two minutes of moderate — so it is more time-efficient for a fixed weekly dose.",
                "Walking is far lower impact; annual running injury rates in the literature commonly land somewhere between 20% and 70% of runners, mostly overuse from too much too soon.",
                "Walking is easier to accumulate in short bouts, after meals, and while doing something else, which makes it more resilient to a busy week.",
                "Walk-run intervals are the standard bridge: keep most volume easy and add running gradually rather than converting all at once.",
                "For someone rebuilding a habit, the honest answer is whichever one happens on the most days."
            ]
        ),
        CoachKnowledgeEntry(
            id: "cardio-vs-strength",
            topic: .physicalActivity,
            title: "Cardio versus strength training",
            keywords: ["cardio or", "weights or", "strength or", "lifting or", "cardio vs", "strength vs"],
            facts: [
                "They are complements, not competitors; guidelines ask for both because they produce different adaptations.",
                "Aerobic work drives cardiorespiratory fitness, which is among the strongest predictors of mortality risk; resistance work preserves muscle, bone, glucose disposal, and independence with age.",
                "Doing both is associated with lower mortality than either alone in large cohort studies.",
                "When time is scarce, roughly two short strength sessions plus accumulated daily walking covers most of the benefit of each.",
                "Order matters only modestly; if one goal is priority, do it first while fresh."
            ]
        ),
        CoachKnowledgeEntry(
            id: "strength-training",
            topic: .strength,
            title: "Resistance training",
            keywords: ["strength", "lifting", "weights", "resistance", "muscle", "sarcopenia", "bone"],
            facts: [
                "Resistance training 2–3 times weekly preserves lean mass and bone density and is associated with lower mortality independent of aerobic activity.",
                "Roughly 30–60 minutes per week of resistance work is associated with much of the observed mortality benefit; more is not proportionally better.",
                "Hypertrophy responds to sets taken near (but not necessarily to) failure, commonly 6–12 reps; strength favors heavier loads and lower reps.",
                "Bodyweight, bands, and household objects produce real adaptation when load progresses over time.",
                "For older adults, strength plus balance work is the most direct lever against falls and functional decline."
            ]
        ),
        CoachKnowledgeEntry(
            id: "movement-snacks",
            topic: .movementSnacks,
            title: "Short movement and sedentary time",
            keywords: ["sitting", "sedentary", "desk", "short walk", "after meal", "glucose", "break"],
            facts: [
                "Two to five minutes of easy walking after a meal meaningfully blunts post-meal glucose rises compared with sitting.",
                "Breaking up prolonged sitting every 30–60 minutes improves glucose and blood-pressure measures even without formal exercise.",
                "Short bouts count toward weekly totals; the old 10-minute minimum was removed from US guidelines in 2018.",
                "Movement snacks are often the highest-adherence option for people with fatigue, pain, caregiving loads, or shift schedules."
            ]
        ),
        CoachKnowledgeEntry(
            id: "recovery",
            topic: .recovery,
            title: "Recovery, soreness, and load management",
            keywords: ["sore", "soreness", "rest day", "recovery", "overtraining", "injury", "doms"],
            facts: [
                "Delayed-onset muscle soreness typically peaks 24–72 hours after unfamiliar work and is not a measure of workout quality.",
                "Sleep and adequate protein are the two most reliable recovery inputs.",
                "Ramping weekly volume gradually (a common heuristic is about 10% per week) reduces overuse injury risk.",
                "Persistent unexplained fatigue, resting heart-rate elevation, or performance decline suggests reducing load rather than pushing.",
                "Rest days are part of training, not a lapse in discipline."
            ]
        )
    ]

    // MARK: - Sleep

    static let sleepEntries: [CoachKnowledgeEntry] = [
        CoachKnowledgeEntry(
            id: "sleep-duration",
            topic: .sleep,
            title: "Sleep duration and regularity",
            keywords: ["sleep", "how much sleep", "hours of sleep", "tired", "rest", "bedtime"],
            facts: [
                "Professional sleep societies advise 7 or more hours per night for adults; commonly cited ranges are 7–9 hours.",
                "Both short and very long habitual sleep are associated with worse outcomes, though long sleep often reflects illness rather than causing it.",
                "Sleep regularity — consistent sleep and wake times — predicts mortality at least as strongly as duration in recent cohort analyses.",
                "Individual need varies; feeling rested without an alarm and stable daytime alertness are practical signals.",
                "Catch-up sleep on weekends only partially offsets weekday restriction."
            ]
        ),
        CoachKnowledgeEntry(
            id: "circadian",
            topic: .circadian,
            title: "Light and circadian anchoring",
            keywords: ["light", "morning light", "circadian", "melatonin", "screen", "shift work", "jet lag"],
            facts: [
                "Morning outdoor light is the strongest cue for anchoring circadian timing; even overcast daylight far exceeds indoor lighting intensity.",
                "Bright evening light, especially short-wavelength, delays melatonin onset and pushes sleep later.",
                "A consistent wake time stabilizes the rhythm faster than a consistent bedtime.",
                "Shift workers benefit from strategic light exposure, protected sleep windows, and darkness during daytime sleep; standard advice needs adaptation for them.",
                "Cool, dark, quiet rooms support sleep maintenance."
            ]
        ),
        CoachKnowledgeEntry(
            id: "sleep-disruptors",
            topic: .sleepDisruptors,
            title: "Caffeine, alcohol, and other sleep disruptors",
            keywords: ["caffeine", "coffee", "alcohol", "wine", "nap", "nicotine", "late"],
            facts: [
                "Caffeine's half-life averages about 5 hours (range roughly 3–7); 400 mg/day is generally considered safe for most healthy adults but timing matters more than total for sleep.",
                "Caffeine taken even 6 hours before bed has been shown to measurably reduce total sleep time.",
                "Alcohol shortens sleep latency but suppresses REM and fragments the second half of the night; it commonly lowers overnight HRV.",
                "Naps under about 20–30 minutes, taken early afternoon, restore alertness with less impact on night sleep.",
                "Large late meals, intense late exercise, and nicotine can each delay sleep onset in sensitive people."
            ]
        ),
        CoachKnowledgeEntry(
            id: "insomnia",
            topic: .insomnia,
            title: "Trouble sleeping",
            keywords: ["insomnia", "can't sleep", "cant sleep", "awake", "wake up", "racing thoughts"],
            facts: [
                "Cognitive behavioral therapy for insomnia (CBT-I) is the recommended first-line treatment for chronic insomnia, ahead of medication.",
                "Core CBT-I components include stimulus control (bed only for sleep), consistent wake time, and limiting time in bed to actual sleep.",
                "Lying awake for more than about 20 minutes is usually better handled by getting up and doing something calm in dim light than by staying in bed.",
                "A wind-down buffer of 30–60 minutes helps the nervous system transition; writing down tomorrow's worries can reduce rumination.",
                "Loud snoring, witnessed pauses in breathing, or severe daytime sleepiness warrant a clinical evaluation for sleep apnea."
            ]
        )
    ]

    // MARK: - Stress, mind, and skills

    static let mindEntries: [CoachKnowledgeEntry] = [
        CoachKnowledgeEntry(
            id: "stress-physiology",
            topic: .stress,
            title: "Stress and allostatic load",
            keywords: ["stress", "stressed", "burnout", "overwhelmed", "anxious", "anxiety", "cortisol"],
            facts: [
                "Acute stress is adaptive; chronic unrelieved stress contributes to allostatic load and worsens sleep, eating patterns, and activity.",
                "Perceived control and social support buffer the physiological impact of a given stressor.",
                "Stress often shows up first in behavior (skipped movement, evening eating, later bedtime) rather than in mood.",
                "Recovery periods matter more than eliminating stressors, which is usually impossible.",
                "Spending about two hours a week in natural settings is associated with better self-reported wellbeing."
            ]
        ),
        CoachKnowledgeEntry(
            id: "breathing",
            topic: .breathing,
            title: "Breathing and rapid down-regulation",
            keywords: ["breathing", "breathe", "panic", "calm down", "relax", "vagal"],
            facts: [
                "Slow breathing near six breaths per minute with a longer exhale than inhale increases heart-rate variability and parasympathetic tone acutely.",
                "A practical version: inhale about four seconds, exhale about six to eight, for two to five minutes.",
                "Physiological sighs (a second short inhale, then a long exhale) rapidly reduce acute arousal.",
                "Breathing practice is most effective when rehearsed when calm, not first attempted mid-crisis."
            ]
        ),
        CoachKnowledgeEntry(
            id: "mindfulness",
            topic: .mindfulness,
            title: "Mindfulness evidence",
            keywords: ["mindfulness", "meditation", "meditate", "present moment"],
            facts: [
                "Meta-analytic evidence supports moderate benefits of mindfulness meditation programs for anxiety, depression, and pain.",
                "Effects are comparable to other active behavioral treatments rather than dramatically superior.",
                "Short daily practice with consistency outperforms occasional long sessions for habit formation.",
                "Mindfulness is a skill of noticing without judgment, not a requirement to empty the mind."
            ]
        ),
        CoachKnowledgeEntry(
            id: "dbt-skills",
            topic: .dbtSkills,
            title: "DBT skills adapted for lifestyle coaching",
            keywords: ["urge", "craving", "emotion", "impulse", "acceptance", "distress", "cope", "dbt"],
            facts: [
                "Dialectics: acceptance and change are held together — 'I accept myself as I am, and I am working toward something.'",
                "Distress tolerance TIPP: temperature change (cool water on the face), intense exercise, paced breathing, paired muscle relaxation.",
                "STOP skill: Stop, Take a step back, Observe, Proceed mindfully — useful for evening eating urges or skipped-workout spirals.",
                "Opposite action: when an emotion's urge is unhelpful (withdrawal from low mood), act opposite in a small way (a five-minute walk, one text to a friend).",
                "PLEASE skill links emotion regulation to physical basics: treat illness, balanced eating, avoid mood-altering substances, sleep, exercise — nearly identical to the Lifestyle Medicine pillars.",
                "Urge surfing: urges rise and fall like waves and typically peak within 20–30 minutes rather than escalating forever.",
                "Radical acceptance targets the suffering added by fighting reality, not the pursuit of change itself."
            ]
        ),
        CoachKnowledgeEntry(
            id: "motivational-interviewing",
            topic: .motivationalInterviewing,
            title: "Motivational Interviewing craft",
            keywords: ["ambivalent", "not sure", "don't want", "dont want", "should i", "stuck", "unmotivated"],
            facts: [
                "MI spirit is partnership, acceptance, compassion, and evocation — drawing out the person's own reasons rather than supplying them.",
                "OARS: open questions, affirmations, reflections, summaries.",
                "Change talk (desire, ability, reasons, need, commitment) predicts behavior change; sustain talk is normal ambivalence, not resistance.",
                "The righting reflex — rushing to fix — reliably increases defensiveness; asking permission before advising reduces it.",
                "Readiness rulers: 'How important is this, 0 to 10? How confident are you?' If confidence is below about 7, shrink the plan.",
                "Elicit–provide–elicit: ask what they already know, offer information briefly, then ask what they make of it."
            ]
        )
    ]

    // MARK: - Connection, substances, behavior

    static let socialAndBehaviorEntries: [CoachKnowledgeEntry] = [
        CoachKnowledgeEntry(
            id: "social-connection",
            topic: .socialConnection,
            title: "Social connection",
            keywords: ["lonely", "loneliness", "friends", "family", "relationship", "connection", "isolated"],
            facts: [
                "Meta-analytic evidence links strong social relationships with substantially lower mortality risk; loneliness and isolation carry risk comparable to other major behavioral factors.",
                "The US Surgeon General issued a 2023 advisory framing loneliness and isolation as a public health priority.",
                "Frequency and reliability of small contacts often matter more than intensity of a few large ones.",
                "Shared activity (walking with someone, cooking together) pairs connection with another pillar and raises adherence to both."
            ]
        ),
        CoachKnowledgeEntry(
            id: "service",
            topic: .service,
            title: "Purpose and serving others",
            keywords: ["purpose", "meaning", "volunteer", "serve", "serving", "others", "give back"],
            facts: [
                "Sense of purpose is associated with lower mortality and better health behaviors in longitudinal cohorts.",
                "Volunteering and prosocial behavior are associated with improved wellbeing, with plausible bidirectional effects.",
                "Framing health behaviors in terms of capacity — energy and presence for people who matter — often sustains motivation better than appearance or numeric targets.",
                "Purpose framing should be offered, not imposed; not every conversation needs a meaning narrative."
            ]
        ),
        CoachKnowledgeEntry(
            id: "substances",
            topic: .substances,
            title: "Alcohol, tobacco, and other substances",
            keywords: ["alcohol", "drink", "smoking", "tobacco", "vape", "nicotine", "cannabis", "weed"],
            facts: [
                "US dietary guidance advises no more than two drinks/day for men and one for women, and recent reviews emphasize that less is better; no intake level is established as protective.",
                "Alcohol degrades sleep architecture and next-day HRV even at modest doses.",
                "Stopping tobacco produces the single largest individual health gain of any behavior change, with benefits beginning within days.",
                "Cannabis can shorten sleep latency but reduces REM and can impair next-day cognition; regular heavy use is associated with tolerance and rebound insomnia.",
                "Substance dependence, withdrawal risk, and cessation medications belong with a clinician, not a wellness coach."
            ]
        ),
        CoachKnowledgeEntry(
            id: "behavior-change",
            topic: .behaviorChange,
            title: "What actually drives behavior change",
            keywords: ["habit", "start", "consistency", "discipline", "willpower", "motivation", "plan"],
            facts: [
                "Implementation intentions — 'After X, I will do Y' — produce medium-to-large improvements in follow-through compared with goal intentions alone.",
                "Self-monitoring is among the most effective single behavior-change techniques identified in the literature.",
                "Environment design beats willpower: reduce friction for the desired behavior and add friction to the default.",
                "Autonomy, competence, and relatedness (self-determination theory) predict durable motivation; externally imposed goals fade.",
                "Starting smaller than feels necessary raises the odds of a streak, and streaks build identity ('I'm someone who walks after dinner').",
                "Habit formation timelines vary widely — often around two to three months for automaticity, not 21 days."
            ]
        ),
        CoachKnowledgeEntry(
            id: "habit-anchoring",
            topic: .habits,
            title: "Anchoring and stacking habits",
            keywords: ["routine", "stack", "anchor", "reminder", "trigger", "cue"],
            facts: [
                "Anchor a new behavior to an existing reliable cue (after brushing teeth, after the first coffee, after closing the laptop).",
                "Make the cue specific in time and place; vague intentions like 'exercise more' rarely survive a busy week.",
                "Pair the behavior with something intrinsically pleasant to shorten the reward delay.",
                "Track completion, not perfection — two of three planned days is a success signal, not a failure."
            ]
        ),
        CoachKnowledgeEntry(
            id: "lapses",
            topic: .lapses,
            title: "Lapses and self-compassion",
            keywords: ["failed", "failure", "gave up", "off track", "slipped", "guilty", "shame", "discouraged"],
            facts: [
                "A lapse is data about the plan or the environment, not evidence about the person's character.",
                "The abstinence violation effect — treating one slip as total failure — predicts full relapse; naming it defuses it.",
                "Self-compassion is associated with faster resumption of health behaviors than self-criticism.",
                "Recovery speed matters more than streak length; the useful question is 'what is the smallest restart?'",
                "Shame reliably reduces follow-through, which is why it has no place in coaching."
            ]
        )
    ]

    // MARK: - App-specific context

    static let appEntries: [CoachKnowledgeEntry] = [
        CoachKnowledgeEntry(
            id: "hrv-context",
            topic: .hrv,
            title: "Heart rate variability in this app",
            keywords: ["hrv", "variability", "sdnn", "recovery score", "readiness"],
            facts: [
                "HRV reflects autonomic balance and is highly individual; trends against a personal baseline are meaningful, absolute comparisons between people are not.",
                "Night-to-night variation of roughly 10–20% is normal; single-night dips commonly follow alcohol, illness, late meals, hard training, or short sleep.",
                "This app derives sleep-window SDNN and compares recent averages to a personal corridor; it is not a diagnosis, readiness verdict, or training prescription.",
                "HRV contributes zero points to the Daily Health Score by design."
            ]
        ),
        CoachKnowledgeEntry(
            id: "score-meaning",
            topic: .appScoring,
            title: "What the Daily Health Score is",
            keywords: ["score", "points", "10", "rating", "grade", "goal"],
            facts: [
                "The score is a behavioral habit proxy: sleep up to 4 points, fiber up to 4, exercise up to 2, capped at goal.",
                "It measures three logged behaviors, not overall health, fitness, or medical risk.",
                "Sleep goal options are 7, 7.5, or 8 hours; fiber goal options are 30, 40, or 50 grams; the exercise goal is fixed at 30 minutes.",
                "Missing Apple Health data lowers the score without meaning the behavior did not happen — fiber especially depends on food logging.",
                "Chasing points is not a health goal; the score exists to make helpful behaviors visible."
            ]
        ),
        CoachKnowledgeEntry(
            id: "weight-neutral",
            topic: .weightNeutral,
            title: "Weight-neutral framing",
            keywords: ["weight", "lose weight", "diet", "fat", "bmi", "scale"],
            facts: [
                "Improvements in fitness and diet quality are associated with better outcomes even without weight change.",
                "Weight-focused framing predicts more shame and dropout than behavior-focused framing for many people.",
                "Behaviors this app tracks — sleep, fiber, activity — improve health independent of what the scale does.",
                "Rapid-weight-loss advice, calorie prescriptions, and eating-disorder-adjacent guidance are out of scope for a wellness coach."
            ]
        )
    ]

    static let all: [CoachKnowledgeEntry] =
        nutritionEntries + activityEntries + sleepEntries + mindEntries + socialAndBehaviorEntries + appEntries
}
