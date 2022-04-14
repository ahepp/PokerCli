import CoreBluetooth
import OSLog

class EmberCentralManager: NSObject, CBCentralManagerDelegate, CBPeripheralDelegate {
  private var peripheralId: UUID;
  private var emberServiceId = CBUUID(string: "FC543622-236C-4C94-8FA9-944A3E5353FA")
  private var logger: Logger!
  public var connected = false
  public var mug: CBPeripheral?
  private var targetTemperatureCharacteristicId = CBUUID(string: "FC540003-236C-4C94-8FA9-944A3E5353FA")
  public var targetTemperatureCharacteristic: CBCharacteristic?
  private var currentTemperatureCharacteristicId = CBUUID(string: "FC540002-236C-4C94-8FA9-944A3E5353FA")
  public var currentTemperatureCharacteristic: CBCharacteristic?
  private var pairingReadCharacteristicId = CBUUID(string: "FC54000E-236C-4C94-8FA9-944A3E5353FA")
  public var pairingReadCharacteristic: CBCharacteristic?
  private var pairingWriteCharacteristicId = CBUUID(string: "FC54000F-236C-4C94-8FA9-944A3E5353FA")
  public var pairingWriteCharacteristic: CBCharacteristic?
                                              
  
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
    mug = peripheral
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
        peripheral.discoverCharacteristics(nil, for: s)
      }
    }
  }

  func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
    if let cs = service.characteristics {
      for c in cs {
        switch c.uuid {
          case targetTemperatureCharacteristicId:
            targetTemperatureCharacteristic = c
          case currentTemperatureCharacteristicId:
            currentTemperatureCharacteristic = c
          case pairingReadCharacteristicId:
            pairingReadCharacteristic = c
          case pairingWriteCharacteristicId:
            pairingWriteCharacteristic = c
          default:
            logger.info("discovered characteristic")
        }
      }
    }
  }
}

public struct Poker {
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
    logger.info("setting target temperature")
    var tmp = targetTemperature
    let data = Data(bytes: &tmp, count: MemoryLayout<UInt16>.size)
    if let mug = delegate.mug, let c = delegate.targetTemperatureCharacteristic {
      mug.writeValue(data, for: c, type: .withResponse)
      sleep(1)
      logger.info("set \(UInt16(data[0]) + UInt16(data[1]) * 256)")
      return true
    } else {
      logger.info("failed to set target temperature")
      return false
    }
  }
  
  func getTargetTemperature() -> UInt16? {
    guard delegate.connected else {return nil}
    if let mug = delegate.mug, let c = delegate.targetTemperatureCharacteristic {
      logger.info("getting target temperature")
      return getUInt16(p: mug, c: c)
    } else {
      logger.info("failed to get target temperature")
      return nil
    }
  }
  
  func getCurrentTemperature() -> UInt16? {
    guard delegate.connected else {return nil}
    if let mug = delegate.mug, let c = delegate.currentTemperatureCharacteristic {
      logger.info("getting current temperature")
      return getUInt16(p: mug, c: c)
    } else {
      logger.info("failed to get current temperature")
      return nil
    }
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
    if let mug = delegate.mug,
       let cr = delegate.pairingReadCharacteristic,
       let cw = delegate.pairingWriteCharacteristic
    {
      mug.readValue(for: cr)
      logger.info("sent pair read")
      sleep(2)
      let data = Data([0xBA, 0x37, 0x89, 0x40, 0x51, 0x0A, 0x13, 0x68, 0x85, 0xE8, 0xD7, 0x73, 0xA5, 0xE0, 0x3E, 0x1C, 0x3F, 0xF2, 0xF5, 0xFA])
      mug.writeValue(data, for: cw, type: .withResponse)
      sleep(2)
      return true
    } else {
      logger.info("failed to pair")
      return false
    }
  }
  func isConnected() -> Bool {
    return delegate.connected
  }
}
