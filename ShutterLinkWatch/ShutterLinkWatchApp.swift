//
//  ShutterLinkWatchApp.swift
//  ShutterLinkWatch
//
//  손목이 셔터 리모컨: iPhone 카메라가 보는 장면 + 셔터 한 번. 혼자서도 단체사진에 들어간다.
//  한 화면, 두 동작 — 셔터(두 번 두드리기 · 동작 버튼도 같다), 3초 타이머 켜고 끄기. Digital Crown 은 줌.
//

import SwiftUI
import WatchKit

@main
struct ShutterLinkWatchApp: App {
    var body: some Scene {
        WindowGroup {
            RemoteScreen(link: .shared)
        }
    }
}

struct RemoteScreen: View {
    @ObservedObject var link: WatchLink
    @Environment(\.scenePhase) private var scenePhase

    @State private var crownZoom = 1.0
    @State private var lastCrownTurn = Date.distantPast
    @State private var flash = false

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let live = isLive(at: context.date)
            // 단체사진은 가장자리에 누가 잘리는지가 중요하다 — 장면 전체를 덮지 않고 보여 주고, 단추는 그 아래.
            VStack(spacing: 4) {
                viewfinder(live: live)
                controls(live: live)
            }
            .ignoresSafeArea(edges: .top)
        }
        .focusable()
        .digitalCrownRotation($crownZoom, from: status?.minZoom ?? 1, through: max(status?.maxZoom ?? 1, (status?.minZoom ?? 1) + 0.1),
                              by: 0.1, sensitivity: .low, isContinuous: false, isHapticFeedbackEnabled: true)
        .onChange(of: crownZoom) { _, value in
            guard let status, abs(value - status.zoom) >= 0.05 else { return }
            lastCrownTurn = .now
            link.send(.setZoom(value.rounded2))
        }
        .onChange(of: status?.zoom) { _, zoom in
            if let zoom, Date.now.timeIntervalSince(lastCrownTurn) > 1 { crownZoom = zoom }
        }
        .onChange(of: status?.countdown) { _, count in
            if count != nil { WKInterfaceDevice.current().play(.click) }
        }
        .onChange(of: status?.captureCount) { old, new in
            guard let old, let new, new > old else { return }
            WKInterfaceDevice.current().play(.success)
            flash = true
            withAnimation(.easeOut(duration: 0.35)) { flash = false }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            link.activate()
            #if DEBUG
            if let demo = WatchDemo.status { link.applyDemo(demo); return }
            #endif
            link.setWatching(phase == .active)
        }
    }

    private var status: RemoteStatus? { link.status }

    /// 프레임이 2초 안에 왔으면 지금 장면이다.
    private func isLive(at date: Date) -> Bool {
        guard let frameDate = link.frameDate else { return false }
        return date.timeIntervalSince(frameDate) < 2
    }

    // MARK: 미리보기

    private func viewfinder(live: Bool) -> some View {
        ZStack {
            if live {
                frame
                    .overlay { if flash { Color.white } }
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityHidden(true)
            } else {
                waiting
            }
            if let count = status?.countdown, live {
                Text(verbatim: "\(count)")
                    .font(.system(size: 80, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 6)
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.default, value: count)
            }
        }
        .overlay(alignment: .top) {
            if let status, status.isRecording {
                Label(Format.duration(status.recordingSeconds), systemImage: "record.circle")
                    .font(.footnote.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 8)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var frame: some View {
        #if DEBUG
        if WatchDemo.status != nil {
            DemoScene().aspectRatio(3 / 4, contentMode: .fit)
        } else {
            liveFrame
        }
        #else
        liveFrame
        #endif
    }

    @ViewBuilder
    private var liveFrame: some View {
        if let image = link.frame {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
        }
    }

    private var waiting: some View {
        VStack(spacing: 6) {
            Image(systemName: "iphone.gen3")
                .font(.title2)
                .foregroundStyle(.tint)
            Text("Open ShutterLink on your iPhone")
                .font(.footnote)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }

    private func controls(live: Bool) -> some View {
        HStack(alignment: .center) {
            timerButton
                .frame(maxWidth: .infinity)
            WatchShutterButton(status: status) { link.send(.shutter) }
                .disabled(status == nil || !live)
            zoomChip
                .frame(maxWidth: .infinity)
        }
        .padding(.bottom, 2)
    }

    /// 3초 타이머 켜고 끄기. iPhone 에서 다른 시간을 골라 두었으면 그 시간이 보이고, 누르면 끈다.
    private var timerButton: some View {
        let seconds = status?.timerSeconds ?? 0
        return Button {
            link.send(.setTimer(seconds: seconds == 0 ? 3 : 0))
        } label: {
            VStack(spacing: 0) {
                Image(systemName: seconds == 0 ? "timer" : "timer.circle.fill")
                    .font(.title3)
                if seconds > 0 {
                    Text(Format.timer(seconds)).font(.caption2.weight(.semibold).monospacedDigit())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .padding(.horizontal, 3)
                }
            }
            .foregroundStyle(seconds == 0 ? Color.white : Color.accentColor)
            .frame(width: 42, height: 42)
            .background(Color.white.opacity(0.18), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(status == nil || status?.isBusy == true)
        .accessibilityLabel(String(localized: "Timer"))
        .accessibilityValue(Format.timer(seconds))
    }

    @ViewBuilder
    private var zoomChip: some View {
        if let status, status.maxZoom > status.minZoom {
            Text(Format.zoom(status.zoom))
                .font(.caption2.weight(.semibold).monospacedDigit())
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.18), in: Circle())
                .accessibilityLabel(String(localized: "Zoom"))
                .accessibilityValue(Format.zoom(status.zoom))
        } else {
            Color.clear.frame(width: 36, height: 36)
        }
    }
}

/// 셔터 — 화면 단추, 두 번 두드리기(watchOS 11+)가 같다.
struct WatchShutterButton: View {
    let status: RemoteStatus?
    let action: () -> Void

    private let size: CGFloat = 54

    var body: some View {
        let button = Button(action: action) {
            ZStack {
                Circle().strokeBorder(Color.white, lineWidth: 3)
                RoundedRectangle(cornerRadius: stops ? 5 : size / 2)
                    .fill(status?.mode == .video ? Color.red : Color.white)
                    .frame(width: stops ? size * 0.38 : size - 12, height: stops ? size * 0.38 : size - 12)
                    .opacity(status?.countdown != nil ? 0.5 : 1)
            }
            .frame(width: size, height: size)
            .animation(.easeInOut(duration: 0.2), value: stops)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        if #available(watchOS 11.0, *) {
            button.handGestureShortcut(.primaryAction)
        } else {
            button
        }
    }

    private var stops: Bool { status?.isBusy == true }

    private var title: String {
        if status?.countdown != nil { return String(localized: "Cancel timer") }
        if status?.isRecording == true { return String(localized: "Stop recording") }
        if status?.isIntervalRunning == true { return String(localized: "Stop interval shooting") }
        return status?.mode == .video ? String(localized: "Start recording") : String(localized: "Take photo")
    }
}
