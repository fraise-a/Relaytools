import SwiftUI

struct MazePlayView: View {
    @Environment(MazeStore.self) private var game
    @Environment(TrainingStore.self) private var workspace
    @State private var confirmAbandon = false

    var body: some View {
        @Bindable var game = game
        ZStack {
            MazeSceneView(game: game).id(game.runID)
            VStack {
                LinearGradient(colors: [.black.opacity(0.65), .clear], startPoint: .top, endPoint: .bottom).frame(height: 160)
                Spacer()
                LinearGradient(colors: [.clear, .black.opacity(0.65)], startPoint: .top, endPoint: .bottom).frame(height: 130)
            }.allowsHitTesting(false)
            VStack {
                hud
                Spacer()
                if game.isCaptured {
                    Image(systemName: "plus").font(.system(size: 17, weight: .ultraLight)).foregroundStyle(.white.opacity(0.75)).allowsHitTesting(false)
                }
                Spacer()
                HStack {
                    Label("W A S D  Move", systemImage: "keyboard")
                    Text("·")
                    Text("Mouse / arrows  Look")
                    Text("·")
                    Text("E  Interact")
                    Spacer()
                    Text("Esc  Release mouse · ⌘.  Quit maze")
                }
                .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.7))
                .padding(.horizontal, 24).padding(.bottom, 18)
                .allowsHitTesting(false)
            }
            if game.phase == .finishing {
                Color.black.opacity(0.55)
                VStack(spacing: 17) {
                    ProgressView().tint(.white)
                    Text("Exit reached. Preparing your debrief…").font(.system(size: 17, weight: .medium))
                    Text("The stopwatch has stopped. Your XP is being banked.").font(.system(size: 12)).foregroundStyle(.secondary)
                }.padding(30).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
            } else if game.activeCustomer != nil {
                Color.black.opacity(0.45).allowsHitTesting(false)
                MazeEncounterView().padding(.top, 105).padding(.bottom, 44)
            } else if !game.isCaptured {
                Color.black.opacity(0.25).allowsHitTesting(false)
                welcome
            }
            if game.phase == .playing {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button(action: requestQuit) {
                            Label("Quit maze", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                        .controlSize(.large)
                        .keyboardShortcut(".", modifiers: .command)
                        .help("Quit this unfinished maze (Command–period). Estimated XP will not be banked.")
                    }
                    .padding(.trailing, 24).padding(.bottom, 50)
                }
            }
        }
        .preferredColorScheme(.dark)
        .alert("Quit this maze?", isPresented: $confirmAbandon) {
            Button("Quit maze", role: .destructive) {
                game.abandonRun()
                workspace.destination = .dashboard
            }
            Button("Keep playing", role: .cancel) {}
        } message: { Text("You will return to the dashboard. This unfinished run will be discarded and no XP will be awarded or deducted.") }
        .sheet(isPresented: $game.showProductFacts) {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("Your Product Facts").font(.title2.weight(.semibold))
                    Spacer()
                    Button("Done") { game.showProductFacts = false }
                }
                ScrollView { Text(game.activeBrief).font(.system(size: 14)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
            }.padding(28).frame(width: 650, height: 460)
        }
    }

    private func requestQuit() {
        game.releaseControls()
        confirmAbandon = true
    }

    private var hud: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("A-MAZE-ING!").font(.system(size: 11, weight: .bold)).tracking(2).foregroundStyle(Color(red: 0.3, green: 0.9, blue: 0.77))
                Text(game.objective).font(.system(size: 16, weight: .semibold)).foregroundStyle(.white)
                HStack(spacing: 7) {
                    ForEach(game.customers) { customer in
                        Image(systemName: customer.passed ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(customer.passed ? Brand.accent : .white.opacity(0.4))
                    }
                    Text("\(game.passedCount) / \(game.customers.count) customers · \(game.objectiveDistance)m to objective")
                        .font(.system(size: 10)).foregroundStyle(.white.opacity(0.65))
                }
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Text("STOPWATCH").font(.system(size: 8, weight: .semibold)).tracking(1.3).foregroundStyle(.white.opacity(0.5))
                Text(MazeTime.display(game.elapsed)).font(.system(size: 25, weight: .medium, design: .monospaced)).foregroundStyle(.white)
                Text(game.hasStartedMoving ? "Runs until the exit" : "Starts on your first step").font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
            }.padding(.trailing, 15)
            VStack(alignment: .trailing, spacing: 6) {
                Text("ESTIMATED FINISH XP").font(.system(size: 8, weight: .semibold)).tracking(1.1).foregroundStyle(.white.opacity(0.5))
                Text(String(format: "%+d", game.rewards.total)).font(.system(size: 25, weight: .semibold, design: .rounded))
                    .foregroundStyle(game.rewards.total >= 0 ? Color(red: 0.3, green: 0.9, blue: 0.77) : .orange)
                Text("Unbanked · quality 80% / pace 20%").font(.system(size: 9)).foregroundStyle(.white.opacity(0.5))
            }
        }
        .padding(24)
        .allowsHitTesting(false)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 18) {
            Label(game.hasStartedMoving ? "Back in the maze" : "Think on your feet.", systemImage: "cube.transparent")
                .font(.system(size: 24, weight: .semibold)).tracking(-0.5)
            Text("Follow the teal floor beacons. Three customers guard your route. Earn their trust, then find the glowing exit.")
                .font(.system(size: 13)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 20) {
                Label("W A S D to move", systemImage: "keyboard")
                Label("Mouse to look", systemImage: "cursorarrow")
            }.font(.system(size: 11, weight: .medium))
            Text("Escape releases the mouse. The stopwatch includes thinking time and continues while paused. Arrow keys are an alternative for looking around.")
                .font(.system(size: 10)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            HStack {
                Button(game.hasStartedMoving ? "Resume Exploring" : "Enter the Maze") { game.requestControls() }
                    .buttonStyle(MazePrimaryButtonStyle()).controlSize(.large).keyboardShortcut(.return, modifiers: [])
                Button("Product Facts") { game.showProductFacts = true }.controlSize(.large)
                Spacer()
                Button("Quit maze", action: requestQuit).buttonStyle(.plain).font(.system(size: 10)).foregroundStyle(.secondary)
                Button { game.soundEnabled.toggle() } label: {
                    Image(systemName: game.soundEnabled ? "speaker.wave.2" : "speaker.slash")
                }.help("Encounter sound effects")
            }
        }
        .padding(28).frame(width: 510)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay { RoundedRectangle(cornerRadius: 18).strokeBorder(.white.opacity(0.12), lineWidth: 1) }
    }
}
