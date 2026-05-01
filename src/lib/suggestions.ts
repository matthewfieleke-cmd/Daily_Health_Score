import type { PrimaryFocus, SuggestionCategory } from "../types/health";
import { loadUsedSuggestions, persistUsedSuggestions } from "./storage";

type SuggestionEntry = { id: string; text: string };

const SLEEP_SUGGESTIONS: SuggestionEntry[] = [
  { id: "sleep-01", text: "Tonight, set a phone charging station outside the bedroom and start wind‑down 45 minutes before lights out." },
  { id: "sleep-02", text: "Tomorrow morning, get 5–10 minutes of outdoor light soon after waking to anchor your clock." },
  { id: "sleep-03", text: "Pick a fixed wake time for the next 3 days; adjust bedtime—not the alarm—to protect sleep pressure." },
  { id: "sleep-04", text: "Cut caffeine after 2:00 PM tomorrow (earlier if you are sensitive) and replace it with water or herbal tea." },
  { id: "sleep-05", text: "Tonight, dim warm lights after dinner and avoid bright overhead lighting in the last hour before bed." },
  { id: "sleep-06", text: "Schedule a 10‑minute ‘shutdown ritual’ tonight: lay out clothes, set tomorrow’s top priority, then stop planning." },
  { id: "sleep-07", text: "Keep the bedroom cooler tonight (many people sleep better near 65–68°F / 18–20°C if comfortable)." },
  { id: "sleep-08", text: "Avoid alcohol within 3 hours of bedtime tonight; even small amounts can fragment sleep." },
  { id: "sleep-09", text: "If you wake at night, resist clock‑watching; breathe slowly and keep lights off unless safety requires them." },
  { id: "sleep-10", text: "Tonight, try a short relaxation sequence: slow exhale‑longer‑than‑inhale for 3 minutes before sleep." },
  { id: "sleep-11", text: "Tomorrow, take a 15‑minute midday movement break instead of extra evening screen time." },
  { id: "sleep-12", text: "Set one consistent ‘lights out’ time for the next week—even if reading time is shorter at first." },
  { id: "sleep-13", text: "Reduce late‑night snacks tonight; if hungry, choose something small and easy to digest." },
  { id: "sleep-14", text: "Tonight, swap late social scrolling for a paper book or calming audio for the final 20 minutes." },
  { id: "sleep-15", text: "Tomorrow evening, finish vigorous exercise at least 3 hours before bed if intense workouts affect your sleep." },
  { id: "sleep-16", text: "Use white noise or steady sound tonight if small noises tend to wake you." },
  { id: "sleep-17", text: "Keep a notepad by the bed tonight—write worries down once, then close the loop until morning." },
  { id: "sleep-18", text: "Align meals so dinner isn’t your heaviest meal within 2 hours of bedtime tonight." },
  { id: "sleep-19", text: "Tomorrow, limit long naps; if needed, cap a nap at 20 minutes and finish before mid‑afternoon." },
  { id: "sleep-20", text: "Tonight, trial blackout curtains or an eye mask if daylight or streetlights enter your room." },
];

const FIBER_SUGGESTIONS: SuggestionEntry[] = [
  { id: "fiber-01", text: "Tomorrow, add ½ cup cooked lentils or black beans to lunch or dinner." },
  { id: "fiber-02", text: "Stir 1–2 tablespoons ground flaxseed into oatmeal or a smoothie tomorrow morning." },
  { id: "fiber-03", text: "Build one meal tomorrow around beans, leafy greens, and an intact whole grain like barley or brown rice." },
  { id: "fiber-04", text: "Tomorrow, choose fruit with edible peel (apple or pear) plus a handful of berries as a snack." },
  { id: "fiber-05", text: "Add chickpeas or kidney beans to a salad or grain bowl tomorrow." },
  { id: "fiber-06", text: "Tomorrow, swap refined grains for oats, quinoa, or intact whole‑wheat pasta in one meal." },
  { id: "fiber-07", text: "Include a vegetable soup with beans and vegetables tomorrow; choose a lower‑salt recipe if canned." },
  { id: "fiber-08", text: "Tomorrow, snack on carrots, peppers, or cucumbers with hummus instead of crackers alone." },
  { id: "fiber-09", text: "Cook split peas or pigeon peas tomorrow as a soup or stew base with vegetables." },
  { id: "fiber-10", text: "Tomorrow, top breakfast with chia seeds or hemp hearts alongside fruit." },
  { id: "fiber-11", text: "Make a bean‑based taco or wrap tomorrow using soft corn tortillas and salsa." },
  { id: "fiber-12", text: "Tomorrow, replace one refined snack with edamame (pods) or roasted chickpeas." },
  { id: "fiber-13", text: "Add shredded cabbage or kale tomorrow to a stir‑fry built around tofu or beans." },
  { id: "fiber-14", text: "Tomorrow, choose a pear or orange plus a small handful of walnuts as an afternoon snack." },
  { id: "fiber-15", text: "Prepare farro or bulgur tomorrow as a side with roasted vegetables." },
  { id: "fiber-16", text: "Tomorrow, blend white beans into a soup for thickness instead of cream." },
  { id: "fiber-17", text: "Pack a banana plus almonds tomorrow for a portable whole‑plant snack." },
  { id: "fiber-18", text: "Tomorrow, try mung beans or adzuki beans in a simple curry with tomatoes and spices." },
  { id: "fiber-19", text: "Add raspberries or blackberries to plain oats tomorrow; skip ultra‑processed cereal toppings." },
  { id: "fiber-20", text: "Tomorrow, build a dinner plate that is half vegetables (mixed colors), one‑quarter intact grains, one‑quarter beans." },
];

const EXERCISE_SUGGESTIONS: SuggestionEntry[] = [
  { id: "exercise-01", text: "Tomorrow, complete two 15‑minute brisk walks—one mid‑morning and one after lunch." },
  { id: "exercise-02", text: "After one meal tomorrow, take a 10‑minute walk before sitting back down." },
  { id: "exercise-03", text: "Block 30 minutes on your calendar tomorrow for walking—protect it like a meeting." },
  { id: "exercise-04", text: "Tomorrow, park farther away or get off transit one stop early to add walking minutes." },
  { id: "exercise-05", text: "Do three 10‑minute walks tomorrow spaced through the day." },
  { id: "exercise-06", text: "Tomorrow morning, start the day with an 8‑minute brisk walk before coffee." },
  { id: "exercise-07", text: "Pair exercise with a habit you already do: walk immediately after brushing teeth tomorrow evening." },
  { id: "exercise-08", text: "Tomorrow, take calls while pacing or standing when possible." },
  { id: "exercise-09", text: "Choose stairs once tomorrow instead of an elevator for a short burst." },
  { id: "exercise-10", text: "Tomorrow, walk with a friend or family member for accountability and connection." },
  { id: "exercise-11", text: "If weather is rough tomorrow, march in place during two TV breaks." },
  { id: "exercise-12", text: "Tomorrow, set a gentle alarm every 90 minutes to stand and walk for 3 minutes." },
  { id: "exercise-13", text: "Finish tomorrow’s exercise minutes with an easy cooldown stretch routine." },
  { id: "exercise-14", text: "Tomorrow, explore a new loop near home to keep walking interesting." },
  { id: "exercise-15", text: "Combine errands tomorrow so at least 20 minutes are on foot." },
  { id: "exercise-16", text: "Tomorrow, try a beginner‑friendly bodyweight circuit at home for 12 minutes, then walk." },
  { id: "exercise-17", text: "Split exercise across chores tomorrow: vigorous cleaning counts—keep intensity brisk." },
  { id: "exercise-18", text: "Tomorrow, walk to a destination you usually drive to if it is safe and realistic." },
  { id: "exercise-19", text: "Use music or a podcast tomorrow only during your walk to create a cue." },
  { id: "exercise-20", text: "If short on time tomorrow, do six 5‑minute brisk walks—equal effort adds up." },
];

const MAINTAIN_SUGGESTIONS: SuggestionEntry[] = [
  { id: "maintain-01", text: "Strong day. Keep the routine stable and take two quiet minutes tonight to notice what helped." },
  { id: "maintain-02", text: "All goals were met. Maintain consistency; a short breathing practice before bed can reinforce the routine." },
  { id: "maintain-03", text: "You matched today’s targets—repeat the same meal timing patterns tomorrow if they felt sustainable." },
  { id: "maintain-04", text: "Great alignment across sleep, fiber, and movement. Protect tomorrow’s schedule from unnecessary late commitments." },
  { id: "maintain-05", text: "Today’s balance supports recovery—keep hydration steady and avoid skipping meals when busy." },
  { id: "maintain-06", text: "Nice work. Choose one small ritual tomorrow that preserves morning light exposure." },
  { id: "maintain-07", text: "Consistency beats spikes—keep tonight’s wind‑down similar to last night’s successful pattern." },
  { id: "maintain-08", text: "You hit the marks—note one environmental cue that made movement easier and reuse it tomorrow." },
  { id: "maintain-09", text: "Stable habits compound—take 60 seconds to appreciate steady progress without pushing harder tonight." },
  { id: "maintain-10", text: "Meeting goals matters—prioritize the same grocery staples this week so fiber stays effortless." },
  { id: "maintain-11", text: "Hold the line tomorrow: keep bedtime within 30 minutes of tonight’s successful timing." },
  { id: "maintain-12", text: "Mindful moment: observe sensations of calm energy—this state is information, not luck." },
  { id: "maintain-13", text: "You’re in maintenance mode—protect walking minutes on a busy day by scheduling them early." },
  { id: "maintain-14", text: "Reinforce success by prepping beans or grains once for the next two days." },
  { id: "maintain-15", text: "Keep screens bounded after dinner—the habit stack that worked today is worth repeating." },
  { id: "maintain-16", text: "Gentle suggestion: pair tonight’s relaxation with gratitude for one supportive person." },
  { id: "maintain-17", text: "Momentum is quiet—avoid ‘reward’ choices that undo sleep timing tonight." },
  { id: "maintain-18", text: "Stay curious: which habit felt easiest today—double down on that simplicity tomorrow." },
  { id: "maintain-19", text: "Pause once today was complete—notice patience available after adequate sleep." },
  { id: "maintain-20", text: "Consistency supports mood regulation—tomorrow, keep protein‑rich plants steady across meals." },
];

const LIBRARIES: Record<SuggestionCategory, SuggestionEntry[]> = {
  sleep: SLEEP_SUGGESTIONS,
  fiber: FIBER_SUGGESTIONS,
  exercise: EXERCISE_SUGGESTIONS,
  maintain: MAINTAIN_SUGGESTIONS,
};

export function getNextSuggestion(primaryFocus: PrimaryFocus): string {
  const cat: SuggestionCategory =
    primaryFocus === "maintain" ? "maintain" : primaryFocus;
  const pool = LIBRARIES[cat];
  let state = loadUsedSuggestions();
  let unused = pool.filter((e) => !state[cat].includes(e.id));
  if (unused.length === 0) {
    state = { ...state, [cat]: [] };
    persistUsedSuggestions(state);
    unused = pool;
  }
  const choice = unused[0]!;
  state = { ...state, [cat]: [...state[cat], choice.id] };
  persistUsedSuggestions(state);
  return choice.text;
}
