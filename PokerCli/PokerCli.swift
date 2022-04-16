import ArgumentParser
import OSLog

@main
struct Poke: ParsableCommand {
  static var configuration = CommandConfiguration(
    commandName: "poker",
    abstract: "A utility for controlling Ember devices.",
    version: "0.0.0",
    subcommands: [Pair.self, Get.self, Set.self])
}

struct Options: ParsableArguments {
  @Argument(help: "UUID of Ember device.")
  var uuid: String
  
  func validate() throws {
    let uuid = UUID(uuidString: uuid)
    if uuid == nil {
      throw ValidationError("failed to parse UUID")
    }
  }
}

extension Poke {
  static func getPoker(uuid: UUID) -> Poker {
    let queue = DispatchQueue(label: "ConcurrentQueue", qos: .default, attributes: .concurrent)
    let logger = Logger()
    let poker = Poker(peripheralId: uuid, queue: queue, logger: logger)
    while !poker.isConnected() {
      Logger.init().info("waiting for connection")
      sleep(1)
    }
    return poker
  }
  
  struct Pair: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Pair with an Ember device.")
    @OptionGroup var opts: Options
    
    mutating func run() throws {
      let uuid = UUID(uuidString: opts.uuid)!
      let poker = getPoker(uuid: uuid)
      throw poker.pair() ? ExitCode.success : ExitCode.failure
    }
  }
  
  struct Get: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Get data from the Ember device.")
    @OptionGroup var opts: Options
    @Argument(help: "Datum to operate on. \"target\", \"current\", \"level\", or \"rgb\".")
    var datum: String
    
    func validate() throws {
      if (datum != "target") && (datum != "current") && (datum != "level") && (datum != "rgb") {
        throw ValidationError("datum may be \"target\", \"current\", \"level\", or \"rgb\"")
      }
    }
    
    mutating func run() throws {
      let uuid = UUID(uuidString: opts.uuid)!
      let poker = getPoker(uuid: uuid)
      switch(datum) {
      case "current":
        if let ret = poker.getCurrentTemperature() {
          print(ret)
          throw ExitCode.success
        }
      case "level":
        if let ret = poker.getLiquidLevel() {
          print(ret)
          throw ExitCode.success
        }
      case "rgb":
        if let ret = poker.getRgb() {
          print(String(format:"%06X", ret.bigEndian >> 8))
          throw ExitCode.success
        }
      default: // "target"
        if let ret = poker.getTargetTemperature() {
          print(ret)
          throw ExitCode.success
        }
      }
      throw ExitCode.failure
    }
  }
  
  struct Set: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Set data on the Ember device.")
    @OptionGroup var opts: Options
    @Argument(help: "Datum to operate on. \"target\" or \"rgb\".")
    var datum: String
    @Argument(help: "Value to set datum to")
    var arg: String
    
    func validate() throws {
      if (datum != "target") && (datum != "rgb") {
        throw ValidationError("datum may be \"target\" or \"rgb\"")
      }
    }
    
    mutating func run() throws {
      let uuid = UUID(uuidString: opts.uuid)!
      let poker = getPoker(uuid: uuid)
      switch datum {
      case "rgb":
        if let rgb = UInt32(arg, radix: 16) {
          throw poker.setRgb(rgb: rgb.bigEndian >> 8) ?
          ExitCode.success
          : ExitCode.failure
        }
        throw ValidationError("rgb must be 4 byte hex value")
      default: // "target"
        if let temp = UInt16(arg) {
          throw poker.setTargetTemperature(targetTemperature: temp) ?
          ExitCode.success
          : ExitCode.failure
        }
        throw ValidationError("temperature must be UInt16")
      }
    }
  }
}

