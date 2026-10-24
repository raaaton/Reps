import SportCore
import SwiftUI
import UIKit

// Mirrors Kavi's name → provider → editable review navigation. No data is saved before confirmation.
struct SkillGenerationView: View {
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openURL) private var openURL
  @Environment(\.dynamicTypeSize) private var textSize
  @State private var path: [SkillGenerationRoute] = []
  @State private var name = ""
  @State private var provider = SkillAIProvider.chatGPT
  @State private var draft: SkillDefinition?
  @State private var hasOpenedProvider = false
  @State private var opening = false
  @State private var promptCopied = false
  @State private var preparedName = ""
  @State private var error: String?
  @State private var errorTitle = "Unable to Continue"
  @FocusState private var nameFocused: Bool

  var body: some View {
    NavigationStack(path: $path) {
      nameStep
        .navigationDestination(for: SkillGenerationRoute.self) { route in
          switch route {
          case .provider: providerStep
          case .review:
            if let draft {
              SkillEditor(
                original: nil, startingDraft: draft, review: true,
                onBack: { edited in
                  self.draft = edited
                  path.removeLast()
                }, onSaved: { dismiss() })
            }
          }
        }
    }
    .alert(errorTitle, isPresented: Binding(get: { error != nil }, set: { if !$0 { error = nil } }))
    {
      Button("OK", role: .cancel) {}
    } message: {
      Text(error ?? "")
    }
  }

  private var nameStep: some View {
    Form {
      Section("Skill") {
        TextField("Name", text: $name).focused($nameFocused)
          .submitLabel(.continue).onSubmit(advanceFromName)
      }
    }
    .navigationTitle("Create with AI").navigationBarTitleDisplayMode(.inline)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        SkillToolbarButton(title: "Cancel", cancel: true) { dismiss() }
      }
      ToolbarItem(placement: .confirmationAction) {
        SkillToolbarButton(title: "Continue") { advanceFromName() }
          .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
      }
    }
    .task { nameFocused = true }
  }

  private var providerStep: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 6) {
          Text("Choose Your AI App").font(.title2.bold())
          Text("Use the app you already have.").font(.subheadline).foregroundStyle(.secondary)
        }
        VStack(spacing: 10) {
          ForEach(SkillAIProvider.allCases) { item in
            providerRow(item)
          }
        }
        if textSize.isAccessibilitySize { providerPanel }
      }
      .padding(.horizontal, 20).padding(.top, 20).padding(.bottom, 12)
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if !textSize.isAccessibilitySize { providerPanel }
    }
    .navigationTitle("Create with AI").navigationBarTitleDisplayMode(.inline)
    .navigationBarBackButtonHidden(true)
    .toolbar {
      ToolbarItem(placement: .cancellationAction) {
        SkillBackButton { path.removeLast() }.disabled(opening)
      }
    }
    .onAppear {
      if !promptCopied { copyPrompt() }
    }
  }

  private func providerRow(_ item: SkillAIProvider) -> some View {
    Button {
      guard provider != item else { return }
      provider = item
      hasOpenedProvider = false
      copyPrompt()
    } label: {
      HStack(spacing: 14) {
        providerLogo(item)
          .resizable().scaledToFit().foregroundStyle(.primary)
          .frame(width: 22, height: 22)
          .frame(width: 42, height: 42)
          .background(Color(uiColor: .tertiarySystemGroupedBackground), in: .rect(cornerRadius: 13))
          .accessibilityHidden(true)
        Text(item.rawValue).font(.headline).foregroundStyle(.primary)
        Spacer(minLength: 8)
        Image(systemName: provider == item ? "checkmark.circle.fill" : "circle")
          .font(.title3).foregroundStyle(provider == item ? Color.accentColor : .secondary)
          .accessibilityHidden(true)
      }
      .padding(15)
      .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
      .overlay {
        RoundedRectangle(cornerRadius: 18).stroke(
          provider == item ? Color.accentColor : Color(uiColor: .separator),
          lineWidth: provider == item ? 1 : 0.5)
      }
      .contentShape(.rect(cornerRadius: 18))
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(provider == item ? [.isSelected] : [])
    .disabled(opening)
  }

  private func providerLogo(_ item: SkillAIProvider) -> Image {
    // SwiftPM processes loose PNGs, not asset-catalog image sets. Resolve the actual file
    // instead of relying on SwiftUI's named-image catalog lookup on the device.
    if let url = Bundle.module.url(forResource: item.logo, withExtension: "png"),
      let image = UIImage(contentsOfFile: url.path)
    {
      return Image(uiImage: image).renderingMode(.template)
    }
    return Image(systemName: "sparkles")
  }

  private var providerPanel: some View {
    VStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 10) {
        if hasOpenedProvider {
          Text("Back from \(provider.rawValue)?").font(.headline)
          Text("Copy the complete response, then paste it here to review your skill.")
            .font(.subheadline).foregroundStyle(.secondary)
          SkillPrimaryButton(
            title: "Paste from \(provider.rawValue)", systemImage: "doc.on.clipboard.fill"
          ) {
            pasteResult()
          }
          SkillSecondaryButton(
            title: "Open \(provider.rawValue) Again", systemImage: "arrow.up.right.square"
          ) {
            launch(website: false)
          }.disabled(opening)
        } else {
          Label(
            promptCopied ? "Prompt Copied" : "Your Skill Prompt", systemImage: "doc.on.clipboard"
          )
          .font(.headline)
          Text(
            "Open \(provider.rawValue), paste the prompt and send it. When the response is complete, copy it and return to Sport."
          )
          .font(.subheadline).foregroundStyle(.secondary)
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(16)
      .background(Color(uiColor: .secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
      if !hasOpenedProvider {
        SkillPrimaryButton(title: "Open \(provider.rawValue)", systemImage: "arrow.up.right.square")
        {
          launch(website: false)
        }.disabled(opening)
        SkillSecondaryButton(title: "Paste Existing Response", systemImage: "doc.on.clipboard.fill")
        { pasteResult() }
      }
      if draft != nil {
        SkillSecondaryButton(title: "Continue Reviewing", systemImage: "pencil") {
          if !path.contains(.review) { path.append(.review) }
        }
      }
      if opening { ProgressView().accessibilityLabel("Opening \(provider.rawValue)") }
      Menu {
        SkillMenuButton(title: "Copy Prompt", systemImage: "doc.on.doc") { copyPrompt() }
        SkillMenuButton(title: "Open Website", systemImage: "safari") { launch(website: true) }
      } label: {
        Label("Other Options", systemImage: "ellipsis").font(.subheadline)
      }
    }
    .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 8)
    .background(Color(uiColor: .systemGroupedBackground))
  }

  private func advanceFromName() {
    guard path.isEmpty else { return }
    do {
      _ = try SkillGeneration.prompt(name: name)
      nameFocused = false
      let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
      if preparedName != cleanName { draft = nil }
      preparedName = cleanName
      promptCopied = false
      hasOpenedProvider = false
      path.append(.provider)
    } catch { show(error.localizedDescription, title: "Check the Skill Name") }
  }
  private func copyPrompt() {
    do {
      UIPasteboard.general.string = try SkillGeneration.prompt(name: name)
      promptCopied = true
    } catch { show(error.localizedDescription, title: "Unable to Copy Prompt") }
  }
  private func launch(website: Bool) {
    guard !opening else { return }
    do {
      let prompt = try SkillGeneration.prompt(name: name)
      UIPasteboard.general.string = prompt
      promptCopied = true
      opening = true
      // Like Kavi, open at most one URL per explicit action. Clipboard remains the reliable fallback.
      openURL(website ? provider.webURL : provider.nativeURL(prompt: prompt)) { accepted in
        opening = false
        if accepted {
          hasOpenedProvider = true
        } else {
          show(
            "The app could not be opened. Your prompt is copied. Choose Open Website in Other Options, or another AI app.",
            title: "Unable to Open \(provider.rawValue)")
        }
      }
    } catch { show(error.localizedDescription, title: "Unable to Prepare Prompt") }
  }
  private func pasteResult() {
    guard !path.contains(.review) else { return }
    guard let response = UIPasteboard.general.string,
      !response.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      show("Copy the complete AI response first, then tap Paste again.", title: "Nothing to Paste")
      return
    }
    do {
      let parsed = try SkillGeneration.parse(response)
      draft = parsed
      path.append(.review)
    } catch { show(error.localizedDescription, title: "Unable to Read Response") }
  }
  private func show(_ message: String, title: String) {
    errorTitle = title
    error = message
  }
}

private enum SkillGenerationRoute: Hashable { case provider, review }
private enum SkillAIProvider: String, CaseIterable, Identifiable {
  case chatGPT = "ChatGPT"
  case claude = "Claude"
  case gemini = "Gemini"
  var id: Self { self }
  var logo: String { "SkillProvider\(rawValue)" }
  func nativeURL(prompt: String) -> URL {
    if self == .chatGPT {
      var components = URLComponents()
      components.scheme = "chatgpt"
      components.host = "chat.openai.com"
      components.path = "/"
      components.queryItems = [URLQueryItem(name: "q", value: prompt)]
      return components.url!
    }
    return URL(string: self == .claude ? "claude://" : "googlegemini://")!
  }
  var webURL: URL {
    URL(
      string: self == .chatGPT
        ? "https://chatgpt.com/"
        : self == .claude ? "https://claude.ai/" : "https://gemini.google.com/")!
  }
}
