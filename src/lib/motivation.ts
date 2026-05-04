import { loadUsedMotivationIds, STORAGE_KEYS } from "./storage";

export type MotivationEntry = { id: string; text: string };

const PARAGRAPHS: MotivationEntry[] = [
  {
    id: "mot-01",
    text: "Hoping a health problem fades on its own is not a plan. You are the one who can choose the next meal, the next walk, the next bedtime—and those choices are how problems actually start to change.",
  },
  {
    id: "mot-02",
    text: "No one else can care about your body for you. If you do not take ownership of sleep, food, and movement, the cost shows up in your energy and in how you show up for the people you love.",
  },
  {
    id: "mot-03",
    text: "Wishful thinking does not lower risk or build stamina. What moves the needle is steady action: small decisions you repeat until they become the foundation you and your relationships can rely on.",
  },
  {
    id: "mot-04",
    text: "Your health is not a lottery ticket. It reflects what you are willing to prioritize and protect. Choosing to invest in yourself is choosing to be more present and less drained for others.",
  },
  {
    id: "mot-05",
    text: "Problems that matter rarely vanish because we ignore them. They improve when we face them with honest effort—when you decide that your well-being and your relationships are worth the discomfort of change.",
  },
  {
    id: "mot-06",
    text: "Blame and regret do not build a better week. Responsibility does: owning what you can control today, even when yesterday was hard, and making one clear move toward health instead of waiting for a perfect moment.",
  },
  {
    id: "mot-07",
    text: "You cannot outsource self-respect. Caring for your health is how you signal—to yourself and to people close to you—that you intend to be here, capable, and engaged for the long run.",
  },
  {
    id: "mot-08",
    text: "Hope without action is thin. When you pair hope with real changes—earlier sleep, more plants, consistent movement—you give yourself and your relationships something solid to build on.",
  },
  {
    id: "mot-09",
    text: "Avoiding the issue does not protect your family or friends; it often makes you less patient and less available. Taking responsibility for your health is a practical way to show up with more steadiness and care.",
  },
  {
    id: "mot-10",
    text: "The path forward is not magic. It is a series of choices that say: I will not passively accept decline. I will do what I can, starting now, because my life and my connections matter enough to try.",
  },
  {
    id: "mot-11",
    text: "You do not need permission to prioritize basics. Sleep, nutrition, and exercise are not selfish hobbies—they are how you keep promises to yourself and have bandwidth for people who depend on you.",
  },
  {
    id: "mot-12",
    text: "If you want different outcomes, something has to change—and that something includes your habits, not only your hopes. Personal responsibility means choosing the harder right option more often than the easy drift.",
  },
  {
    id: "mot-13",
    text: "Relationships thrive when people are regulated enough to listen and repair. That regulation is partly biological: when you steward your health, you give yourself a fairer chance to be the partner, parent, or friend you want to be.",
  },
  {
    id: "mot-14",
    text: "Passivity is still a choice. Deciding to take one concrete step—book the walk, cook the simple meal, set a firm lights-out time—is how you break the trance of “maybe it will get better on its own.”",
  },
  {
    id: "mot-15",
    text: "You are allowed to start small, but not to pretend you have no role. Every day you either reinforce old patterns or practice new ones. Own the direction you are rehearsing.",
  },
  {
    id: "mot-16",
    text: "Resentment often grows when we feel powerless. Reclaiming agency over your health—even imperfectly—can soften that edge and free attention for connection instead of survival mode.",
  },
  {
    id: "mot-17",
    text: "Denial buys short-term comfort and long-term cost. Facing where you are and choosing the next right step is an act of courage—and a form of love for your future self and the people who share your life.",
  },
  {
    id: "mot-18",
    text: "Sustainable improvement is not about shame; it is about stewardship. You are responsible for tending the one body you have and for not expecting others to carry what only you can change.",
  },
  {
    id: "mot-19",
    text: "When you treat your health as negotiable, everything downstream becomes harder—work, mood, intimacy, patience. When you treat it as non-negotiable enough to act on, you create room for real repair and growth.",
  },
  {
    id: "mot-20",
    text: "The story that “it should be easier” keeps people stuck. What sets you free is deciding that your well-being and your relationships are worth the effort—then proving it with repeated choices, not just good intentions.",
  },
];

function saveUsed(ids: string[]) {
  localStorage.setItem(STORAGE_KEYS.usedMotivationParagraphs, JSON.stringify(ids));
}

export function getNextMotivationParagraph(): string {
  let used = [...loadUsedMotivationIds()];
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
