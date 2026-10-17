import CoreBluetooth
import UIKit

/// BLE client in the App Clip. Finds the camera advertising "SL-<code>", pairs with the code,
/// subscribes to status and opens the L2CAP preview stream.
final class RemoteCentral: NSObject, ObservableObject {
    enum Phase: Equatable {
        case idle
        case waitingForBluetooth
        case scanning
        case connecting
        case pairing
        case connected
        case failed(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var status: RemoteStatus?
    @Published private(set) var previewImage: UIImage?
    /// Photos the camera sent back after each shot, newest first.
    @Published private(set) var reviews: [ReviewPhoto] = []
    @Published private(set) var code: String?

    private var central: CBCentralManager?
    private var peripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var statusCharacteristic: CBCharacteristic?
    private var psmCharacteristic: CBCharacteristic?
    private var channel: CBL2CAPChannel?
    private var receiver: PreviewStreamReceiver?
    private var isAuthorized = false
    private var scanTimeout: DispatchWorkItem?

    private static let scanTimeoutSeconds: TimeInterval = 20
    private static let maxReviews = 20

    // MARK: Public API (main thread)

    func connect(code newCode: String) {
        guard RemoteConfig.isValidCode(newCode) else {
            phase = .failed(String(localized: "Enter the 4-digit code shown on the camera iPhone."))
            return
        }
        if code == newCode, phase != .idle, !isFailed { return }
        teardown()
        code = newCode

        if let central, central.state == .poweredOn {
            startScan()
        } else {
            phase = .waitingForBluetooth
            if central == nil {
                central = CBCentralManager(delegate: self, queue: .main)
            }
        }
    }

    func retry() {
        guard let code else {
            phase = .idle
            return
        }
        self.code = nil
        connect(code: code)
    }

    /// User-initiated disconnect: forget the code so we don't auto-reconnect.
    func disconnect() {
        code = nil
        teardown()
        phase = .idle
    }

    func send(_ command: RemoteCommand) {
        guard isAuthorized,
              let peripheral,
              let characteristic = commandCharacteristic,
              let data = RemoteWire.encode(command) else { return }
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }

    #if DEBUG
    /// Screenshot mode: shows a connected remote with an illustrated preview.
    @MainActor
    func applyDemo() {
        code = "4821"
        phase = .connected
        var demo = RemoteStatus()
        demo.zoom = 1
        demo.minZoom = 0.5
        demo.maxZoom = 10
        demo.burstCount = 5
        demo.timerSeconds = 10
        demo.autoCapture = .palm
        demo.faces = 5
        demo.tilt = 0
        demo.flashAvailable = true
        status = demo
        previewImage = DemoMode.sceneImage(width: 600)
        reviews = (0 ..< 3).map { index in
            let image = DemoMode.sceneImage(width: 1024, variant: index * 2)
            return ReviewPhoto(image: image, data: image.jpegData(compressionQuality: 0.8) ?? Data())
        }
    }
    #endif

    // MARK: Private

    private var isFailed: Bool {
        if case .failed = phase { return true }
        return false
    }

    private func startScan() {
        guard let central, central.state == .poweredOn, code != nil else { return }
        phase = .scanning
        central.scanForPeripherals(withServices: [RemoteUUID.service],
                                   options: [CBCentralManagerScanOptionAllowDuplicatesKey: true])
        scanTimeout?.cancel()
        let timeout = DispatchWorkItem { [weak self] in
            guard let self, self.phase == .scanning else { return }
            self.central?.stopScan()
            self.phase = .failed(String(localized: "Couldn't find the camera. Make sure ShutterLink is open on the camera iPhone and Bluetooth is on."))
        }
        scanTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.scanTimeoutSeconds, execute: timeout)
    }

    private func teardown() {
        scanTimeout?.cancel()
        scanTimeout = nil
        if central?.isScanning == true { central?.stopScan() }
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        resetConnectionState()
    }

    private func resetConnectionState() {
        receiver?.close()
        receiver = nil
        channel = nil
        peripheral = nil
        commandCharacteristic = nil
        statusCharacteristic = nil
        psmCharacteristic = nil
        isAuthorized = false
        status = nil
        previewImage = nil
    }

    private func fail(_ message: String) {
        let peripheral = peripheral
        code = nil // stop auto-reconnect
        phase = .failed(message)
        if let peripheral { central?.cancelPeripheralConnection(peripheral) }
        resetConnectionState()
    }
}

// MARK: - CBCentralManagerDelegate

extension RemoteCentral: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        switch central.state {
        case .poweredOn:
            if code != nil, peripheral == nil { startScan() }
        case .unauthorized:
            phase = .failed(String(localized: "Allow Bluetooth access in Settings to control the camera."))
        case .poweredOff:
            resetConnectionState()
            phase = .failed(String(localized: "Turn on Bluetooth to connect to the camera."))
        case .unsupported:
            phase = .failed(String(localized: "This device doesn't support Bluetooth LE."))
        default:
            break
        }
    }

    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        guard let code, self.peripheral == nil else { return }
        let name = advertisementData[CBAdvertisementDataLocalNameKey] as? String
        guard name == RemoteConfig.localName(for: code) else { return }

        central.stopScan()
        scanTimeout?.cancel()
        self.peripheral = peripheral
        peripheral.delegate = self
        phase = .connecting
        central.connect(peripheral)
    }

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        phase = .pairing
        peripheral.discoverServices([RemoteUUID.service])
    }

    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        resetConnectionState()
        if code != nil { startScan() }
    }

    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        guard peripheral.identifier == self.peripheral?.identifier else { return }
        resetConnectionState()
        // Auto-reconnect (e.g. the camera app was briefly backgrounded).
        if code != nil { startScan() }
    }
}

// MARK: - CBPeripheralDelegate

extension RemoteCentral: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let service = peripheral.services?.first(where: { $0.uuid == RemoteUUID.service }) else {
            fail(String(localized: "This device isn't a ShutterLink camera."))
            return
        }
        peripheral.discoverCharacteristics([RemoteUUID.command, RemoteUUID.status, RemoteUUID.previewPSM],
                                           for: service)
    }

    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        for characteristic in service.characteristics ?? [] {
            switch characteristic.uuid {
            case RemoteUUID.command: commandCharacteristic = characteristic
            case RemoteUUID.status: statusCharacteristic = characteristic
            case RemoteUUID.previewPSM: psmCharacteristic = characteristic
            default: break
            }
        }
        guard let commandCharacteristic,
              let code,
              let hello = RemoteWire.encode(RemoteCommand.hello(code: code)) else {
            fail(String(localized: "Couldn't pair with the camera."))
            return
        }
        peripheral.writeValue(hello, for: commandCharacteristic, type: .withResponse)
    }

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        guard !isAuthorized else { return } // later command acks don't need handling
        if error != nil {
            fail(String(localized: "The pairing code was rejected. Scan the QR code again."))
            return
        }
        isAuthorized = true
        phase = .connected
        UINotificationFeedbackGenerator().notificationOccurred(.success)

        if let statusCharacteristic {
            peripheral.setNotifyValue(true, for: statusCharacteristic)
            peripheral.readValue(for: statusCharacteristic)
        }
        if let psmCharacteristic {
            peripheral.readValue(for: psmCharacteristic)
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if error != nil {
            // The camera may not have published its L2CAP channel yet; retry the PSM read.
            if characteristic.uuid == RemoteUUID.previewPSM, isAuthorized {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                    guard let self, self.isAuthorized, self.channel == nil else { return }
                    peripheral.readValue(for: characteristic)
                }
            }
            return
        }
        guard let data = characteristic.value else { return }
        switch characteristic.uuid {
        case RemoteUUID.status:
            if data == StatusMarker.readFull {
                // Too big for a notification; fetch it with a (long) read.
                peripheral.readValue(for: characteristic)
            } else if let decoded = RemoteWire.decode(RemoteStatus.self, from: data) {
                status = decoded
            }
        case RemoteUUID.previewPSM:
            guard data.count >= 2, channel == nil else { return }
            let bytes = [UInt8](data)
            let psm = CBL2CAPPSM(bytes[0]) | (CBL2CAPPSM(bytes[1]) << 8)
            peripheral.openL2CAPChannel(psm)
        default:
            break
        }
    }

    func peripheral(_ peripheral: CBPeripheral, didOpen channel: CBL2CAPChannel?, error: Error?) {
        guard let channel, error == nil else {
            print("L2CAP open failed: \(String(describing: error))")
            return
        }
        self.channel = channel
        receiver = PreviewStreamReceiver(channel: channel, onFrame: { [weak self] kind, data in
            guard let self, let image = UIImage(data: data) else { return }
            switch kind {
            case .preview:
                self.previewImage = image
            case .review:
                self.reviews.insert(ReviewPhoto(image: image, data: data), at: 0)
                if self.reviews.count > Self.maxReviews { self.reviews.removeLast() }
            }
        }, onClose: { [weak self, weak channel] in
            // Ignore late close callbacks from a previous connection.
            guard let self, let channel, self.channel === channel else { return }
            self.receiver = nil
            self.channel = nil
            // Try to reopen the preview stream while still paired.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                guard let self, self.isAuthorized, self.channel == nil,
                      let peripheral = self.peripheral,
                      let psmCharacteristic = self.psmCharacteristic else { return }
                peripheral.readValue(for: psmCharacteristic)
            }
        })
    }
}

/// A copy of a photo the camera just took, delivered to the remote so the person can keep it.
struct ReviewPhoto: Identifiable, Equatable {
    let id = UUID()
    let date = Date()
    let image: UIImage
    let data: Data

    static func == (lhs: ReviewPhoto, rhs: ReviewPhoto) -> Bool { lhs.id == rhs.id }
}
