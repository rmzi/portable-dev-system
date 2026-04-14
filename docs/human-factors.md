# Human Factors in AI-Assisted Development

*Draft for whitepaper integration. Author integration points marked with `[PERSONAL ANECDOTE]`.*

---

## 1. The Reinforcement Loop

AI coding assistants create a uniquely tight feedback cycle. You type a request, and within seconds, working code appears. Then another request. Then another. The gap between "I want this" and "I have this" collapses to nearly zero.

This speed is intoxicating. Traditional development has natural pauses — waiting for builds, running tests, reading documentation, thinking through edge cases. AI assistants compress or eliminate many of these pauses. What remains is a continuous stream of small rewards: problem stated, problem solved, next problem.

[PERSONAL ANECDOTE: Describe a time when you realized you'd been prompting for hours without a break — what the session felt like, what you were building, and when you finally noticed the time.]

The "one more prompt" pattern is familiar to anyone who has used these tools. The marginal cost of one more request feels trivial. The potential reward — finishing this feature, fixing this bug, cleaning up this file — always feels close. The session extends.

What gets compressed isn't just time. It's the reflection that normally happens between actions. The walk to the coffee machine where you reconsider the approach. The compile-time pause where you notice a simpler path. AI assistants don't just speed up coding — they remove the spaces where second thoughts happen.

## 2. AI Psychosis

*Note: This term is used colloquially, not clinically. We are not psychologists or psychiatrists. Expert contribution is invited and encouraged.*

Something strange happens when you work with an AI assistant for extended periods. The relationship stops feeling like tool-use and starts feeling like collaboration. You begin to anthropomorphize. You thank the AI. You feel frustrated when it misunderstands. You feel satisfied when it "gets it."

This is understandable — the interface is conversational, the responses are contextual, and the AI adapts to your style. But the shift from "I'm using a tool" to "we're working together" has consequences:

**Loss of critical evaluation.** When the AI produces code that looks right, the temptation is to accept it without deep review. "It looks good to me" becomes "the AI probably got it right." The more capable the AI, the more this trust extends into areas where the AI is actually uncertain.

**Dependency patterns.** Developers who lean heavily on AI assistants sometimes report feeling less capable when working without them. The muscle memory of problem decomposition, API lookup, and incremental debugging can atrophy when a single prompt replaces the full process.

[PERSONAL ANECDOTE: Describe a moment when you caught yourself trusting AI output without adequate verification, or when you felt an emotional response to an AI interaction that surprised you.]

**The blurring line.** At what point does "using AI as a tool" become "using AI as a crutch"? This isn't a question we can answer definitively. Different developers, different contexts, different tools all shift the line. But the question is worth asking honestly rather than dismissing.

## 3. Healthy Human-in-the-Loop

Sustainability matters more than throughput. A developer who ships 50% more code per week but burns out in three months has not improved productivity. A methodology that extracts maximum output from the human-AI system without accounting for the human's needs is not a good methodology.

Some observations about sustainable AI-assisted development:

**Breaks are not waste.** The instinct to keep prompting while the AI is "hot" — while context is loaded, while the session is flowing — creates pressure to skip breaks. But the human brain is not a context window. It needs rest, movement, and idle time to consolidate learning and generate novel connections.

**Time-boxed sessions work.** Setting a hard boundary ("I will stop after 90 minutes regardless of where I am") creates healthier patterns than outcome-based boundaries ("I will stop when this feature is done"). Features always have one more edge case.

[PERSONAL ANECDOTE: Describe your experience with session limits — what happened when you started enforcing them, and what you noticed about the quality of work before vs after.]

**The AI can keep going. You should not.** One of the unique properties of AI assistants is their infinite patience. They never get tired, never need a break, never lose focus. This creates an implicit pressure: the bottleneck is you. If you step away, work stops. This framing is seductive and harmful.

**Boredom has value.** The moments when you're not actively prompting — when you're staring at the ceiling, taking a walk, doing nothing — are often when the best architectural insights arrive. Constant stimulation from AI interactions crowds out this kind of thinking.

## 4. PDS's Role as Guardrail

PDS includes several features designed to nudge developers toward sustainable practices. These are not enforcement mechanisms — they can be disabled. They are reminders.

**Session health monitoring.** The `health-check.sh` hook tracks session duration and provides escalating reminders:
- At 30 minutes: "Good time for a stretch."
- At 60 minutes: "You've been at this over an hour. Take a walk."
- At 120 minutes: "Seriously, take a break. Use /pds:pause to save state."

These are deliberately informal, not clinical. They acknowledge that you're an adult who can make your own decisions, while also noting that you might have lost track of time.

**Deliberate session boundaries.** The `/pds:pause` skill saves session state — a WIP commit, context preservation — so that stopping doesn't mean losing work. The friction of "I'll lose my place" is one of the strongest forces keeping developers in sessions too long. Reducing that friction makes breaks easier.

**Spinner tips.** PDS overrides Claude Code's default spinner tips with messages like:
- "Take a walk. Your best ideas come after breaks."
- "Hydration check — when did you last drink water?"
- "Your health matters more than this commit."

These appear during wait times — the moments when the developer is most likely to be passively engaged and receptive to a nudge.

**Shipping as a break point.** The finish protocol explicitly frames shipping as a natural stopping point. After pushing code, PDS suggests `/pds:pause`. The message is: you accomplished something. That's a good time to step away.

**Swarm delegation.** The multi-agent workflow is not just about parallelism — it's about allowing the human to step back. When an orchestrator is running a swarm, the human can disengage while work continues. This isn't lazy — it's sustainable. The human reviews the output later, fresh.

[PERSONAL ANECDOTE: Describe how the break reminders or session limits have affected your actual behavior — have they helped, been annoying, been ignored? Be honest.]

## 5. Invitation to Contribute

This section represents observations from building and using PDS. We are not psychologists, behavioral health researchers, or HCI experts. We are software developers who noticed patterns in our own behavior and wanted to be honest about them.

We believe this topic deserves serious attention from people with relevant expertise:

**Psychology and behavioral health.** What are the actual cognitive effects of extended AI-assisted development sessions? How do reinforcement loops in AI tools compare to those in other digital environments? What intervention strategies have evidence behind them?

**Human-Computer Interaction (HCI).** How should AI coding interfaces be designed to support sustainable use? What affordances encourage healthy patterns? How do conversational interfaces change the developer's relationship with their tools?

**Workplace health and ergonomics.** How should organizations think about AI tool adoption in terms of employee wellbeing? What policies or practices help?

**Neuroscience.** What happens in the brain during extended prompt-response cycles? How does the dopamine system respond to the rapid reward cycles of AI coding?

If you work in any of these areas and have thoughts, research, or criticism, we want to hear from you. This document should be improved by people who know more than we do about the human side of human-computer interaction.

Open an issue, submit a PR, or reach out directly. The code is MIT — the ideas should be open too.
