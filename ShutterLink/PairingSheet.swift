import CoreImage.CIFilterBuiltins
import SwiftUI

struct PairingSheet: View {
    let url: URL
    let code: String
    @ObservedObject var remote: RemotePeripheral
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    Text("Scan with another iPhone")
                        .font(.title2.bold())

                    if let image = qrImage {
                        Image(uiImage: image)
                            .interpolation(.none)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 260)
                            .padding(16)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
                    }

                    VStack(spacing: 4) {
                        Text("Pairing code")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(code)
                            .font(.system(size: 44, weight: .bold, design: .monospaced))
                            .tracking(8)
                    }

                    Text("Point the other iPhone's Camera at the QR code. The ShutterLink Remote App Clip opens without installing anything. Keep this app open while shooting.")
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)

                    Label(statusText, systemImage: remote.connectedRemotes > 0
                          ? "checkmark.circle.fill" : "dot.radiowaves.left.and.right")
                        .foregroundStyle(remote.connectedRemotes > 0 ? Color.green : Color.secondary)
                        .font(.headline)

                    if let image = qrImage {
                        ShareLink(item: Image(uiImage: image),
                                  subject: Text("ShutterLink Remote"),
                                  message: Text("Scan to control the camera: \(url.absoluteString)"),
                                  preview: SharePreview(Text("ShutterLink Remote"), image: Image(uiImage: image))) {
                            Label("Share QR code", systemImage: "square.and.arrow.up")
                                .font(.body)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(24)
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }

    private var qrImage: UIImage? {
        QRCode.image(for: url.absoluteString)
    }

    private var statusText: String {
        remote.connectedRemotes > 0
            ? String(localized: "\(remote.connectedRemotes) remote connected")
            : remote.bluetoothState
    }
}

enum QRCode {
    static func image(for string: String) -> UIImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 10, y: 10)),
              let cgImage = CIContext().createCGImage(output, from: output.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
