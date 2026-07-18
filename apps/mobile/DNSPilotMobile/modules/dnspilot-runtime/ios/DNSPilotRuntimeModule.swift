import ExpoModulesCore
import Foundation

@_silgen_name("dnspilot_run_action")
private func dnspilotRunAction(
  _ action: UnsafePointer<CChar>,
  _ payloadJson: UnsafePointer<CChar>,
  _ dbPath: UnsafePointer<CChar>?
) -> UnsafeMutablePointer<CChar>?

@_silgen_name("dnspilot_free_string")
private func dnspilotFreeString(_ value: UnsafeMutablePointer<CChar>)

public class DNSPilotRuntimeModule: Module {
  public func definition() -> ModuleDefinition {
    Name("DNSPilotRuntime")

    Function("isAvailable") { true }

    AsyncFunction("runAction") { (action: String, payloadJson: String) -> String in
      let databasePath = try mobileDatabasePath()
      return try action.withCString { actionPointer in
        try payloadJson.withCString { payloadPointer in
          try databasePath.withCString { databasePointer in
            guard let output = dnspilotRunAction(actionPointer, payloadPointer, databasePointer) else {
              throw DNSPilotRuntimeError.emptyResponse
            }
            defer { dnspilotFreeString(output) }
            return String(cString: output)
          }
        }
      }
    }
  }
}

private func mobileDatabasePath() throws -> String {
  var directory = try FileManager.default.url(
    for: .applicationSupportDirectory,
    in: .userDomainMask,
    appropriateFor: nil,
    create: true
  ).appendingPathComponent("DNSPilot", isDirectory: true)
  try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
  var resourceValues = URLResourceValues()
  resourceValues.isExcludedFromBackup = true
  try directory.setResourceValues(resourceValues)
  return directory.appendingPathComponent("dnspilot.sqlite").path
}

private enum DNSPilotRuntimeError: Error, LocalizedError {
  case emptyResponse

  var errorDescription: String? {
    "The DNSPilot native runtime returned no response."
  }
}
