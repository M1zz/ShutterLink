import CoreBluetooth
import Foundation

/// BLE GATT server on the camera iPhone.
/// - Advertises the service with local name "SL-<code>" so a remote can find the right camera.
/// - A remote must write `.hello(code:)` with the pairing code before any other command is accepted.
/// - Authorized remotes can read the L2CAP PSM and open a preview stream.
final class RemotePeripheral: NSObject, ObservableObject {
    @Published private(set) var bluetoothState = "Starting Bluetooth…"
    @Published private(set) var isAdvertising = false
    @Published private(set) var connectedRemotes = 0
    @Published private(set) var hasPreviewViewers = false

    let sessionCode: String
    var onCommand: ((RemoteCommand) -> Void)?

    private var manager: CBPeripheralManager?
    private let commandCharacteristic = CBMutableCharacteristic(
        type: RemoteUUID.command, properties: [.write], value: nil, permissions: [.writeable])
    private let statusCharacteristic = CBMutableCharacteristic(
        type: RemoteUUID.status, properties: [.read, .notify], value: nil, permissions: [.readable])
    private let psmCharacteristic = CBMutableCharacteristic(
        type: RemoteUUID.previewPSM, properties: [.read], value: nil, permissions: [.readable])

    private var serviceAdded = false
    private var psm: CBL2CAPPSM?
    private var authorized = Set<UUID>()
    private var subscribers: [UUID: CBCentral] = [:]
    private var channels: [UUID: PreviewStreamSender] = [:]
    private var statusData = Data()
    private var needsStatusResend = false

    init(sessionCode: String) {
        self.sessionCode = sessionCode
        super.init()
    }

    func start() {
        guard manager == nil else { return }
        manager = CBPeripheralManager(delegate: self, queue: .main)
    }

    /// main thread
    func updateStatus(_ status: RemoteStatus) {
        guard let data = RemoteWire.encode(status), data != statusData else { return }
        statusData = data
        sendStatus()
    }

    /// main thread
    func sendPreviewFrame(_ jpeg: Data) {
        let framed = FrameAssembler.frame(jpeg)
        for sender in channels.values where sender.isIdle {
            sender.send(framed)
        }
    }

    private func sendStatus() {
        guard let manager, !subscribers.isEmpty, !statusData.isEmpty else { return }
        needsStatusResend = !manager.updateValue(statusData, for: statusCharacteristic, onSubscribedCentrals: nil)
    }

    private func refreshCounts() {
        connectedRemotes = subscribers.keys.filter { authorized.contains($0) }.count
        hasPreviewViewers = !channels.isEmpty
    }

    private func setUpService(_ peripheral: CBPeripheralManager) {
        guard !serviceAdded else {
            startAdvertising(peripheral)
            return
        }
        peripheral.removeAllServices()
        let service = CBMutableService(type: RemoteUUID.service, primary: true)
        service.characteristics = [commandCharacteristic, statusCharacteristic, psmCharacteristic]
        peripheral.add(service)
        peripheral.publishL2CAPChannel(withEncryption: false)
    }

    private func startAdvertising(_ peripheral: CBPeripheralManager) {
        guard !peripheral.isAdvertising else { return }
        peripheral.startAdvertising([
            CBAdvertisementDataServiceUUIDsKey: [RemoteUUID.service],
            CBAdvertisementDataLocalNameKey: RemoteConfig.localName(for: sessionCode)
        ])
    }

    private func dropCentral(_ id: UUID) {
        subscribers.removeValue(forKey: id)
        authorized.remove(id)
        channels.removeValue(forKey: id)?.close()
        refreshCounts()
    }
}

extension RemotePeripheral: CBPeripheralManagerDelegate {
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            bluetoothState = "Bluetooth ready"
            setUpService(peripheral)
        case .poweredOff:
            bluetoothState = "Bluetooth is off"
            resetAfterPowerLoss()
        case .unauthorized:
            bluetoothState = "Bluetooth permission denied"
            resetAfterPowerLoss()
        case .unsupported:
            bluetoothState = "Bluetooth LE not supported"
        default:
            bluetoothState = "Bluetooth unavailable"
        }
    }

    private func resetAfterPowerLoss() {
        isAdvertising = false
        serviceAdded = false
        psm = nil
        for id in Array(subscribers.keys) { dropCentral(id) }
        authorized.removeAll()
        refreshCounts()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error {
            bluetoothState = "Service error: \(error.localizedDescription)"
            return
        }
        serviceAdded = true
        startAdvertising(peripheral)
    }

    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error {
            isAdvertising = false
            bluetoothState = "Advertising failed: \(error.localizedDescription)"
        } else {
            isAdvertising = true
            bluetoothState = "Waiting for a remote"
        }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didPublishL2CAPChannel PSM: CBL2CAPPSM, error: Error?) {
        if let error {
            print("L2CAP publish failed: \(error)")
            return
        }
        psm = PSM
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
        guard characteristic.uuid == RemoteUUID.status else { return }
        subscribers[central.identifier] = central
        peripheral.setDesiredConnectionLatency(.low, for: central)
        refreshCounts()
        sendStatus()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
        guard characteristic.uuid == RemoteUUID.status else { return }
        // Unsubscribe is the most reliable disconnect signal on the peripheral side.
        dropCentral(central.identifier)
    }

    func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {
        if needsStatusResend { sendStatus() }
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveRead request: CBATTRequest) {
        let value: Data
        switch request.characteristic.uuid {
        case RemoteUUID.status:
            value = statusData
        case RemoteUUID.previewPSM:
            guard authorized.contains(request.central.identifier), let psm else {
                peripheral.respond(to: request, withResult: .readNotPermitted)
                return
            }
            var littleEndian = psm.littleEndian
            value = withUnsafeBytes(of: &littleEndian) { Data($0) }
        default:
            peripheral.respond(to: request, withResult: .attributeNotFound)
            return
        }
        guard request.offset <= value.count else {
            peripheral.respond(to: request, withResult: .invalidOffset)
            return
        }
        request.value = value.subdata(in: request.offset ..< value.count)
        peripheral.respond(to: request, withResult: .success)
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didReceiveWrite requests: [CBATTRequest]) {
        guard let first = requests.first else { return }
        // Note: never answer with .insufficientAuthentication — it makes iOS start BLE pairing.
        var result: CBATTError.Code = .success
        for request in requests {
            guard request.characteristic.uuid == RemoteUUID.command,
                  let data = request.value,
                  let command = RemoteWire.decode(RemoteCommand.self, from: data) else {
                result = .unlikelyError
                continue
            }
            let id = request.central.identifier
            if case .hello(let code) = command {
                if code == sessionCode {
                    authorized.insert(id)
                } else {
                    result = .writeNotPermitted
                }
            } else if authorized.contains(id) {
                onCommand?(command)
            } else {
                result = .writeNotPermitted
            }
        }
        peripheral.respond(to: first, withResult: result)
        refreshCounts()
    }

    func peripheralManager(_ peripheral: CBPeripheralManager, didOpen channel: CBL2CAPChannel?, error: Error?) {
        guard let channel, error == nil else { return }
        let id = channel.peer.identifier
        guard authorized.contains(id) else {
            channel.inputStream?.close()
            channel.outputStream?.close()
            return
        }
        channels[id]?.close()
        let sender = PreviewStreamSender(channel: channel) { [weak self] in
            // Only remove the registered sender if it is the one that closed
            // (a replaced sender's close callback must not remove its successor).
            guard let self, let current = self.channels[id], current.isClosed else { return }
            self.channels.removeValue(forKey: id)
            self.refreshCounts()
        }
        channels[id] = sender
        refreshCounts()
    }
}
