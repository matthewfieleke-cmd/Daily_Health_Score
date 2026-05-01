import { loadUsedDiscouragementIds, STORAGE_KEYS } from "./storage";

export type DiscouragementEntry = { id: string; text: string };

const PARAGRAPHS: DiscouragementEntry[] = [
  {
    id: "disc-01",
    text: "Sleep, movement, and whole-food nutrition quietly shape energy, attention, and emotional steadiness. These are not vanity metrics—they are the steady inputs that change how you meet stress and how present you feel with people you care about.",
  },
  {
    id: "disc-02",
    text: "Metabolic resilience and mood regulation emerge from repeated small choices, not sudden perfection. When you protect basics like sleep and walking, you are investing in steadier glucose rhythms and clearer thinking tomorrow.",
  },
  {
    id: "disc-03",
    text: "Whole-food plant-forward meals support microbiome diversity and fiber-linked benefits without needing rigid ideology. Practical consistency helps digestion, satiety, and long-run cardiovascular risk reduction over years.",
  },
  {
    id: "disc-04",
    text: "Physical activity—even brisk walking—supports brain-derived signals linked to mood and cognition. You do not need an optimal gym plan; you need repeatable minutes that fit real life.",
  },
  {
    id: "disc-05",
    text: "Sleep debt stacks faster than it feels. Protecting wind-down is partly about protecting how kindly you respond when someone needs you—patience is biological, not purely moral.",
  },
  {
    id: "disc-06",
    text: "Stress systems calm when the body receives predictable cues: daylight, movement, meals, and sleep regularity. Mindfulness supports this by reducing rumination loops that steal sleep and appetite signals.",
  },
  {
    id: "disc-07",
    text: "Social connection is a health behavior. When you stabilize your own routines, you often have more bandwidth for listening, showing up, and repairing misunderstandings without burning out.",
  },
  {
    id: "disc-08",
    text: "Self-compassion is not self-indulgence. Accurate kindness reduces shame cycles that derail sleep and eating patterns—especially after hard weeks.",
  },
  {
    id: "disc-09",
    text: "Consistency beats peaks. Two moderate weeks outperform one heroic day because physiology learns from repetition—circadian timing, gut microbes, and habits all reward steadiness.",
  },
  {
    id: "disc-10",
    text: "Caring for yourself expands your capacity to care for others sustainably. Burnout often arrives when basics erode quietly—protecting sleep is partly protecting your relationships from unnecessary friction.",
  },
  {
    id: "disc-11",
    text: "Evidence-informed lifestyle medicine emphasizes foods close to nature: legumes, grains in intact forms, vegetables, fruits, nuts, and seeds. Progress can be incremental and still meaningful.",
  },
  {
    id: "disc-12",
    text: "Exercise minutes reduce all-cause mortality risk on average across large populations—not as punishment, but as a reliable lever available without perfection.",
  },
  {
    id: "disc-13",
    text: "Fiber-rich meals blunt post-meal glucose spikes for many people and support satiety—helpful for steady energy when life demands focus.",
  },
  {
    id: "disc-14",
    text: "When routines wobble, repair gently. One restarted walk, one earlier bedtime, one simple plant-forward meal can reopen a pathway without needing dramatic resets.",
  },
  {
    id: "disc-15",
    text: "Hope here is grounded: small sustained shifts change trajectories over months and years. You are allowed to move slowly if you move honestly.",
  },
  {
    id: "disc-16",
    text: "Attention is finite. Adequate sleep and movement improve executive function—the same resource you spend on parenting, partnering, and creative work.",
  },
  {
    id: "disc-17",
    text: "Nutrition quality influences inflammatory tone over time. Choosing minimally processed plants more often is a practical way to support vascular health without chasing extremes.",
  },
  {
    id: "disc-18",
    text: "Breathing practices and brief mindfulness reduce sympathetic drive for some people, especially when practiced consistently—not as a miracle, but as training.",
  },
  {
    id: "disc-19",
    text: "Taking care of yourself is how you stay dependable without resentment. Boundaries around sleep and movement are sometimes the most loving choice you can model.",
  },
  {
    id: "disc-20",
    text: "Your score is a mirror, not a verdict. Use it to steer tomorrow with clarity—and remember that steadiness builds the calm presence people around you often need most.",
  },
];

function saveUsed(ids: string[]) {
  localStorage.setItem(STORAGE_KEYS.usedDiscouragementParagraphs, JSON.stringify(ids));
}

export function getNextDiscouragementParagraph(): string {
  let used = [...loadUsedDiscouragementIds()];
  const pool = PARAGRAPHS;
  let unused = pool.filter((p) => !used.includes(p.id));
  if (unused.length === 0) {
    used = [];
    saveUsed([]);
    unused = pool;
  }
  const choice = unused[0]!;
  saveUsed([...used, choice.id]);
  return choice.text;
}
