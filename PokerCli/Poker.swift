import CoreBluetooth
import OSLog

class EmberCentralManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  private final var peripheralId: UUID;
  private final var emberServiceId = CBUUID(string: "FC543622-236C-4C94-8FA9-944A3E5353FA")
  public private(set) var charsDiscovered: [CBUUID: CBCharacteristic] = [:]
  
  private var logger: Logger!
  public var peripheral: CBPeripheral?
  public var connected = false
  
  init(peripheralId: UUID, logger: Logger) {
    self.peripheralId = peripheralId
    self.logger = Logger()
  }
  
  func centralManagerDidUpdateState(_ central: CBCentralManager) {
    logger.info("central manager state updated to \(central.state.rawValue)")
    switch central.state {
    case .poweredOn:
      central.scanForPeripherals(withServices: nil)
      logger.info("started scan")
    default:
      central.stopScan()
      logger.info("stopped scan")
    }
  }
  
  func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
    guard peripheral.identifier == self.peripheralId else {return}
    logger.info("discovered peripheral \(peripheral.identifier.uuidString)")
    central.stopScan()
    logger.info("stopped scan")
    central.connect(peripheral, options: nil)
    self.peripheral = peripheral
  }
  
  func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
    logger.info("connected to \(peripheral.identifier.uuidString)")
    self.connected = true
    peripheral.delegate = self
    peripheral.discoverServices(nil)
  }
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
    if let ss = peripheral.services {
      for s in ss {
        logger.info("discovered service \(s.uuid.uuidString)")
        if(s.uuid == emberServiceId) {
          peripheral.discoverCharacteristics(nil, for: s)
        }
      }
    }
  }
  
  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    if let cs = service.characteristics {
      for c in cs {
        logger.info("discovered characteristic \(c.uuid)")
        charsDiscovered[c.uuid] = c
      }
    }
  }
}

class Poker {
  enum EmberChars: Int { case
    DeviceName,
    DrinkTemperature,
    TargetTemperature,
    TemperatureUnit,
    LiquidLevel,
    BatteryLevel,
    LiquidState,
    MugId,
    Dsk,
    Udsk,
    PushEvent,
    Statistics,
    Rgb
  }
  private final var EmberCharUuids: [EmberChars: CBUUID] =
  [
    .DeviceName:        CBUUID(string: "FC540001-236C-4C94-8FA9-944A3E5353FA"),
    .DrinkTemperature:  CBUUID(string: "FC540002-236C-4C94-8FA9-944A3E5353FA"),
    .TargetTemperature: CBUUID(string: "FC540003-236C-4C94-8FA9-944A3E5353FA"),
    .TemperatureUnit:   CBUUID(string: "FC540004-236C-4C94-8FA9-944A3E5353FA"),
    .LiquidLevel:       CBUUID(string: "FC540005-236C-4C94-8FA9-944A3E5353FA"),
    .BatteryLevel:      CBUUID(string: "FC540007-236C-4C94-8FA9-944A3E5353FA"),
    .LiquidState:       CBUUID(string: "FC540008-236C-4C94-8FA9-944A3E5353FA"),
    .MugId:             CBUUID(string: "FC54000D-236C-4C94-8FA9-944A3E5353FA"),
    .Dsk:               CBUUID(string: "FC54000E-236C-4C94-8FA9-944A3E5353FA"),
    .Udsk:              CBUUID(string: "FC54000F-236C-4C94-8FA9-944A3E5353FA"),
    .PushEvent:         CBUUID(string: "FC540012-236C-4C94-8FA9-944A3E5353FA"),
    .Statistics:        CBUUID(string: "FC540013-236C-4C94-8FA9-944A3E5353FA"),
    .Rgb:               CBUUID(string: "FC540014-236C-4C94-8FA9-944A3E5353FA")
  ]
  private var queue: DispatchQueue!
  private var logger: Logger!
  private var delegate: EmberCentralManager!
  private var manager: CBCentralManager!
  
  public init(peripheralId: UUID, queue: DispatchQueue, logger: Logger) {
    self.logger = logger
    self.queue = queue
    self.delegate = EmberCentralManager(peripheralId: peripheralId, logger: self.logger)
    self.manager = CBCentralManager(delegate: self.delegate, queue: self.queue)
  }
  
  func setTargetTemperature(targetTemperature: UInt16) -> Bool {
    guard delegate.connected else {return false}
    let peripheral = delegate.peripheral!
    let char = delegate.charsDiscovered[EmberCharUuids[EmberChars.TargetTemperature]!]
    if char == nil {
      logger.info("set temperature failed, delegate has not discovered target temperature characteristic")
      return false
    }
    
    logger.info("setting target temperature")
    var tmp = targetTemperature
    let data = Data(bytes: &tmp, count: MemoryLayout<UInt16>.size)
    peripheral.writeValue(data, for: char!, type: .withResponse)
    sleep(1)
    logger.info("set \(UInt16(data[0]) + UInt16(data[1]) * 256)")
    return true
  }
  
  func getTargetTemperature() -> UInt16? {
    guard delegate.connected else {return nil}
    let peripheral = delegate.peripheral!
    if let char = delegate.charsDiscovered[EmberCharUuids[EmberChars.TargetTemperature]!] {
      logger.info("getting target temperature")
      return getUInt16(p: peripheral, c: char)
    }
    logger.info("get target temperature failed, delegate has not discovered target temperature characteristic")
    return nil
  }
  
  func getCurrentTemperature() -> UInt16? {
    guard delegate.connected else {return nil}
    let peripheral = delegate.peripheral!
    if let char = delegate.charsDiscovered[EmberCharUuids[EmberChars.DrinkTemperature]!] {
      logger.info("getting drink temperature")
      return getUInt16(p: peripheral, c: char)
    }
    logger.info("get drink temperature failed, delegate has not discovered drink temperature characteristic")
    return nil
  }
  
  private func getUInt16(p: CBPeripheral, c: CBCharacteristic) -> UInt16 {
    p.readValue(for: c)
    sleep(1)
    //debugPrint(c.value!.map { "\($0)" }.joined(separator: " "))
    let ret = c.value!.withUnsafeBytes {
      [UInt16](UnsafeBufferPointer(start: $0, count: c.value!.count))
    }.first!
    logger.info("got \(ret)")
    return ret
  }
  
  func pair() -> Bool {
    if let peripheral = delegate.peripheral,
       let cr = delegate.charsDiscovered[EmberCharUuids[EmberChars.Dsk]!],
       let cw = delegate.charsDiscovered[EmberCharUuids[EmberChars.Udsk]!]
    {
      peripheral.readValue(for: cr)
      logger.info("sent pair read")
      sleep(2)
      let data = Data([0xBA, 0x37, 0x89, 0x40, 0x51, 0x0A, 0x13, 0x68, 0x85, 0xE8, 0xD7, 0x73, 0xA5, 0xE0, 0x3E, 0x1C, 0x3F, 0xF2, 0xF5, 0xFA])
      peripheral.writeValue(data, for: cw, type: .withResponse)
      logger.info("sent pair write")
      sleep(2)
      return true
    }
    logger.info("failed to pair")
    return false
  }
  func isConnected() -> Bool {
    return delegate.connected
  }
}
