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
    @Argument(help: "Datum to operate on. \"target\" or \"current\".")
    var datum: String
    
    func validate() throws {
      if (datum != "target") && (datum != "current") {
        throw ValidationError("datum must be \"target\" or \"current\"")
      }
    }
    
    mutating func run() throws {
      let uuid = UUID(uuidString: opts.uuid)!
      let poker = getPoker(uuid: uuid)
      var ret: UInt16?
      if datum == "target" {
        ret = poker.getTargetTemperature()
      } else {
        ret = poker.getCurrentTemperature()
      }
      if let ret: UInt16 = ret {
        print(ret)
        throw ExitCode.success
      }
      throw ExitCode.failure
    }
  }
  
  struct Set: ParsableCommand {
    static var configuration = CommandConfiguration(abstract: "Set data on the Ember device.")
    @OptionGroup var opts: Options
    @Argument(help: "Datum to operate on. Only \"target\" is supported.")
    var datum: String
    @Argument(help: "Temperature, in celcius, times 100. That is, 5723 for 135f (57.23c).")
    var temp: UInt16

    func validate() throws {
      if (datum != "target") {
        throw ValidationError("datum must be \"target\"")
      }
    }
    
    mutating func run() throws {
      let uuid = UUID(uuidString: opts.uuid)!
      let poker = getPoker(uuid: uuid)
      throw poker.setTargetTemperature(targetTemperature: temp) ?
        ExitCode.success
      : ExitCode.failure
    }
  }
}

