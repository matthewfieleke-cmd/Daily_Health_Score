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
    case supplements
    case nutritionMyths
    case exerciseMyths
    case cardiometabolic
    case lifeStages
    case practicalEating
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
        // A single entry can exceed a tight budget. Returning a truncated best
        // match beats returning nothing and letting the model improvise.
        if output.isEmpty, let first = entries.first {
            output = first.block.limitedToCoachBudget(characterBudget)
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

    // MARK: - Supplements

    static let supplementEntries: [CoachKnowledgeEntry] = [
        CoachKnowledgeEntry(
            id: "supplement-basics",
            topic: .supplements,
            title: "How to think about supplements",
            keywords: ["supplement", "multivitamin", "vitamins", "pills", "should i take"],
            facts: [
                "Supplements are regulated as food, not drugs, in the US: manufacturers do not have to prove efficacy or purity before sale, and label accuracy varies.",
                "Large trials of multivitamins in well-nourished adults show no reduction in cardiovascular events, cancer, or mortality; they are insurance against deficiency, not a health upgrade.",
                "The strongest cases are for correcting a documented gap — vitamin B12 on a vegan diet, vitamin D with little sun exposure, iron with diagnosed deficiency, folate in pregnancy.",
                "Third-party certification (NSF Certified for Sport, USP, Informed Choice) is the practical way to check what is actually in a bottle.",
                "Supplements interact with medications; anything ongoing is worth running past a clinician or pharmacist."
            ]
        ),
        CoachKnowledgeEntry(
            id: "creatine",
            topic: .supplements,
            title: "Creatine monohydrate",
            keywords: ["creatine", "monohydrate"],
            facts: [
                "Creatine monohydrate is among the best-studied ergogenic aids: roughly 3–5 g/day increases muscle phosphocreatine and modestly improves strength and lean mass gains alongside resistance training.",
                "Loading protocols are optional; 3–5 g/day reaches saturation in about three to four weeks.",
                "It does not damage kidneys in healthy adults across decades of trials, though anyone with kidney disease should ask their clinician first.",
                "Early weight gain of one to two kilograms is intracellular water, not fat.",
                "Evidence for cognitive or mood benefits is preliminary and mostly in sleep-deprived or vegetarian populations."
            ]
        ),
        CoachKnowledgeEntry(
            id: "protein-powder",
            topic: .supplements,
            title: "Protein powder and shakes",
            keywords: ["protein powder", "whey", "shake", "casein", "protein supplement"],
            facts: [
                "Protein powder is a convenience food, not a superior protein source; total daily protein matters far more than form or timing.",
                "Whey is high in leucine and absorbs quickly; soy, pea, and blended plant powders work well when total intake and variety are adequate.",
                "Most people meeting 1.2–1.6 g/kg/day from food gain nothing from adding powder.",
                "Some powders carry heavy-metal or contaminant concerns; third-party certification addresses this.",
                "A shake is a poor substitute for a meal in fiber, micronutrients, and satiety."
            ]
        ),
        CoachKnowledgeEntry(
            id: "vitamin-d",
            topic: .supplements,
            title: "Vitamin D",
            keywords: ["vitamin d", "d3", "sunshine vitamin", "sun exposure"],
            facts: [
                "The RDA is 600 IU/day for adults under 70 and 800 IU/day after 70; the tolerable upper intake level is 4,000 IU/day.",
                "Deficiency is genuinely common in people with limited sun exposure, darker skin, higher body weight, or northern latitudes in winter.",
                "Large randomized trials (VITAL, D-Health) found no reduction in cardiovascular disease, cancer incidence, or all-cause mortality from supplementing people who were not deficient.",
                "The clear benefit is skeletal: correcting deficiency supports bone health, and vitamin D plus calcium modestly reduces fracture risk in older adults.",
                "Blood levels vary enough between people that testing beats guessing before high-dose supplementation."
            ]
        ),
        CoachKnowledgeEntry(
            id: "sleep-supplements",
            topic: .supplements,
            title: "Melatonin, magnesium, and sleep supplements",
            keywords: ["melatonin", "magnesium", "sleep supplement", "sleep aid", "sleeping pill"],
            facts: [
                "Melatonin is a circadian timing signal more than a sedative: low doses of 0.5–1 mg taken a few hours before target bedtime shift the clock more effectively than the 5–10 mg doses sold everywhere.",
                "Its strongest evidence is for jet lag and delayed sleep phase; effects on chronic insomnia are small, averaging under ten minutes of extra sleep in meta-analyses.",
                "US melatonin products are frequently mislabeled, with measured content ranging far from the stated dose.",
                "Magnesium supplementation improves sleep only modestly and mostly in people with low intake or older adults; food sources include legumes, nuts, seeds, and leafy greens.",
                "Cognitive behavioral therapy for insomnia outperforms every sleep supplement and is the guideline-recommended first-line treatment."
            ]
        ),
        CoachKnowledgeEntry(
            id: "omega-3",
            topic: .supplements,
            title: "Omega-3 fats and fish oil",
            keywords: ["omega", "fish oil", "epa", "dha", "flax", "chia omega"],
            facts: [
                "Two servings of fatty fish per week is the guideline-level recommendation; salmon, sardines, mackerel, herring, and trout are the practical sources.",
                "Fish oil supplements have not reduced cardiovascular events in general-population trials such as VITAL and ASCEND.",
                "High-dose prescription EPA lowers triglycerides substantially and is a clinical decision, not a wellness one.",
                "Plant omega-3 (ALA from flax, chia, walnuts) converts to EPA and DHA inefficiently, so vegans often consider an algae-based DHA source.",
                "Doses above about 3 g/day may increase bleeding risk and atrial fibrillation signals have appeared in some trials."
            ]
        ),
        CoachKnowledgeEntry(
            id: "probiotics-fermented",
            topic: .supplements,
            title: "Probiotics and fermented foods",
            keywords: ["probiotic", "fermented", "yogurt", "kefir", "kimchi", "sauerkraut", "kombucha"],
            facts: [
                "Probiotic effects are strain-specific and condition-specific; 'probiotic' on a label says almost nothing about what a product does.",
                "The clearest evidence is for preventing antibiotic-associated diarrhea and for specific strains in irritable bowel syndrome.",
                "Most supplemented strains are transient — they pass through rather than colonize.",
                "A small randomized trial found fermented foods increased microbiome diversity and lowered inflammatory markers more than a high-fiber diet did, though this needs replication.",
                "Feeding existing gut bacteria with fiber and plant variety has stronger evidence than adding new bacteria from a capsule."
            ]
        )
    ]

    // MARK: - Frequently asked nutrition questions

    static let nutritionQuestionEntries: [CoachKnowledgeEntry] = [
        CoachKnowledgeEntry(
            id: "seed-oils",
            topic: .nutritionMyths,
            title: "Seed oils and cooking fats",
            keywords: ["seed oil", "canola", "vegetable oil", "sunflower", "soybean oil", "linoleic", "olive oil"],
            facts: [
                "Randomized trials consistently show that replacing saturated fat with polyunsaturated vegetable oils lowers LDL cholesterol and cardiovascular events.",
                "Higher blood levels of linoleic acid, the main omega-6 in seed oils, are associated with lower risk of cardiovascular disease and type 2 diabetes in pooled cohort data.",
                "Controlled feeding studies have not found that dietary linoleic acid raises inflammatory markers in humans, which is the central claim of the anti-seed-oil argument.",
                "Seed oils cluster in ultra-processed foods, so the association people notice is largely about the foods, not the oil.",
                "Extra virgin olive oil has the deepest outcome evidence (PREDIMED) and is a reasonable default; canola, avocado, and high-oleic oils are fine for higher-heat cooking."
            ]
        ),
        CoachKnowledgeEntry(
            id: "sweeteners",
            topic: .nutritionMyths,
            title: "Artificial and non-sugar sweeteners",
            keywords: ["artificial sweetener", "aspartame", "sucralose", "stevia", "diet soda", "erythritol", "sugar free"],
            facts: [
                "Approved sweeteners have large safety margins; typical consumption sits far below the acceptable daily intake, and the 2023 IARC classification of aspartame as 'possibly carcinogenic' came with JECFA reaffirming its existing intake limit.",
                "WHO issued a conditional recommendation in 2023 against using non-sugar sweeteners for weight control, based on low-certainty evidence of no long-term benefit.",
                "Swapping sugar-sweetened beverages for diet versions does reduce sugar and calorie intake in the short term, and randomized trials show modest weight benefit versus staying on sugar.",
                "Observational signals linking erythritol to cardiovascular events exist but are confounded and unconfirmed.",
                "Water, sparkling water, and unsweetened tea sidestep the debate entirely; diet drinks are best framed as a bridge, not a destination."
            ]
        ),
        CoachKnowledgeEntry(
            id: "detox-cleanse",
            topic: .nutritionMyths,
            title: "Detoxes, cleanses, and 'toxins'",
            keywords: ["detox", "cleanse", "juice cleanse", "toxins", "flush", "reset diet"],
            facts: [
                "The liver, kidneys, lungs, and gut clear metabolic waste continuously; no commercial cleanse has been shown to improve their function.",
                "No detox product has demonstrated clinical benefit in a controlled trial, and 'toxins' is almost never specified by the products claiming to remove them.",
                "Juice cleanses remove the fiber that makes fruit and vegetables valuable and can spike blood sugar.",
                "Risks include inadequate protein, electrolyte disturbance with laxative-based programs, and rebound eating.",
                "What actually supports clearance pathways is unglamorous: adequate fluid, fiber, protein, sleep, and less alcohol."
            ]
        ),
        CoachKnowledgeEntry(
            id: "red-processed-meat",
            topic: .nutritionMyths,
            title: "Red and processed meat",
            keywords: ["red meat", "processed meat", "bacon", "deli", "steak", "sausage", "hot dog"],
            facts: [
                "IARC classifies processed meat as a Group 1 carcinogen and red meat as Group 2A (probably carcinogenic); Group 1 describes strength of evidence, not size of risk.",
                "Pooled cohort data associate each 50 g/day of processed meat with roughly 16–18% higher relative colorectal cancer risk — a meaningful but modest absolute increase.",
                "World Cancer Research Fund guidance is to limit red meat to about three portions weekly (350–500 g cooked) and eat very little processed meat.",
                "Unprocessed red meat is nutrient-dense — heme iron, B12, zinc, high-quality protein — so the question is frequency, not prohibition.",
                "Swapping some red meat for legumes, fish, or poultry captures most of the modeled benefit without eliminating anything."
            ]
        ),
        CoachKnowledgeEntry(
            id: "eggs-cholesterol",
            topic: .nutritionMyths,
            title: "Eggs and dietary cholesterol",
            keywords: ["egg", "eggs", "dietary cholesterol", "yolk"],
            facts: [
                "Dietary cholesterol raises blood LDL far less than saturated and trans fat do for most people, which is why the 300 mg/day cap was dropped from US dietary guidance.",
                "Meta-analyses of cohorts generally find no association between up to about one egg per day and cardiovascular disease in generally healthy adults.",
                "Response varies: a minority are hyper-responders, and people with type 2 diabetes or familial hypercholesterolemia show less reassuring data.",
                "Eggs are inexpensive, satiating, and rich in choline, lutein, and complete protein.",
                "What accompanies the egg — bacon, sausage, buttered white toast — usually matters more than the egg."
            ]
        ),
        CoachKnowledgeEntry(
            id: "soy",
            topic: .nutritionMyths,
            title: "Soy foods and phytoestrogens",
            keywords: ["soy", "tofu", "edamame", "phytoestrogen", "soy milk", "tempeh"],
            facts: [
                "Clinical meta-analyses show soy foods and isoflavones do not lower testosterone, raise estrogen, or feminize men.",
                "Soy intake is associated with neutral-to-favorable breast cancer outcomes, including among survivors; guidance from major cancer organizations treats soy foods as safe.",
                "About 25 g/day of soy protein produces a small LDL reduction and carries an FDA heart-health claim.",
                "Minimally processed forms — tofu, tempeh, edamame, soy milk — carry the evidence; isolated isoflavone supplements do not.",
                "Soy is one of the few complete plant proteins, which makes it useful for people reducing animal foods."
            ]
        ),
        CoachKnowledgeEntry(
            id: "gluten-dairy",
            topic: .nutritionMyths,
            title: "Gluten and dairy",
            keywords: ["gluten", "celiac", "dairy", "lactose", "milk", "cheese", "gluten free"],
            facts: [
                "Gluten avoidance is medically necessary for celiac disease (about 1% of people), wheat allergy, and diagnosed non-celiac gluten sensitivity.",
                "For everyone else, gluten-free eating shows no health benefit and often lowers whole-grain and fiber intake.",
                "Celiac testing requires eating gluten beforehand, so it is worth testing before cutting it out.",
                "Lactose intolerance is common and dose-dependent; aged cheeses and yogurt are usually tolerated because fermentation reduces lactose.",
                "Fermented dairy such as yogurt and kefir is associated with neutral-to-favorable cardiometabolic outcomes; fortified soy milk is the closest non-dairy nutritional match."
            ]
        ),
        CoachKnowledgeEntry(
            id: "organic-produce",
            topic: .nutritionMyths,
            title: "Organic versus conventional produce",
            keywords: ["organic", "pesticide", "dirty dozen", "conventional", "grass fed"],
            facts: [
                "Systematic reviews find minimal nutritional difference between organic and conventional produce, apart from somewhat higher antioxidant and lower cadmium levels in organic.",
                "Organic produce does lower measured pesticide residue exposure, though residues on conventional produce in the US are typically far below regulatory safety thresholds.",
                "No trial has shown a health outcome difference; cohort evidence is mixed and heavily confounded by income and overall diet quality.",
                "Total vegetable and fruit intake predicts outcomes much more strongly than whether they were organically grown.",
                "If cost forces a trade-off, buying more conventional, frozen, or canned produce beats buying less organic produce."
            ]
        ),
        CoachKnowledgeEntry(
            id: "carbs-and-low-carb",
            topic: .nutritionMyths,
            title: "Carbohydrates, keto, and low-carb eating",
            keywords: ["carb", "carbs", "keto", "low carb", "ketogenic", "atkins", "carbohydrate"],
            facts: [
                "Carbohydrate quality separates outcomes far more than quantity: whole grains, legumes, fruit, and vegetables associate with lower disease risk while refined starch and added sugar do the opposite.",
                "Head-to-head trials of low-carb versus low-fat diets show similar average weight change at twelve months; adherence dominates the result.",
                "Very low-carb and ketogenic patterns can improve triglycerides and glycemic control short term, though LDL rises in a subset of people.",
                "Cohort data suggest a U-shaped mortality curve, with the lowest risk around 50% of calories from carbohydrate and higher risk at both extremes when replacements are animal-based.",
                "Cutting carbohydrate usually also cuts fiber, which is the piece worth protecting deliberately."
            ]
        ),
        CoachKnowledgeEntry(
            id: "metabolism",
            topic: .nutritionMyths,
            title: "Metabolism and 'starvation mode'",
            keywords: ["metabolism", "slow metabolism", "metabolic rate", "starvation mode", "burn calories"],
            facts: [
                "Resting metabolic rate accounts for roughly 60–70% of daily energy use and scales mostly with fat-free mass, which is why bigger and more muscular bodies burn more at rest.",
                "Large doubly-labeled-water analyses found total energy expenditure adjusted for body composition is stable from about age 20 to 60, then declines slowly — the 'metabolism crashes at 40' story is not supported.",
                "Adaptive thermogenesis after weight loss is real but modest, on the order of tens to a couple hundred calories per day, not a shutdown.",
                "Non-exercise activity — walking, fidgeting, standing — varies enormously between people and often drops silently during dieting.",
                "There is no food, spice, or supplement that meaningfully 'boosts metabolism'; muscle mass and daily movement are the levers that exist."
            ]
        ),
        CoachKnowledgeEntry(
            id: "meal-timing",
            topic: .nutritionMyths,
            title: "Meal timing and late eating",
            keywords: ["meal timing", "late eating", "night eating", "before bed", "eat after", "when to eat"],
            facts: [
                "Total intake and food quality dominate; timing is a secondary lever for most people.",
                "Controlled crossover studies do show worse glucose tolerance and greater hunger when the same calories are eaten late in the evening, reflecting circadian rhythms in insulin sensitivity.",
                "Large meals within roughly three hours of bed worsen reflux and fragment sleep for many people.",
                "A light protein or carbohydrate snack before bed does not harm sleep and can help people who wake hungry.",
                "Skipping breakfast is not inherently harmful; in practice it often shifts intake later and raises evening eating."
            ]
        )
    ]

    // MARK: - Frequently asked exercise questions

    static let exerciseQuestionEntries: [CoachKnowledgeEntry] = [
        CoachKnowledgeEntry(
            id: "spot-reduction",
            topic: .exerciseMyths,
            title: "Spot reduction and 'toning'",
            keywords: ["spot reduction", "belly fat", "toning", "tone up", "target fat", "love handles", "abs"],
            facts: [
                "Training a body part does not preferentially remove fat from it; controlled studies of localized training show no regional fat loss advantage.",
                "Where fat is lost is largely genetic and hormonal, and it is not something training can direct.",
                "'Toning' describes building muscle while reducing overlying fat, which comes from resistance training plus overall energy balance.",
                "Abdominal exercises strengthen the trunk and support posture and back health, which is worth doing for its own reasons.",
                "Visceral fat responds well to aerobic activity and better sleep, often before any change shows on the scale."
            ]
        ),
        CoachKnowledgeEntry(
            id: "stretching-warmup",
            topic: .exerciseMyths,
            title: "Stretching, warm-ups, and flexibility",
            keywords: ["stretch", "stretching", "warm up", "warmup", "cool down", "flexibility", "mobility"],
            facts: [
                "Long static stretches held over about 60 seconds immediately before lifting or sprinting produce small acute reductions in strength and power.",
                "A dynamic warm-up — five to ten minutes of progressively harder movement rehearsing the activity — is the better pre-exercise choice.",
                "Meta-analyses find stretching alone has little effect on overall injury risk; structured neuromuscular warm-up programs do reduce injuries in sport.",
                "Static stretching does improve range of motion when done consistently, and post-exercise or standalone sessions are a fine time for it.",
                "Stretching does not prevent or meaningfully reduce delayed-onset muscle soreness."
            ]
        ),
        CoachKnowledgeEntry(
            id: "soreness-recovery",
            topic: .exerciseMyths,
            title: "Muscle soreness and rest days",
            keywords: ["sore", "soreness", "doms", "rest day", "recovery day", "too sore"],
            facts: [
                "Delayed-onset muscle soreness peaks 24–72 hours after unfamiliar or eccentric work and fades as the same movement is repeated.",
                "Soreness is not a measure of workout quality and is not required for strength or fitness adaptation.",
                "Light movement — walking, easy cycling, mobility work — relieves soreness better than complete rest.",
                "Sharp, one-sided, or joint-line pain is different from diffuse muscle soreness and deserves attention rather than pushing through.",
                "Persistent soreness alongside poor sleep, low mood, and stalled performance suggests under-recovery rather than insufficient training."
            ]
        ),
        CoachKnowledgeEntry(
            id: "cardio-types",
            topic: .exerciseMyths,
            title: "HIIT, zone 2, and choosing cardio",
            keywords: ["hiit", "interval", "intervals", "zone 2", "cardio", "best workout", "steady state"],
            facts: [
                "Both interval and continuous moderate training improve cardiorespiratory fitness; intervals produce slightly larger VO2max gains per minute invested in meta-analyses.",
                "Guidelines treat one minute of vigorous activity as equivalent to two minutes of moderate, which is why 75–150 vigorous minutes substitutes for 150–300 moderate minutes.",
                "Lower-intensity work is easier to recover from and to sustain, which usually matters more than the theoretical advantage of intervals.",
                "A practical mix is most sessions easy enough to hold a conversation, with one or two harder sessions weekly.",
                "The best cardio is the kind that gets done repeatedly; adherence beats optimization at every level below elite sport."
            ]
        ),
        CoachKnowledgeEntry(
            id: "step-counts",
            topic: .exerciseMyths,
            title: "Step counts and what the numbers mean",
            keywords: ["steps", "10000", "10,000", "step count", "step goal", "pedometer"],
            facts: [
                "The 10,000-step target came from 1960s Japanese pedometer marketing, not from research.",
                "Meta-analyses show mortality risk falls steeply from about 2,500 steps per day and largely plateaus around 7,000–8,000 for most adults, with the plateau lower in older adults.",
                "Cadence matters somewhat: faster walking is associated with additional benefit beyond total volume.",
                "Steps and structured exercise minutes measure overlapping but different things; this app scores minutes of intentional activity.",
                "Adding roughly 1,000 steps per day to a current baseline is a more useful target than any universal number."
            ]
        )
    ]

    // MARK: - Cardiometabolic questions

    static let cardiometabolicEntries: [CoachKnowledgeEntry] = [
        CoachKnowledgeEntry(
            id: "blood-pressure",
            topic: .cardiometabolic,
            title: "Blood pressure and lifestyle",
            keywords: ["blood pressure", "hypertension", "systolic", "diastolic", "dash"],
            facts: [
                "US guidelines define normal as under 120/80 mmHg, elevated as 120–129 systolic, and stage 1 hypertension as 130–139 or 80–89.",
                "The DASH dietary pattern lowers systolic pressure by roughly 5–11 mmHg, and combining it with sodium reduction produces the largest effect.",
                "Reducing sodium by about 1,000 mg/day lowers systolic pressure a few mmHg on average, with larger effects in salt-sensitive people.",
                "Regular aerobic activity lowers systolic pressure about 5–8 mmHg; isometric work such as wall sits shows surprisingly strong effects in recent meta-analyses.",
                "Potassium-rich foods, weight change, less alcohol, and better sleep each contribute; readings should be taken seated, arm supported, after five quiet minutes."
            ]
        ),
        CoachKnowledgeEntry(
            id: "cholesterol",
            topic: .cardiometabolic,
            title: "Cholesterol and lipids",
            keywords: ["cholesterol", "ldl", "hdl", "triglyceride", "lipid", "statin", "apob"],
            facts: [
                "LDL cholesterol is causally linked to atherosclerotic cardiovascular disease; lowering it lowers risk, and apolipoprotein B is an increasingly preferred measure.",
                "Replacing saturated fat with unsaturated fat is the single most effective dietary lever on LDL.",
                "Five to ten grams per day of viscous soluble fiber — oats, barley, psyllium, legumes — lowers LDL by roughly 5%, and plant sterols at 2 g/day lower it about 8–10%.",
                "Exercise mainly lowers triglycerides and raises HDL rather than moving LDL much.",
                "Lipid targets and medication decisions are clinical; the lifestyle contribution is real but complements rather than replaces that conversation."
            ]
        ),
        CoachKnowledgeEntry(
            id: "blood-sugar",
            topic: .cardiometabolic,
            title: "Blood sugar, A1c, and glucose spikes",
            keywords: ["blood sugar", "glucose", "a1c", "prediabetes", "insulin", "cgm", "spike", "diabetes"],
            facts: [
                "The Diabetes Prevention Program showed that modest weight change plus 150 minutes weekly of activity reduced progression from prediabetes to type 2 diabetes by 58%, outperforming metformin.",
                "A 10–15 minute walk after meals meaningfully blunts post-meal glucose rises, and it works even when the walk is easy.",
                "Muscle is the largest site of glucose disposal, so resistance training improves glycemic control independently of aerobic work.",
                "Fiber, protein, and fat slow gastric emptying and flatten the same carbohydrate's glucose curve; eating vegetables and protein before starch has a modest measured effect.",
                "Continuous glucose monitors in people without diabetes show variation that is largely normal physiology; interpreting A1c or diagnosing anything is a clinician's job."
            ]
        ),
        CoachKnowledgeEntry(
            id: "cardiorespiratory-fitness",
            topic: .cardiometabolic,
            title: "Cardiorespiratory fitness as a health marker",
            keywords: ["vo2", "vo2max", "cardio fitness", "fitness level", "aerobic capacity", "mets"],
            facts: [
                "Cardiorespiratory fitness is one of the strongest predictors of all-cause mortality, rivaling or exceeding smoking, hypertension, and diabetes as a risk marker.",
                "The largest survival difference sits between the least fit and the next group up, so early gains matter most.",
                "Fitness improves at any age; older previously sedentary adults show substantial relative gains from consistent training.",
                "Watch-estimated VO2max is imprecise in absolute terms but useful as a personal trend.",
                "Both easy aerobic volume and occasional harder efforts contribute; consistency over months is what moves it."
            ]
        ),
        CoachKnowledgeEntry(
            id: "heat-cold-exposure",
            topic: .cardiometabolic,
            title: "Sauna, heat, and cold exposure",
            keywords: ["sauna", "cold plunge", "ice bath", "cold exposure", "heat therapy", "cold shower"],
            facts: [
                "Finnish cohort studies associate frequent sauna use with lower cardiovascular and all-cause mortality, and heat exposure acutely improves vascular function — but this evidence is observational.",
                "Sauna is not a substitute for exercise, though it may be a useful adjunct for people with limited mobility.",
                "Cold water immersion reduces perceived soreness; taken immediately after resistance training it appears to blunt muscle hypertrophy adaptations.",
                "Reported mood and alertness benefits from cold exposure are short-term and largely unblinded.",
                "Both carry real cardiovascular risk for some people, and neither should follow heavy alcohol use or be done alone."
            ]
        )
    ]

    // MARK: - Life stages and practical logistics

    static let lifeContextEntries: [CoachKnowledgeEntry] = [
        CoachKnowledgeEntry(
            id: "aging-muscle",
            topic: .lifeStages,
            title: "Aging, muscle, and falls",
            keywords: ["aging", "older", "sarcopenia", "muscle loss", "elderly", "getting older", "balance"],
            facts: [
                "Muscle mass declines roughly 3–8% per decade after age 30 and faster after 60, with strength declining even more quickly than mass.",
                "Resistance training produces meaningful gains at every age studied, including in adults in their eighties and nineties.",
                "Protein needs rise with age due to anabolic resistance; 1.0–1.2 g/kg/day is commonly recommended for older adults, with some evidence supporting more.",
                "Multicomponent programs including balance work reduce fall risk by roughly a quarter in older adults.",
                "Grip strength and chair-stand speed are simple, well-validated functional markers worth tracking over years."
            ]
        ),
        CoachKnowledgeEntry(
            id: "menopause",
            topic: .lifeStages,
            title: "Perimenopause and menopause",
            keywords: ["menopause", "perimenopause", "hot flash", "night sweats", "hormones"],
            facts: [
                "Sleep disruption is one of the most common and underdiscussed symptoms, driven by vasomotor symptoms and changes in sleep architecture.",
                "Bone loss accelerates around the menopausal transition, making resistance and impact training especially valuable.",
                "Cardiovascular risk rises after menopause, so blood pressure and lipids deserve attention during this window.",
                "Cognitive behavioral therapy has evidence for both insomnia and vasomotor symptom distress in this population.",
                "Hormone therapy decisions are individualized and belong with a clinician who knows the person's history."
            ]
        ),
        CoachKnowledgeEntry(
            id: "pain-and-movement",
            topic: .lifeStages,
            title: "Back pain, joint pain, and movement",
            keywords: ["back pain", "knee pain", "joint", "arthritis", "hurts", "sore knees", "hip pain"],
            facts: [
                "For chronic low back pain, exercise therapy is first-line in clinical guidelines and extended bed rest worsens outcomes.",
                "In knee osteoarthritis, strength training and walking reduce pain and improve function; they do not accelerate joint damage.",
                "Pain is modulated by sleep, stress, and mood as well as tissue state, which is why poor sleep reliably amplifies it.",
                "Reducing load and range temporarily, then rebuilding gradually, usually beats stopping entirely.",
                "Red flags — numbness, weakness, bowel or bladder changes, unexplained weight loss, night pain, fever — need medical evaluation rather than a training tweak."
            ]
        ),
        CoachKnowledgeEntry(
            id: "eating-on-a-budget",
            topic: .practicalEating,
            title: "Eating well on a budget and short on time",
            keywords: ["budget", "cheap", "expensive", "afford", "cost", "no time to cook", "meal prep", "busy"],
            facts: [
                "Dried and canned legumes, oats, brown rice, frozen vegetables, frozen berries, eggs, canned fish, and peanut butter deliver the most fiber and protein per dollar.",
                "Frozen and canned produce are nutritionally comparable to fresh and often better than fresh that spoils before it is eaten; rinsing canned beans cuts sodium substantially.",
                "Batch-cooking one pot of beans, grains, or soup weekly removes most weekday decisions.",
                "Keeping two or three genuinely fast default meals on hand beats aspirational recipes that require a shopping trip.",
                "A 15-gram fiber gap usually closes with one cup of beans, one bowl of oatmeal with berries, or a handful of nuts plus a piece of fruit — not with a diet overhaul."
            ]
        ),
        CoachKnowledgeEntry(
            id: "travel-and-eating-out",
            topic: .practicalEating,
            title: "Restaurants, travel, and disrupted routines",
            keywords: ["restaurant", "eating out", "travel", "airport", "takeout", "vacation", "hotel"],
            facts: [
                "Restaurant portions and added fat, sodium, and sugar are usually the difference, not any single menu item.",
                "Anchoring the order around a protein and a vegetable, and adding a side of beans or a salad, moves the meal more than avoiding a specific food.",
                "Travel disrupts sleep and activity more than diet for most people; protecting sleep timing usually pays the largest dividend.",
                "Walking is the most portable form of exercise, and hotel bodyweight circuits cover strength adequately for a week or two.",
                "A disrupted week is a pause, not a failure; the recovery habit is resuming the next normal meal or day rather than waiting for Monday."
            ]
        ),
        CoachKnowledgeEntry(
            id: "shift-work-jet-lag",
            topic: .practicalEating,
            title: "Shift work and jet lag",
            keywords: ["shift work", "night shift", "jet lag", "time zone", "overnight", "rotating shift"],
            facts: [
                "Circadian misalignment, not just short sleep, drives the metabolic and cardiovascular risks associated with shift work.",
                "The body clock shifts roughly one hour per day, so full adjustment to a large time-zone change takes several days.",
                "Light is the dominant signal: bright light during the intended wake period and darkness or blue-blocking before the intended sleep period.",
                "Anchor sleep — a consistent core block kept even on off days — reduces the cost of rotating schedules.",
                "Caffeine early in a shift and avoided in the final hours, plus a dark, cool, quiet daytime sleep environment, are the practical levers."
            ]
        )
    ]

    static let all: [CoachKnowledgeEntry] =
        nutritionEntries + activityEntries + sleepEntries + mindEntries
            + socialAndBehaviorEntries + appEntries + supplementEntries
            + nutritionQuestionEntries + exerciseQuestionEntries
            + cardiometabolicEntries + lifeContextEntries
}
