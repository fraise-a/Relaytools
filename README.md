**Relaytools** is a native macOS sales training workspace with three playable tools: **Pitch it!** for AI customer roleplay, **A-maze-ing!** for first-person 3D objection handling, and **QuickPic!** for fast sales-communication judgement. Employees practise listening, product knowledge, honest persuasion and customer care, then use feedback, XP and saved results to track their progress.

Built for a sales and go-to-market buildathon, Relaytools combines a shared employee profile, dashboard, progression and leaderboards with three distinct ways to practise. It is a local training application, with clearly labelled fictional team data for demonstrations.

## The Three Tools

| Tool | What You Practise | How It Works |
| --- | --- | --- |
| **Pitch it!** | Discovery, listening, objection handling and moving a conversation forward | Give a product brief, meet a named customer, reply in your own words and receive a scored debrief. |
| **A-maze-ing!** | Product knowledge and persuasive, accurate answers under pressure | Navigate a real 3D maze and convince three AI customers to open the route to the exit. |
| **QuickPic!** | Recognising excellent, acceptable and poor sales communication | Judge messaging-style conversations against stated product facts during a two-minute round. |

All three contribute completed results to the same local XP total. Pitch it! and A-maze-ing! also contribute customer wins. QuickPic! measures judgement rather than customer conversions.

## Build and Run

Run these commands from the Relaytools project directory.

Requirements:

- macOS 14 or newer to run the application.
- A Swift 6 toolchain and a macOS SDK that includes Foundation Models to compile the project.
- For genuine AI roleplay and maze evaluation: macOS 26 or newer on a compatible Mac, with Apple Intelligence available and its model downloaded.

```sh
./script/build_and_run.sh --verify
```

The script builds the SwiftPM executable, generates the macOS icon, assembles and locally signs `dist/Relaytools.app`, registers the bundle, launches it and verifies that its process is running. The project also includes a Codex Run action.

QuickPic! uses authored scenarios and needs neither AI nor an internet connection. Pitch it! has an explicitly labelled **Demo simulation** mode for scripted rehearsal when on-device AI is unavailable. A-maze-ing! requires the real on-device model.

The generated app is a locally signed development build. Distribution signing and notarisation are not configured.

## A Short Demo Route

1. Start on **Dashboard** to introduce the three-tool practice journey: **Practise Conversations** with Pitch it!, **Handle Objections** with A-maze-ing!, and **Sharpen Judgement** with QuickPic!. Each card opens its tool directly. Then point out the shared employee profile, customer wins and XP.
2. Open **Pitch it!**, select a sample brief and meet a customer. Send a reply, point out the live signals, then finish to show the debrief.
3. Open **A-maze-ing!**, choose a product brief and difficulty, and select **Build My Maze**. Enter the maze and approach a customer to demonstrate the free-text challenge and guarded passage.
4. Open **QuickPic!**, select a difficulty and press **Start Game**. Judge conversations until the two-minute round ends, then open **Review Your Mistakes**.
5. Return to the dashboard or leaderboard to show how completed activities update the employee's progress.

Check AI availability before demonstrating Pitch it! in AI mode or A-maze-ing!. QuickPic! and Pitch it!'s scripted demo mode can be demonstrated without the model.

## Pitch it!

Pitch it! is a customer conversation rehearsal. It uses the product information you supply, a named customer persona and live training signals for conviction, comfort and purchase readiness.

### Start a Conversation

1. Select a fictional sample brief or write your own. Include the product, price, benefits, limitations, intended customer and an appropriate next step.
2. Leave customer traits on **Surprise Me**, or pin budget, personality, buying experience and priority in the sidebar.
3. Select **On-device AI** for generative roleplay, or **Demo simulation** for explicitly scripted rehearsal.
4. Select **Meet Your Customer**. A brief is added to Recents only after a session starts successfully.
5. Type a reply, or use the microphone to dictate and review the text before sending. Send with the button or **⌘ Return**.
6. Read the customer's response or listen to it aloud. The speaker control and Settings let you switch spoken replies off.
7. Finish manually, or continue until the customer agrees to a next step or walks away.

Recently used briefs are saved for reuse. Completed sessions retain their transcript, outcome, signals, feedback and XP in **Practice History**.

The signals are coaching estimates, not measurements of a real person's feelings. A high signal alone does not count as convincing a customer; the conversation must reach an agreed outcome.

### Scoring and Feedback

The overall signal score weights conviction at 35%, comfort at 25% and purchase readiness at 40%.

| Outcome | XP |
| --- | --- |
| Customer convinced | 100 + overall score |
| Customer lost | −60 |
| Other completed session with a score below 35 | −30 |
| Other completed session with a score from 35 to below 50 | −10 |
| Other completed session with a score of 50 or above | 20 + half the score |
| No completed salesperson/customer exchange | 0 |

The debrief highlights demonstrated strengths and a practical improvement. Empty sessions receive neutral feedback rather than praise inferred from the customer's opening message. Each completed session can award XP only once.

## A-maze-ing!

A-maze-ing! is a native first-person 3D maze rendered with SceneKit and Metal. Each generated route contains walls, corridors, floor beacons, a starting point, an illuminated exit and three named customers guarding mandatory passages.

### Prepare and Play

Enter product facts or select a fictional sample, choose a difficulty, then select **Build My Maze**. Difficulty changes customer personalities, objection complexity and the XP at stake.

| Difficulty | Customer Style | Maximum Reward Budget | Target Time |
| --- | --- | --- | --- |
| **Follow the Leader** · Easy | Friendly buyers with straightforward questions | 400 XP | 4 minutes |
| **Merely Convincible** · Medium | Cautious buyers who need reassurance | 600 XP | 5 minutes |
| **Uncomfortably Needy** · Hard | Sceptical, impatient or price-conscious buyers | 900 XP | 6 minutes |
| **Who's the Customer?** · Expert | Demanding buyers who challenge evidence and differentiation | 1,200 XP | 7 minutes |

These are the difficulty names currently shown in the application.

- Select **Enter the Maze** to capture the pointer.
- Use **W A S D** to move and the **mouse** to look. Arrow keys provide an alternative for looking.
- Follow the teal beacons. Approaching a customer opens an encounter; **E** interacts with a nearby customer.
- Read the objection and enter a free-text response. Submit with **Make Your Case** or **⌘ Return**.
- Use **Escape** to release the pointer and access the overlay. Product facts remain available during encounters.
- Use **Quit Game** or **⌘.** to leave mid-run. Confirming abandons the run without banking its estimated XP.

### Customer Gates and Evaluation

The AI assesses relevance, persuasion, factual accuracy, clarity, professionalism and understanding of the customer's needs. The application calculates the score and enforces the gate decision.

A response must score **at least 70/100** and contain no serious factual inaccuracies or misleading claims to pass. A failed response never opens the passage. The customer explains what was lacking, remains in place and starts a **five-second cooldown**, after which the player can request a new question or approach again.

Passed customers react and move aside. All three must be convinced before the exit completes the run. AI service failures keep the gate closed and allow retry without counting as a failed attempt. There is no keyword-based or scripted grading fallback.

### Timing, Rewards and Results

The stopwatch starts on the first successful movement and stops at the exit. Thinking time, AI evaluation and time spent with controls released remain part of the run.

XP is labelled as an **unbanked estimate** during play:

- Communication determines approximately **80%** of the reward budget, using answer quality and first-attempt success.
- Pace determines **20%**. Reaching the target time earns the full pace bonus. At twice the target it is zero; at three times the target it becomes an equivalent deduction.
- Each unsuccessful attempt deducts another **3.5%** of the difficulty's reward budget.
- Speed and estimated XP never override the response pass criteria.
- XP is recorded once, only after reaching the exit. Abandoning the run awards nothing.

The results screen shows completion time, customers convinced, attempts, first-attempt success rate, communication score, XP breakdown, strongest responses, improvement areas and coaching. A mini timeboard compares the employee's actual best completed time with clearly labelled fictional colleague benchmarks. Recent completed runs can be reopened from the maze page.

## QuickPic!

QuickPic! is a fast, two-minute game about evaluating the salesperson's actual response. Each card displays product facts, a left-aligned customer message and a right-aligned salesperson reply.

### Choose a Difficulty

| Difficulty | Scenario Style | Base XP per Exact Answer |
| --- | --- | --- |
| **Terribly Laughable (Easy)** | Straightforward concerns and recognisable communication mistakes | 50 |
| **Surprisingly Tough (Medium)** | Nuanced replies that distinguish acceptable from exceptional | 100 |
| **Downright Nasty (Hard)** | Subtle unsupported claims, competing priorities and difficult objections | 150 |

Select a difficulty and press **Start Game**. The countdown starts immediately at **02:00**.

Judge each response using the buttons or keys **1**, **2** and **3**, in this order:

1. **Requires Improvement**: inadequate, misleading, dismissive or fails to address the concern.
2. **Okay**: relevant, respectful and acceptable, with room to be more effective.
3. **Perfect**: accurate, professional and exceptionally responsive to the customer's needs.

Each scenario has a predetermined rating, explanation and improvement example. There are **180 authored cards**, with 60 per difficulty and 20 for each rating within each difficulty. Topics include pricing, empathy, customer needs, negotiation, uncertainty and honest claims. Cards shuffle without repeating within the difficulty pool until every card has been used.

### Countdown, XP and Combos

The timer runs continuously through questions, feedback and navigation away from the game. It never resets between cards. A warning appears in the final 15 seconds.

| Judgement | XP | Combo |
| --- | --- | --- |
| Exactly correct | Base XP × the consecutive-correct multiplier | Increases up to 10× |
| Adjacent category | 25% of base XP, without a multiplier | Resets to 1× |
| Opposite category | Deducts 25% of base XP | Resets to 1× |

The categories are ordered **Requires Improvement → Okay → Perfect**. Choosing either end when the other is correct is an opposite-category error.

The first exact answer earns 1×, the second consecutive exact answer earns 2×, and so on to a maximum of 10×. Further correct answers retain 10× until a mistake breaks the streak. Fractional rewards such as 12.5 and 37.5 XP are preserved exactly.

An answer is recorded immediately and cannot be submitted twice. Feedback and an animated XP change appear for 0.8 seconds before the next card loads automatically. At **00:00**, answers lock and results appear. An unanswered card is discarded without penalty.

Use **Quit Game** or **⌘.** to leave early. Confirming discards the unfinished score without changing profile XP.

### Results and Review

Completed rounds show:

- **Total XP Earned**, **Difficulty Played** and **Questions Answered**.
- **Correct Answers**, **Partially Correct Answers** and **Incorrect Answers** separately.
- **Accuracy Percentage**, calculated as exactly correct answers divided by all answered questions.
- **Highest Combo**, **Average Response Time** and a difficulty-specific **Personal Best**.
- A performance assessment and coaching grounded in the topics and mistakes from the actual round.
- A mini leaderboard with fictional colleagues and the employee's real personal best.

**Review Your Mistakes** lets the player move through every partial or incorrect judgement without leaving the results screen. Each review includes the original conversation, chosen rating, correct rating, explanation and an improved response. When the original reply was already excellent, the review explains its strengths instead of inventing unnecessary changes.

Use **Play Again**, **Change Difficulty** or **Return to Dashboard** to continue. Personal bests are stored separately for each difficulty and survive relaunch. Saved rounds can be reopened from **Recent QuickPic! Games** without awarding their XP again.

Keyboard shortcuts, labelled messages, reduced-motion support, combo animations and adaptive layouts are included.

## Shared Workspace and Progression

- **Dashboard** explains the three-tool practice journey with cards for **Pitch it!**, **A-maze-ing!** and **QuickPic!**. Each card describes the skill, experience and feedback, and opens that tool directly. Players can choose any tool; the numbering does not lock them into a sequence.
- Shared dashboard metrics show all-time customer wins, wins in the last 30 days, rolling 30-day XP, a 14-day activity chart and recent Pitch it! practice.
- **Leaderboard** ranks rolling 30-day XP, including the employee's completed results from all three tools.
- **Practice History** contains Pitch it! sessions. Maze and QuickPic! results are reopened from their respective tool pages.
- The employee's name and level appear in the sidebar. The name starts from the Mac's local profile and is editable in Settings.
- Levels use accumulated XP in 1,000-XP steps. Reward deductions and fractional QuickPic! XP carry through to shared totals.
- Appearance can follow the system or use the available light and dark options.

The dashboard starts with fictional practice activity and the colleague standings are demo data. The app labels these sample figures. Completed local activity is added to the workspace; no real colleagues are connected.

Customer-win totals include won Pitch it! conversations and successfully convinced maze customers from completed runs. QuickPic! contributes XP but does not invent customer wins. Rolling metrics use result timestamps and include deductions.

## AI, Voice and Product Facts

Pitch it!'s generative roleplay and A-maze-ing!'s customer generation and evaluation use Apple's Foundation Models on the Mac. Availability is checked before use and no API key is required. AI response failures offer retry rather than silently switching to scripted customer grading.

QuickPic!'s cards, ratings and coaching are local and deterministic. Its feedback is based on the player's answers, rather than generated compliments. Pitch it!'s **Demo simulation** is a separate, visibly labelled scripted mode.

Product briefs should clearly state what can and cannot be claimed. Briefs are limited to 4,000 characters and free-text replies to 2,500. AI coaching is advisory; generated responses and assessments can be imperfect. Recent context is supplied to the customer, while very long session reviews use selected opening and closing excerpts.

Spoken customer replies use macOS speech synthesis. Dictation uses Apple's Speech framework and may use Apple's servers. Speech and microphone permissions are requested only when dictation is used. Permission denial or unavailable speech input leaves typed replies available.

## Local Data and Persistence

Relaytools uses a **local employee profile**, not a remote account or team login. There is no backend, team synchronisation or live multiplayer leaderboard.

Training data is written atomically to:

```text
~/Library/Application Support/Relaytools/training.json
```

The file stores the profile name, recent briefs, Pitch it! transcripts and feedback, completed maze runs and completed QuickPic! rounds. Appearance and voice preferences use local application settings.

Stable result IDs prevent duplicate XP when recording, retrying a save or reopening old results. Earlier workspace files without the newer game records remain readable. Storage errors are shown in the workspace; an unreadable existing file is preserved rather than overwritten.

This build is a native macOS application. It is not an iOS, Android or browser release.

## Verification

Run the regular test suite with compiler warnings treated as errors:

```sh
swift test -Xswiftc -warnings-as-errors
```

The regular suite covers scoring, penalties, empty sessions, prompt reuse, persona settings, navigation-related lifecycle behaviour, save failures and retries, duplicate protection, rolling metrics and compatibility with older saved data.

Game-specific checks include:

- **A-maze-ing!**: generated routes and mandatory gates, collision, score thresholds and factual vetoes, cooldowns, complete routes, exit-only XP, reward weighting and cancellation while AI is pending.
- **QuickPic!**: all rating combinations and difficulties, fractional XP, every combo step through the 10× cap, combo breaks, continuous deadlines, stale or duplicate clicks, unanswered expiry, accuracy, review data, replay, quitting and per-difficulty personal bests.
- **Pitch it! and voice**: transcript context, honest empty-session feedback, failed replies, permission denial and cancellation during speech setup.

Real-model checks are opt-in and require available Apple Intelligence:

```sh
RELAYTOOLS_AI_SMOKE=1 RELAYTOOLS_MAZE_AI_SMOKE=1 swift test -Xswiftc -warnings-as-errors
```

To check an optimised build:

```sh
swift build -c release -Xswiftc -warnings-as-errors
```

Automated speech checks do not replace testing with a physical microphone. For a demo, also check spoken replies, actual dictation, maze pointer capture and release, mid-game quitting and the full QuickPic! countdown on the presentation Mac.

## Project Structure

Paths below are relative to the project root:

- `Package.swift`: SwiftPM executable and test targets.
- `Sources/Relaytools/App/`: application entry point, lifecycle and shared state ownership.
- `Sources/Relaytools/Views/`: dashboard, the adaptive three-tool journey in `DashboardJourneyView.swift`, Pitch it! screens, history, leaderboard, settings and shared interface components.
- `Sources/Relaytools/Stores/`: persistent workspace and Pitch it! session lifecycle.
- `Sources/Relaytools/Services/`: customer AI, transcript context, session review, scripted demo simulation and voice.
- `Sources/Relaytools/Models/`: shared personas, messages, results, navigation and scoring.
- `Sources/Relaytools/Maze/`: 3D scene, maze generation, AI encounters, lifecycle, rewards and results.
- `Sources/Relaytools/QuickPic/`: authored scenario bank, scoring, deck, game lifecycle, feedback, results and mistake review.
- `Sources/Relaytools/Support/`: branding, sample product briefs and fictional demo fixtures.
- `Tests/RelaytoolsTests/`: shared regression tests and tool-specific checks.
- `Assets/`: app icon source representations.
- `script/`: build, local packaging and icon generation.
- `dist/Relaytools.app`: generated runnable app bundle.
