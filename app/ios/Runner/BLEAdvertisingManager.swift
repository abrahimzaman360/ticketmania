import Foundation
import CoreBluetooth
import os.log

/**
 * Highly optimized BLE advertising manager for iOS
 * Uses low power advertising intervals and proper advertising parameters
 */
@available(iOS 13.0, *)
class BLEAdvertisingManager: NSObject, CBPeripheralManagerDelegate {
    
    // Custom Service UUID for Ticket Mania
    // Format: 0000FEED-0000-1000-8000-00805F9B34FB
    private let serviceUUID = CBUUID(string: "0000FEED-0000-1000-8000-00805F9B34FB")
    
    private var peripheralManager: CBPeripheralManager?
    private var isAdvertising = false
    private var currentTicketIds: [String] = []
    private var pendingStart = false
    
    // Callbacks
    var onAdvertisingStarted: (() -> Void)?
    var onAdvertisingStopped: (() -> Void)?
    var onAdvertisingError: ((Error) -> Void)?
    
    override init() {
        super.init()
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
    }
    
    // MARK: - Public Methods
    
    /**
     * Start advertising with ticket IDs
     * Optimized for battery consumption with low power settings
     */
    func startAdvertising(ticketIds: [String]) -> Bool {
        guard let peripheralManager = peripheralManager else {
            os_log("Peripheral manager is nil", log: .default, type: .error)
            return false
        }
        
        if ticketIds.isEmpty {
            os_log("No ticket IDs to advertise", log: .default, type: .info)
            return false
        }
        
        currentTicketIds = ticketIds
        
        // Stop current advertising if active
        if isAdvertising {
            stopAdvertising()
        }
        
        // Wait for peripheral manager to be ready
        if peripheralManager.state != .poweredOn {
            pendingStart = true
            os_log("Bluetooth not ready, waiting...", log: .default, type: .info)
            return true
        }
        
        return startAdvertisingInternal()
    }
    
    /**
     * Stop advertising
     */
    func stopAdvertising() {
        guard let peripheralManager = peripheralManager else {
            return
        }
        
        if isAdvertising {
            peripheralManager.stopAdvertising()
            isAdvertising = false
            currentTicketIds = []
            os_log("Stopped BLE advertising", log: .default, type: .info)
            onAdvertisingStopped?()
        }
    }
    
    /**
     * Update ticket IDs while advertising
     */
    func updateTicketIds(ticketIds: [String]) {
        if isAdvertising {
            // Restart advertising with new ticket IDs
            stopAdvertising()
            startAdvertising(ticketIds: ticketIds)
        } else {
            currentTicketIds = ticketIds
        }
    }
    
    func isCurrentlyAdvertising() -> Bool {
        return isAdvertising
    }
    
    func getCurrentTicketIds() -> [String] {
        return currentTicketIds
    }
    
    // MARK: - Private Methods
    
    private func startAdvertisingInternal() -> Bool {
        guard let peripheralManager = peripheralManager else {
            return false
        }
        
        // Create CBMutableService with our UUID
        let service = CBMutableService(type: serviceUUID, primary: true)
        
        // Create characteristic with ticket IDs
        let characteristic = CBMutableCharacteristic(
            type: CBUUID(string: "0000FEED-0001-1000-8000-00805F9B34FB"),
            properties: [.read, .notify],
            value: encodeTicketIds(currentTicketIds),
            permissions: [.readable]
        )
        
        service.characteristics = [characteristic]
        
        // Add service to peripheral manager
        peripheralManager.add(service)
        
        // Create advertising data
        // iOS automatically uses low power advertising intervals
        let advertisementData: [String: Any] = [
            CBAdvertisementDataServiceUUIDsKey: [serviceUUID],
            CBAdvertisementDataServiceDataKey: [
                serviceUUID: encodeTicketIds(currentTicketIds)
            ],
            CBAdvertisementDataLocalNameKey: "" // Empty to save power
        ]
        
        // Start advertising with optimized settings
        // iOS uses low power mode by default for background advertising
        peripheralManager.startAdvertising(advertisementData)
        
        os_log("Started BLE advertising with %d ticket(s)", log: .default, type: .info, currentTicketIds.count)
        return true
    }
    
    /**
     * Encode ticket IDs into Data for advertising
     * Format: [count: 1 byte][id1_length: 1 byte][id1: N bytes][id2_length: 1 byte][id2: M bytes]...
     */
    private func encodeTicketIds(_ ticketIds: [String]) -> Data {
        if ticketIds.isEmpty {
            return Data([0])
        }
        
        // Limit to 20 bytes total (BLE advertising data limit is 31 bytes, we use 20 for ticket data)
        let maxBytes = 20
        var totalBytes = 1 // Count byte
        var encodedIds: [Data] = []
        
        for ticketId in ticketIds {
            guard let idData = ticketId.data(using: .utf8) else {
                continue
            }
            
            let entrySize = 1 + idData.count // 1 byte for length + id bytes
            
            if totalBytes + entrySize > maxBytes {
                break // Can't fit more tickets
            }
            
            var entry = Data()
            entry.append(UInt8(idData.count))
            entry.append(idData)
            encodedIds.append(entry)
            totalBytes += entrySize
        }
        
        // Build final data: [count][id1_length][id1]...[idN_length][idN]
        var result = Data()
        result.append(UInt8(encodedIds.count))
        
        for encodedId in encodedIds {
            result.append(encodedId)
        }
        
        return result
    }
    
    /**
     * Decode ticket IDs from Data
     */
    func decodeTicketIds(_ data: Data) -> [String] {
        guard !data.isEmpty, data[0] != 0 else {
            return []
        }
        
        let count = Int(data[0])
        var ticketIds: [String] = []
        var offset = 1
        
        for _ in 0..<count {
            guard offset < data.count else {
                break
            }
            
            let idLength = Int(data[offset])
            offset += 1
            
            guard offset + idLength <= data.count else {
                break
            }
            
            let idData = data.subdata(in: offset..<(offset + idLength))
            if let ticketId = String(data: idData, encoding: .utf8) {
                ticketIds.append(ticketId)
            }
            offset += idLength
        }
        
        return ticketIds
    }
    
    // MARK: - CBPeripheralManagerDelegate
    
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        switch peripheral.state {
        case .poweredOn:
            os_log("Bluetooth powered on", log: .default, type: .info)
            if pendingStart {
                pendingStart = false
                _ = startAdvertisingInternal()
            }
        case .poweredOff:
            os_log("Bluetooth powered off", log: .default, type: .error)
            isAdvertising = false
            onAdvertisingError?(NSError(domain: "BLEAdvertising", code: -1, userInfo: [NSLocalizedDescriptionKey: "Bluetooth is powered off"]))
        case .unauthorized:
            os_log("Bluetooth unauthorized", log: .default, type: .error)
            isAdvertising = false
            onAdvertisingError?(NSError(domain: "BLEAdvertising", code: -2, userInfo: [NSLocalizedDescriptionKey: "Bluetooth is unauthorized"]))
        case .unsupported:
            os_log("Bluetooth unsupported", log: .default, type: .error)
            isAdvertising = false
            onAdvertisingError?(NSError(domain: "BLEAdvertising", code: -3, userInfo: [NSLocalizedDescriptionKey: "Bluetooth LE is not supported"]))
        case .resetting:
            os_log("Bluetooth resetting", log: .default, type: .info)
        case .unknown:
            os_log("Bluetooth state unknown", log: .default, type: .info)
        @unknown default:
            os_log("Bluetooth state unknown", log: .default, type: .info)
        }
    }
    
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            os_log("Failed to start advertising: %@", log: .default, type: .error, error.localizedDescription)
            isAdvertising = false
            onAdvertisingError?(error)
        } else {
            os_log("Successfully started advertising", log: .default, type: .info)
            isAdvertising = true
            onAdvertisingStarted?()
        }
    }
    
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if let error = error {
            os_log("Failed to add service: %@", log: .default, type: .error, error.localizedDescription)
        } else {
            os_log("Service added successfully", log: .default, type: .info)
        }
    }
}

