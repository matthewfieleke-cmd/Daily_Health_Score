import Foundation

enum SuggestionLibrary {
    static func pool(for focus: PrimaryFocus) -> [ContentEntry] {
        switch focus {
        case .sleep: return sleep
        case .fiber: return fiber
        case .exercise: return exercise
        case .maintain: return maintain
        }
    }

    private static let sleep: [ContentEntry] = [
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

    private static let fiber: [ContentEntry] = [
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

    private static let exercise: [ContentEntry] = [
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

    private static let maintain: [ContentEntry] = [
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
