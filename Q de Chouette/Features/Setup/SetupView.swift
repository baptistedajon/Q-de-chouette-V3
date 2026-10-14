// SetupView.swift
// Écran de configuration d'une nouvelle partie.

import SwiftUI
import SwiftData
import ChouetteRules

struct SetupView: View {
    /// Partie guidée cochée par défaut (première partie, ou depuis les règles).
    var guided = false
    @Environment(AppSettings.self) private var settings
    @Environment(Router.self) private var router
    @Environment(\.modelContext) private var context
    @Query(sort: \PlayerProfile.lastPlayed, order: .reverse) private var profiles: [PlayerProfile]

    @State private var model = SetupViewModel(mode: .simple)
    @State private var didLoadPreferences = false
    @State private var avatarPickerEntry: SetupViewModel.Entry.ID?
    @State private var errorMessage: String?
    @FocusState private var focusedEntry: SetupViewModel.Entry.ID?

    var body: some View {
        form(model)
        .navigationTitle("Nouvelle partie")
        .navigationBarTitleDisplayMode(.inline)
        .themedBackground()
        .onAppear {
            // Reprend le dernier mode choisi, une seule fois (pas à chaque retour des réglages).
            if !didLoadPreferences {
                model.mode = settings.lastMode
                model.isGuided = guided
                didLoadPreferences = true
            }
        }
        .alert("Impossible de commencer", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    @ViewBuilder
    private func form(_ model: SetupViewModel) -> some View {
        @Bindable var model = model
        List {
            Section {
                ForEach($model.entries) { $entry in
                    let index = model.entries.firstIndex(of: entry) ?? 0
                    HStack(spacing: 14) {
                        Button {
                            avatarPickerEntry = entry.id
                        } label: {
                            AvatarView(avatar: entry.avatar, size: 40)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text("Avatar : \(Text(entry.avatar.name))"))
                        .accessibilityHint(Text("Choisir un autre avatar"))

                        TextField(String(localized: "Joueur \(index + 1)"), text: $entry.name)
                            .font(.title3)
                            .textInputAutocapitalization(.words)
                            .autocorrectionDisabled()
                            .submitLabel(.next)
                            .focused($focusedEntry, equals: entry.id)
                            .onSubmit { focusNext(after: entry.id, in: model) }
                    }
                    .listRowBackground(Theme.surface)
                }
                .onDelete { model.remove(at: $0) }
                .onMove { model.move(from: $0, to: $1) }
                .deleteDisabled(!model.canRemovePlayer)

                if model.canAddPlayer {
                    Button {
                        model.addPlayer()
                        focusedEntry = model.entries.last?.id
                    } label: {
                        Label("Ajouter un joueur", systemImage: "person.badge.plus")
                    }
                    .listRowBackground(Theme.surface)
                }
            } header: {
                Text("Joueurs (\(model.entries.count)/8)")
            } footer: {
                if let message = model.validationMessage {
                    Text(message).foregroundStyle(Theme.negative)
                } else {
                    Text("L'ordre de la liste est l'ordre de jeu. Touchez « Modifier » pour réordonner ou supprimer.")
                }
            }

            let recent = profiles.filter { !model.isAlreadyAdded($0.name) }.prefix(12)
            if !recent.isEmpty && model.canAddPlayer {
                Section("Joueurs récents") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(Array(recent)) { profile in
                                Button {
                                    model.addPlayer(name: profile.name, avatar: profile.avatar)
                                } label: {
                                    HStack(spacing: 6) {
                                        AvatarView(avatar: profile.avatar, size: 24)
                                        Text(profile.name).lineLimit(1)
                                    }
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(Theme.background, in: Capsule())
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text("Ajouter \(profile.name)"))
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Theme.surface)
                }
            }

            Section("Dés") {
                ForEach(GameMode.allCases) { mode in
                    Button {
                        model.mode = mode
                    } label: {
                        HStack(spacing: 14) {
                            Image(systemName: mode.systemImage)
                                .font(.title2)
                                .frame(width: 36)
                                .foregroundStyle(Theme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(mode.title).font(.headline)
                                Text(mode.subtitle).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                            }
                            Spacer()
                            if model.mode == mode {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.accent)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(model.mode == mode ? .isSelected : [])
                    .listRowBackground(Theme.surface)
                }
            }

            Section {
                Toggle(isOn: $model.isGuided) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Partie guidée").font(.headline)
                        Text("Chaque lancer est expliqué en direct. Idéal pour une première partie.")
                            .font(.subheadline)
                            .foregroundStyle(Theme.inkSecondary)
                    }
                }
                .listRowBackground(Theme.surface)
            }

            Section("Qui commence ?") {
                Picker("Premier joueur", selection: $model.firstPlayer) {
                    Text("Tirage au sort").tag(SetupViewModel.FirstPlayer.random)
                    ForEach(model.entries.indices, id: \.self) { index in
                        Text(model.resolvedName(at: index)).tag(SetupViewModel.FirstPlayer.entry(model.entries[index].id))
                    }
                }
                .listRowBackground(Theme.surface)
            }

            Section {
                Button {
                    router.push(.settings)
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Règles").font(.headline).foregroundStyle(Theme.ink)
                            Text(rulesSummary).font(.subheadline).foregroundStyle(Theme.inkSecondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(Theme.inkSecondary)
                    }
                }
                .listRowBackground(Theme.surface)
            }
        }
        .frame(maxWidth: 720)
        .frame(maxWidth: .infinity)
        .toolbar { EditButton() }
        .safeAreaInset(edge: .bottom) {
            Button {
                start(model)
            } label: {
                Label("Commencer la partie", systemImage: "flag.checkered")
            }
            .buttonStyle(.primary)
            .disabled(!model.canStart)
            .padding()
            .frame(maxWidth: 720)
            .frame(maxWidth: .infinity)
            .background(.bar)
        }
        .sheet(isPresented: Binding(get: { avatarPickerEntry != nil }, set: { if !$0 { avatarPickerEntry = nil } })) {
            if let id = avatarPickerEntry, let index = model.entries.firstIndex(where: { $0.id == id }) {
                AvatarPicker(selection: $model.entries[index].avatar)
            }
        }
    }

    private var rulesSummary: String {
        let rules = settings.rules
        var parts = [String(localized: "\(rules.targetScore) points")]
        parts.append(rules.usesLightVariants ? String(localized: "variantes allégées") : String(localized: "règles traditionnelles"))
        let advanced = [
            rules.sirotage.isEnabled ? String(localized: "sirotage") : nil,
            rules.bevue.isEnabled ? String(localized: "bévue") : nil,
            rules.civet.isEnabled ? String(localized: "civet") : nil,
            rules.grelottine.isEnabled ? String(localized: "grelottine") : nil,
        ].compactMap { $0 }
        parts.append(advanced.isEmpty ? String(localized: "sans règles avancées") : advanced.joined(separator: ", "))
        return parts.joined(separator: " · ")
    }

    private func focusNext(after id: SetupViewModel.Entry.ID, in model: SetupViewModel) {
        guard let index = model.entries.firstIndex(where: { $0.id == id }) else { return }
        focusedEntry = model.entries.indices.contains(index + 1) ? model.entries[index + 1].id : nil
    }

    private func start(_ model: SetupViewModel) {
        do {
            settings.lastMode = model.mode
            let game = try model.startGame(rules: settings.rules, in: context)
            router.startGame(game)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

/// Grille de choix d'avatar.
struct AvatarPicker: View {
    @Binding var selection: Avatar
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 88))], spacing: 18) {
                    ForEach(Avatar.allCases) { avatar in
                        Button {
                            selection = avatar
                            dismiss()
                        } label: {
                            VStack(spacing: 6) {
                                AvatarView(avatar: avatar, size: 60)
                                Text(avatar.name).font(.footnote).foregroundStyle(Theme.ink)
                            }
                            .padding(8)
                            .background(selection == avatar ? Theme.gold.opacity(0.25) : .clear,
                                        in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Text(avatar.name))
                        .accessibilityAddTraits(selection == avatar ? .isSelected : [])
                    }
                }
                .padding()
            }
            .themedBackground()
            .navigationTitle("Choisir un avatar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Fermer") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    NavigationStack { SetupView() }
        .environment(AppSettings())
        .environment(Router())
        .modelContainer(Persistence.makeContainer(inMemory: true))
}
