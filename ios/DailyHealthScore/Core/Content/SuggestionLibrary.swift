import Foundation

enum SuggestionLibrary {
    static func pool(for focus: PrimaryFocus, phase: DayPhase) -> [ContentEntry] {
        switch (focus, phase) {
        case (.sleep, .day): return sleepDay
        case (.sleep, .evening): return sleepEvening
        case (.fiber, .day): return fiberDay
        case (.fiber, .evening): return fiberEvening
        case (.exercise, .day): return exerciseDay
        case (.exercise, .evening): return exerciseEvening
        case (.maintain, .day): return maintainDay
        case (.maintain, .evening): return maintainEvening
        }
    }

    // MARK: - Sleep (day) — caffeine, light, walks; fuel today for tonight

    private static let sleepDay: [ContentEntry] = [
        ContentEntry(id: "sleep-day-01", text: "Today, cut caffeine by mid‑afternoon if you can—your future self at bedtime will notice."),
        ContentEntry(id: "sleep-day-02", text: "Take a 10–15 minute walk outside today; daylight and movement both support tonight’s sleep."),
        ContentEntry(id: "sleep-day-03", text: "You’re building sleep for people you care about—steady days make kinder evenings. Plan one calm block tonight."),
        ContentEntry(id: "sleep-day-04", text: "If you’re tempted to nap today, keep it short (about 20 minutes) and finish before mid‑afternoon."),
        ContentEntry(id: "sleep-day-05", text: "Today, swap an extra coffee for water after lunch—small fuel choices change how you feel at night."),
        ContentEntry(id: "sleep-day-06", text: "A brief walk after a meal today can ease stress without reaching for snacks—protect the evening you want."),
        ContentEntry(id: "sleep-day-07", text: "Think bigger picture: rested you shows up better in relationships. Today, guard your afternoon energy."),
        ContentEntry(id: "sleep-day-08", text: "Today, notice stress rising—and try a slow exhale and a glass of water before more caffeine."),
        ContentEntry(id: "sleep-day-09", text: "Get a few minutes of outdoor light today, even on a cloudy day; it helps anchor your body clock."),
        ContentEntry(id: "sleep-day-10", text: "Today, avoid stacking heavy meals and late espresso—give your body an easier path to sleep tonight."),
        ContentEntry(id: "sleep-day-11", text: "When tired this afternoon, a short walk may restore you more than scrolling—try it once today."),
        ContentEntry(id: "sleep-day-12", text: "Healthy bodies support healthy connections. Today, choose one habit that makes tonight’s wind‑down realistic."),
        ContentEntry(id: "sleep-day-13", text: "If evening snacking is your stress default, plan a satisfying lunch with protein and fiber today."),
        ContentEntry(id: "sleep-day-14", text: "Today, move your body at a comfortable pace—gentle activity today often means an easier time falling asleep."),
        ContentEntry(id: "sleep-day-15", text: "Set a loose ‘last caffeine’ time today and stick to it—direct, kind boundary for tonight."),
        ContentEntry(id: "sleep-day-16", text: "Pause before afternoon treats: are you hungry, tired, or seeking comfort? Name it, then choose on purpose."),
        ContentEntry(id: "sleep-day-17", text: "Today, keep hydration steady—dehydration and fatigue can masquerade as ‘need sugar now.’"),
        ContentEntry(id: "sleep-day-18", text: "You don’t have to earn rest tonight—start supporting it now with light, movement, and calmer fuel today."),
    ]

    // MARK: - Sleep (evening)

    private static let sleepEvening: [ContentEntry] = [
        ContentEntry(id: "sleep-01", text: "Tonight, set a phone charging station outside the bedroom and start wind‑down 45 minutes before lights out."),
        ContentEntry(id: "sleep-02", text: "Tomorrow morning, get 5–10 minutes of outdoor light soon after waking to anchor your clock."),
        ContentEntry(id: "sleep-03", text: "Pick a fixed wake time for the next 3 days; adjust bedtime—not the alarm—to protect sleep pressure."),
        ContentEntry(id: "sleep-04", text: "Cut caffeine after 2:00 PM tomorrow (earlier if you are sensitive) and replace it with water or herbal tea."),
        ContentEntry(id: "sleep-05", text: "Tonight, dim warm lights after dinner and avoid bright overhead lighting in the last hour before bed."),
        ContentEntry(id: "sleep-06", text: "Schedule a 10‑minute ‘shutdown ritual’ tonight: lay out clothes, set tomorrow’s top priority, then stop planning."),
        ContentEntry(id: "sleep-07", text: "Keep the bedroom cooler tonight (many people sleep better near 65–68°F / 18–20°C if comfortable)."),
        ContentEntry(id: "sleep-08", text: "Avoid alcohol within 3 hours of bedtime tonight; even small amounts can fragment sleep."),
        ContentEntry(id: "sleep-09", text: "If you wake at night, resist clock‑watching; breathe slowly and keep lights off unless safety requires them."),
        ContentEntry(id: "sleep-10", text: "Tonight, try a short relaxation sequence: slow exhale‑longer‑than‑inhale for 3 minutes before sleep."),
        ContentEntry(id: "sleep-11", text: "Tomorrow, take a 15‑minute midday movement break instead of extra evening screen time."),
        ContentEntry(id: "sleep-12", text: "Set one consistent ‘lights out’ time for the next week—even if reading time is shorter at first."),
        ContentEntry(id: "sleep-13", text: "Reduce late‑night snacks tonight; if hungry, choose something small and easy to digest."),
        ContentEntry(id: "sleep-14", text: "Tonight, swap late social scrolling for a paper book or calming audio for the final 20 minutes."),
        ContentEntry(id: "sleep-15", text: "Tomorrow evening, finish vigorous exercise at least 3 hours before bed if intense workouts affect your sleep."),
        ContentEntry(id: "sleep-16", text: "Use white noise or steady sound tonight if small noises tend to wake you."),
        ContentEntry(id: "sleep-17", text: "Keep a notepad by the bed tonight—write worries down once, then close the loop until morning."),
        ContentEntry(id: "sleep-18", text: "Align meals so dinner isn’t your heaviest meal within 2 hours of bedtime tonight."),
        ContentEntry(id: "sleep-19", text: "Tomorrow, limit long naps; if needed, cap a nap at 20 minutes and finish before mid‑afternoon."),
        ContentEntry(id: "sleep-20", text: "Tonight, trial blackout curtains or an eye mask if daylight or streetlights enter your room."),
    ]

    // MARK: - Fiber (day) — today fuel, mindful eating, evening slip risk

    private static let fiberDay: [ContentEntry] = [
        ContentEntry(id: "fiber-day-01", text: "Today, add one high‑fiber side to your next meal—beans, berries, or vegetables—before evening hunger hits."),
        ContentEntry(id: "fiber-day-02", text: "When you fuel your body well today, it works with you tonight. Plan lunch fiber now, not after you’re exhausted."),
        ContentEntry(id: "fiber-day-03", text: "Later today, tired-you may snack on autopilot. Choose one intentional snack this afternoon (fruit, nuts, hummus) and skip mindless grazing."),
        ContentEntry(id: "fiber-day-04", text: "Pause before opening the pantry: hungry, stressed, or bored? One honest check can save the evening."),
        ContentEntry(id: "fiber-day-05", text: "Healthy relationships need steady energy—you’re allowed to prioritize whole‑food fuel today over quick comfort."),
        ContentEntry(id: "fiber-day-06", text: "Today, build your plate around plants at one meal: half vegetables, some beans or lentils, intact grains if you like."),
        ContentEntry(id: "fiber-day-07", text: "If you’re on track this morning, protect the afternoon—that’s when many people drift. Add fiber at lunch on purpose."),
        ContentEntry(id: "fiber-day-08", text: "Stress wants immediate relief; fiber and protein today give calmer energy for the people you care about tonight."),
        ContentEntry(id: "fiber-day-09", text: "Today, keep a water bottle visible—thirst often masquerades as ‘need chips now.’"),
        ContentEntry(id: "fiber-day-10", text: "Before evening, prep one easy fiber option (washed fruit, carrot sticks, bean leftovers) so comfort food isn’t the only option."),
        ContentEntry(id: "fiber-day-11", text: "Choose the higher‑fiber option today when it’s close—whole fruit over juice, beans over refined sides."),
        ContentEntry(id: "fiber-day-12", text: "A short walk today can blunt stress eating—movement first, then decide if you still want a snack."),
        ContentEntry(id: "fiber-day-13", text: "You’re not behind forever—you have hours left. One fiber‑rich meal today still moves the score and your body."),
        ContentEntry(id: "fiber-day-14", text: "Today, eat slowly enough to notice fullness—mindless eating steals fiber goals and evening calm."),
        ContentEntry(id: "fiber-day-15", text: "Think week‑scale, not bite‑scale: today’s choices are how you show up for family, work, and yourself tomorrow."),
        ContentEntry(id: "fiber-day-16", text: "If cravings spike this afternoon, try protein plus fiber together (e.g. apple with almonds) before ultra‑processed snacks."),
        ContentEntry(id: "fiber-day-17", text: "Today, add vegetables to whatever you already planned—low effort, real fiber, fewer empty evening calories."),
        ContentEntry(id: "fiber-day-18", text: "Tonight will feel easier if you front‑load plants today—gentle reminder, not guilt: one good meal still counts."),
    ]

    // MARK: - Fiber (evening)

    private static let fiberEvening: [ContentEntry] = [
        ContentEntry(id: "fiber-01", text: "Tomorrow, add ½ cup cooked lentils or black beans to lunch or dinner."),
        ContentEntry(id: "fiber-02", text: "Stir 1–2 tablespoons ground flaxseed into oatmeal or a smoothie tomorrow morning."),
        ContentEntry(id: "fiber-03", text: "Build one meal tomorrow around beans, leafy greens, and an intact whole grain like barley or brown rice."),
        ContentEntry(id: "fiber-04", text: "Tomorrow, choose fruit with edible peel (apple or pear) plus a handful of berries as a snack."),
        ContentEntry(id: "fiber-05", text: "Add chickpeas or kidney beans to a salad or grain bowl tomorrow."),
        ContentEntry(id: "fiber-06", text: "Tomorrow, swap refined grains for oats, quinoa, or intact whole‑wheat pasta in one meal."),
        ContentEntry(id: "fiber-07", text: "Include a vegetable soup with beans and vegetables tomorrow; choose a lower‑salt recipe if canned."),
        ContentEntry(id: "fiber-08", text: "Tomorrow, snack on carrots, peppers, or cucumbers with hummus instead of crackers alone."),
        ContentEntry(id: "fiber-09", text: "Cook split peas or pigeon peas tomorrow as a soup or stew base with vegetables."),
        ContentEntry(id: "fiber-10", text: "Tomorrow, top breakfast with chia seeds or hemp hearts alongside fruit."),
        ContentEntry(id: "fiber-11", text: "Make a bean‑based taco or wrap tomorrow using soft corn tortillas and salsa."),
        ContentEntry(id: "fiber-12", text: "Tomorrow, replace one refined snack with edamame (pods) or roasted chickpeas."),
        ContentEntry(id: "fiber-13", text: "Add shredded cabbage or kale tomorrow to a stir‑fry built around tofu or beans."),
        ContentEntry(id: "fiber-14", text: "Tomorrow, choose a pear or orange plus a small handful of walnuts as an afternoon snack."),
        ContentEntry(id: "fiber-15", text: "Prepare farro or bulgur tomorrow as a side with roasted vegetables."),
        ContentEntry(id: "fiber-16", text: "Tomorrow, blend white beans into a soup for thickness instead of cream."),
        ContentEntry(id: "fiber-17", text: "Pack a banana plus almonds tomorrow for a portable whole‑plant snack."),
        ContentEntry(id: "fiber-18", text: "Tomorrow, try mung beans or adzuki beans in a simple curry with tomatoes and spices."),
        ContentEntry(id: "fiber-19", text: "Add raspberries or blackberries to plain oats tomorrow; skip ultra‑processed cereal toppings."),
        ContentEntry(id: "fiber-20", text: "Tomorrow, build a dinner plate that is half vegetables (mixed colors), one‑quarter intact grains, one‑quarter beans."),
    ]

    // MARK: - Exercise (day)

    private static let exerciseDay: [ContentEntry] = [
        ContentEntry(id: "exercise-day-01", text: "Today, take a 10‑minute walk before you reach for stress snacks—movement can reset the urge."),
        ContentEntry(id: "exercise-day-02", text: "You still have time on the clock: one brisk walk this afternoon counts toward your goal and your mood."),
        ContentEntry(id: "exercise-day-03", text: "Healthy bodies support patience in relationships. Today, move once on purpose, even if it’s modest."),
        ContentEntry(id: "exercise-day-04", text: "If you’re partly on track, don’t coast—evening fatigue steals minutes. Schedule a short walk before dinner."),
        ContentEntry(id: "exercise-day-05", text: "Today, choose stairs once or park a little farther—small bursts add up without a ‘perfect workout.’"),
        ContentEntry(id: "exercise-day-06", text: "Stress relief doesn’t have to be food. A quick walk today is immediate gratification that still fits the bigger picture."),
        ContentEntry(id: "exercise-day-07", text: "Today, stand and pace during one call or meeting—exercise minutes can be woven in, not postponed."),
        ContentEntry(id: "exercise-day-08", text: "When tired this afternoon, try walking first for five minutes—then decide if you still need a couch snack."),
        ContentEntry(id: "exercise-day-09", text: "Invite someone you care about on a short walk today—movement plus connection beats solo scrolling."),
        ContentEntry(id: "exercise-day-10", text: "Today, protect a 15‑minute movement window like an appointment—you’re worth the calendar block."),
        ContentEntry(id: "exercise-day-11", text: "Immediate comfort is loud; long‑term health is quiet. Today, add quiet minutes on your feet."),
        ContentEntry(id: "exercise-day-12", text: "If weather is poor, march in place during one break today—effort still counts."),
        ContentEntry(id: "exercise-day-13", text: "Today, finish one errand on foot if safe—practical minutes beat waiting for motivation tonight."),
        ContentEntry(id: "exercise-day-14", text: "You’re building a body that can play, work, and rest well—today’s walk is part of that story."),
        ContentEntry(id: "exercise-day-15", text: "Before evening slump, drink water and walk once—hydration plus movement blunts ‘I give up’ snacking."),
        ContentEntry(id: "exercise-day-16", text: "Today, try music only during a walk—pair pleasure with movement instead of ultra‑processed comfort food."),
        ContentEntry(id: "exercise-day-17", text: "Gentle and direct: six 5‑minute walks today still move the needle if a single 30‑minute block feels heavy."),
        ContentEntry(id: "exercise-day-18", text: "Tonight-you will be tired. Earn calmer evenings by moving while you still have daylight and choice."),
    ]

    // MARK: - Exercise (evening)

    private static let exerciseEvening: [ContentEntry] = [
        ContentEntry(id: "exercise-01", text: "Tomorrow, complete two 15‑minute brisk walks—one mid‑morning and one after lunch."),
        ContentEntry(id: "exercise-02", text: "After one meal tomorrow, take a 10‑minute walk before sitting back down."),
        ContentEntry(id: "exercise-03", text: "Block 30 minutes on your calendar tomorrow for walking—protect it like a meeting."),
        ContentEntry(id: "exercise-04", text: "Tomorrow, park farther away or get off transit one stop early to add walking minutes."),
        ContentEntry(id: "exercise-05", text: "Do three 10‑minute walks tomorrow spaced through the day."),
        ContentEntry(id: "exercise-06", text: "Tomorrow morning, start the day with an 8‑minute brisk walk before coffee."),
        ContentEntry(id: "exercise-07", text: "Pair exercise with a habit you already do: walk immediately after brushing teeth tomorrow evening."),
        ContentEntry(id: "exercise-08", text: "Tomorrow, take calls while pacing or standing when possible."),
        ContentEntry(id: "exercise-09", text: "Choose stairs once tomorrow instead of an elevator for a short burst."),
        ContentEntry(id: "exercise-10", text: "Tomorrow, walk with a friend or family member for accountability and connection."),
        ContentEntry(id: "exercise-11", text: "If weather is rough tomorrow, march in place during two TV breaks."),
        ContentEntry(id: "exercise-12", text: "Tomorrow, set a gentle alarm every 90 minutes to stand and walk for 3 minutes."),
        ContentEntry(id: "exercise-13", text: "Finish tomorrow’s exercise minutes with an easy cooldown stretch routine."),
        ContentEntry(id: "exercise-14", text: "Tomorrow, explore a new loop near home to keep walking interesting."),
        ContentEntry(id: "exercise-15", text: "Combine errands tomorrow so at least 20 minutes are on foot."),
        ContentEntry(id: "exercise-16", text: "Tomorrow, try a beginner‑friendly bodyweight circuit at home for 12 minutes, then walk."),
        ContentEntry(id: "exercise-17", text: "Split exercise across chores tomorrow: vigorous cleaning counts—keep intensity brisk."),
        ContentEntry(id: "exercise-18", text: "Tomorrow, walk to a destination you usually drive to if it is safe and realistic."),
        ContentEntry(id: "exercise-19", text: "Use music or a podcast tomorrow only during your walk to create a cue."),
        ContentEntry(id: "exercise-20", text: "If short on time tomorrow, do six 5‑minute brisk walks—equal effort adds up."),
    ]

    // MARK: - Maintain (day) — protect evening, slip risk even when on track

    private static let maintainDay: [ContentEntry] = [
        ContentEntry(id: "maintain-day-01", text: "You’re on track today—still plan for tonight, when fatigue invites comfort snacking. Decide one gentle evening snack now."),
        ContentEntry(id: "maintain-day-02", text: "Strong morning doesn’t guarantee strong night. Today, keep meals steady so you don’t ‘reward’ yourself into a slip."),
        ContentEntry(id: "maintain-day-03", text: "Healthy bodies help healthy relationships—maintain with kindness, not rigidity, if stress rises later."),
        ContentEntry(id: "maintain-day-04", text: "Today, take a short walk even though you’re doing well—movement buffers stress before it becomes mindless eating."),
        ContentEntry(id: "maintain-day-05", text: "When you fuel correctly today, everything works smoother tonight. Repeat what already worked at lunch."),
        ContentEntry(id: "maintain-day-06", text: "Immediate gratification is tempting this evening. Remember the bigger picture: how you want to feel waking up tomorrow."),
        ContentEntry(id: "maintain-day-07", text: "You matched targets so far—protect the afternoon with water, fiber, and one planned snack instead of grazing."),
        ContentEntry(id: "maintain-day-08", text: "Today, notice pride without complacency—many slips happen after a good day. Stay present at dinner."),
        ContentEntry(id: "maintain-day-09", text: "Call or text someone you care about and take a brief walk—connection plus movement beat solo stress eating."),
        ContentEntry(id: "maintain-day-10", text: "Maintain mode is quiet discipline. Today, choose the healthier option when it’s a close call."),
        ContentEntry(id: "maintain-day-11", text: "If you’re ahead on goals, invest the margin: prep vegetables or beans for tonight so exhaustion doesn’t decide dinner."),
        ContentEntry(id: "maintain-day-12", text: "Today, pause before second servings—mindless extras are how ‘on track’ days unravel."),
        ContentEntry(id: "maintain-day-13", text: "You’re building trust with yourself. Honor it by walking once before you settle in for the evening."),
        ContentEntry(id: "maintain-day-14", text: "Stress will show up; you get to choose the response. Walk, breathe, then eat if you’re still hungry."),
        ContentEntry(id: "maintain-day-15", text: "Keep caffeine reasonable today if sleep is part of your success stack—even in maintain mode."),
        ContentEntry(id: "maintain-day-16", text: "Today’s stability supports people who rely on you. Eat enough at lunch so the pantry isn’t dinner."),
        ContentEntry(id: "maintain-day-17", text: "Celebrate quietly: note one habit that worked, and repeat it through the second half of today."),
        ContentEntry(id: "maintain-day-18", text: "Tonight will test you with tiredness. Front‑load a satisfying, fiber‑rich meal today while you have judgment."),
    ]

    // MARK: - Maintain (evening)

    private static let maintainEvening: [ContentEntry] = [
        ContentEntry(id: "maintain-01", text: "Strong day. Keep the routine stable and take two quiet minutes tonight to notice what helped."),
        ContentEntry(id: "maintain-02", text: "All goals were met. Maintain consistency; a short breathing practice before bed can reinforce the routine."),
        ContentEntry(id: "maintain-03", text: "You matched today’s targets—repeat the same meal timing patterns tomorrow if they felt sustainable."),
        ContentEntry(id: "maintain-04", text: "Great alignment across sleep, fiber, and movement. Protect tomorrow’s schedule from unnecessary late commitments."),
        ContentEntry(id: "maintain-05", text: "Today’s balance supports recovery—keep hydration steady and avoid skipping meals when busy."),
        ContentEntry(id: "maintain-06", text: "Nice work. Choose one small ritual tomorrow that preserves morning light exposure."),
        ContentEntry(id: "maintain-07", text: "Consistency beats spikes—keep tonight’s wind‑down similar to last night’s successful pattern."),
        ContentEntry(id: "maintain-08", text: "You hit the marks—note one environmental cue that made movement easier and reuse it tomorrow."),
        ContentEntry(id: "maintain-09", text: "Stable habits compound—take 60 seconds to appreciate steady progress without pushing harder tonight."),
        ContentEntry(id: "maintain-10", text: "Meeting goals matters—prioritize the same grocery staples this week so fiber stays effortless."),
        ContentEntry(id: "maintain-11", text: "Hold the line tomorrow: keep bedtime within 30 minutes of tonight’s successful timing."),
        ContentEntry(id: "maintain-12", text: "Mindful moment: observe sensations of calm energy—this state is information, not luck."),
        ContentEntry(id: "maintain-13", text: "You’re in maintenance mode—protect walking minutes on a busy day by scheduling them early."),
        ContentEntry(id: "maintain-14", text: "Reinforce success by prepping beans or grains once for the next two days."),
        ContentEntry(id: "maintain-15", text: "Keep screens bounded after dinner—the habit stack that worked today is worth repeating."),
        ContentEntry(id: "maintain-16", text: "Gentle suggestion: pair tonight’s relaxation with gratitude for one supportive person."),
        ContentEntry(id: "maintain-17", text: "Momentum is quiet—avoid ‘reward’ choices that undo sleep timing tonight."),
        ContentEntry(id: "maintain-18", text: "Stay curious: which habit felt easiest today—double down on that simplicity tomorrow."),
        ContentEntry(id: "maintain-19", text: "Pause once today was complete—notice patience available after adequate sleep."),
        ContentEntry(id: "maintain-20", text: "Consistency supports mood regulation—tomorrow, keep protein‑rich plants steady across meals."),
    ]
}
