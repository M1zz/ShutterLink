import SwiftUI
import PhotosUI

/// Scaled-down live rendering of the real banner artwork.
struct BannerPreview: View {
    let design: BannerDesign

    var body: some View {
        GeometryReader { geo in
            let full = design.aspect.renderSize
            let scale = geo.size.width / full.width
            BannerCanvasView(design: design, size: full)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: geo.size.width, height: full.height * scale, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        }
        .aspectRatio(CGFloat(design.aspect.ratio), contentMode: .fit)
    }
}

struct BannerDesignForm: View {
    @Bindable var design: BannerDesign
    @State private var logoItem: PhotosPickerItem?

    var body: some View {
        Form {
            Section("Theme") {
                BannerThemePicker(design: design)
                    .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
            }

            Section("Text") {
                TextField("Small top line (e.g. 2026 Acme Inc.)", text: $design.title)
                TextField("Main message", text: $design.subtitle)
                TextField("Bottom line: date · place", text: $design.footer)
            }

            Section("Shape") {
                Picker("Aspect Ratio", selection: $design.aspect) {
                    ForEach(BannerAspect.allCases) { Text(verbatim: $0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("Background", selection: $design.background) {
                    ForEach(BannerBackground.allCases) { Text($0.title).tag($0) }
                }
                Picker("Font", selection: $design.fontStyle) {
                    ForEach(BannerFont.allCases) { Text($0.title).tag($0) }
                }
                Picker("Decoration", selection: $design.decoration) {
                    ForEach(BannerDecoration.allCases) { Text($0.title).tag($0) }
                }
            }

            Section("Colors") {
                ColorPicker("Background Color", selection: $design.backgroundColor, supportsOpacity: false)
                ColorPicker("Accent (Border · Stripe)", selection: $design.accentColor, supportsOpacity: false)
                ColorPicker("Top Text", selection: $design.titleColor, supportsOpacity: false)
                ColorPicker("Main Text", selection: $design.subtitleColor, supportsOpacity: false)
                ColorPicker("Bottom Text", selection: $design.footerColor, supportsOpacity: false)
            }

            Section("Logo") {
                PhotosPicker(selection: $logoItem, matching: .images) {
                    Label(design.logoImage == nil ? "Add Logo Image" : "Change Logo", systemImage: "photo")
                }
                if design.logoImage != nil {
                    Button("Remove Logo", role: .destructive) { design.logoImage = nil }
                }
            }

            Section("Material · Size") {
                Picker("Material", selection: $design.material) {
                    ForEach(BannerMaterialStyle.allCases) { Text($0.title).tag($0) }
                }
                Toggle("Show Side Poles", isOn: $design.showPoles)
                if design.material.canFlutter {
                    Toggle("Sway in the breeze", isOn: $design.flutter)
                }
                HStack {
                    Text("Width")
                    Slider(value: $design.widthMeters, in: 1.5...8, step: 0.5)
                    Text(String(format: "%.1fm", design.widthMeters))
                        .monospacedDigit()
                        .frame(width: 48, alignment: .trailing)
                }
                LabeledContent("Height", value: String(format: "%.2fm", design.heightMeters))
            }
        }
        .onChange(of: logoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    design.logoImage = image
                }
            }
        }
    }
}

#Preview {
    BannerDesignForm(design: BannerDesign())
}

/// Horizontal strip of theme cards, each a small live render of the banner in that theme.
private struct BannerThemePicker: View {
    let design: BannerDesign

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(BannerTheme.all) { theme in
                        card(theme).id(theme.id)
                    }
                }
                .padding(.horizontal, 16)
            }
            .onAppear { proxy.scrollTo(design.themeID, anchor: .center) }
        }
    }

    private func card(_ theme: BannerTheme) -> some View {
        let isSelected = design.themeID == theme.id
        return Button {
            withAnimation(.easeInOut(duration: 0.2)) { design.apply(theme) }
        } label: {
            VStack(spacing: 8) {
                BannerPreview(design: design.previewing(theme))
                    .frame(width: 168)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 3)
                    )
                Text(theme.title)
                    .font(.body.weight(isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.primary)
                    .lineLimit(1)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
