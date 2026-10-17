import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var showGuide = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle(isOn: $settings.voiceCountdown) {
                        Label("Voice countdown", systemImage: "speaker.wave.2.fill")
                    }
                    Toggle(isOn: $settings.flashCountdown) {
                        Label("Flash light countdown", systemImage: "flashlight.on.fill")
                    }
                } header: {
                    Text("Countdown")
                } footer: {
                    Text("The camera counts down out loud and blinks its light, so a group standing far away knows exactly when the photo is taken.")
                        .font(.body)
                }

                Section("Viewfinder") {
                    Toggle(isOn: $settings.showLevel) {
                        Label("Level", systemImage: "level.fill")
                    }
                    Toggle(isOn: $settings.showFaceCount) {
                        Label("People counter", systemImage: "person.2.fill")
                    }
                }

                Section {
                    Toggle(isOn: $settings.saveToPhotos) {
                        Label("Save to Photos", systemImage: "photo.on.rectangle")
                    }
                    Toggle(isOn: $settings.sendPhotosToRemote) {
                        Label("Send photos to the remote", systemImage: "iphone.and.arrow.forward")
                    }
                } header: {
                    Text("Photos")
                } footer: {
                    Text("Every shot is also kept in the ShutterLink gallery. When sending is on, the person holding the remote gets a copy of each photo they take.")
                        .font(.body)
                }

                Section("Help") {
                    Button {
                        showGuide = true
                    } label: {
                        Label("How to use ShutterLink", systemImage: "questionmark.circle")
                    }
                    LabeledContent("Version", value: Bundle.main.appVersion)
                }
            }
            .font(.body)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .fullScreenCover(isPresented: $showGuide) {
                OnboardingView { showGuide = false }
            }
        }
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
