import ExpoModulesCore
import NetworkExtension

struct DNSSettingsRequest: Record {
  @Field var description: String = ""
  @Field var protocolName: String = ""
  @Field var serverAddresses: [String] = []
  @Field var dohUrl: String?
  @Field var dotHostname: String?
}

public class DNSSettingsModule: Module {
  public func definition() -> ModuleDefinition {
    Name("DNSSettings")

    AsyncFunction("getStatus") { () async throws -> [String: Any] in
      guard #available(iOS 14.0, *) else {
        return unavailableStatus("iOS 14 or later is required.")
      }
      let manager = NEDNSSettingsManager.shared()
      try await load(manager)
      return status(for: manager)
    }

    AsyncFunction("install") { (request: DNSSettingsRequest) async throws -> [String: Any] in
      guard #available(iOS 14.0, *) else {
        return unavailableStatus("iOS 14 or later is required.")
      }
      guard !request.description.isEmpty, !request.serverAddresses.isEmpty else {
        throw DNSSettingsError.invalidRequest("A description and bootstrap server addresses are required.")
      }

      let manager = NEDNSSettingsManager.shared()
      try await load(manager)
      manager.localizedDescription = request.description
      manager.dnsSettings = try dnsSettings(from: request)
      try await save(manager)
      try await load(manager)
      return status(for: manager)
    }

    AsyncFunction("remove") { () async throws -> [String: Any] in
      guard #available(iOS 14.0, *) else {
        return unavailableStatus("iOS 14 or later is required.")
      }
      let manager = NEDNSSettingsManager.shared()
      try await load(manager)
      try await remove(manager)
      try await load(manager)
      return status(for: manager)
    }
  }
}

@available(iOS 14.0, *)
private func dnsSettings(from request: DNSSettingsRequest) throws -> NEDNSSettings {
  switch request.protocolName {
  case "doh":
    guard let value = request.dohUrl, let url = URL(string: value), url.scheme?.lowercased() == "https" else {
      throw DNSSettingsError.invalidRequest("A valid HTTPS DoH URL is required.")
    }
    let settings = NEDNSOverHTTPSSettings(servers: request.serverAddresses)
    settings.serverURL = url
    return settings
  case "dot":
    guard let hostname = request.dotHostname, !hostname.isEmpty else {
      throw DNSSettingsError.invalidRequest("A DoT hostname is required.")
    }
    let settings = NEDNSOverTLSSettings(servers: request.serverAddresses)
    settings.serverName = hostname
    return settings
  default:
    throw DNSSettingsError.invalidRequest("Only DoH and DoT configurations are supported.")
  }
}

@available(iOS 14.0, *)
private func load(_ manager: NEDNSSettingsManager) async throws {
  try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
    manager.loadFromPreferences { error in
      if let error {
        continuation.resume(throwing: error)
      } else {
        continuation.resume()
      }
    }
  }
}

@available(iOS 14.0, *)
private func save(_ manager: NEDNSSettingsManager) async throws {
  try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
    manager.saveToPreferences { error in
      if let error {
        continuation.resume(throwing: error)
      } else {
        continuation.resume()
      }
    }
  }
}

@available(iOS 14.0, *)
private func remove(_ manager: NEDNSSettingsManager) async throws {
  try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
    manager.removeFromPreferences { error in
      if let error {
        continuation.resume(throwing: error)
      } else {
        continuation.resume()
      }
    }
  }
}

@available(iOS 14.0, *)
private func status(for manager: NEDNSSettingsManager) -> [String: Any] {
  return [
    "available": true,
    "installed": manager.dnsSettings != nil,
    "enabled": manager.isEnabled,
    "description": manager.localizedDescription ?? NSNull(),
    "protocol": protocolName(for: manager.dnsSettings) ?? NSNull(),
  ]
}

private func unavailableStatus(_ reason: String) -> [String: Any] {
  return [
    "available": false,
    "installed": false,
    "enabled": false,
    "description": NSNull(),
    "protocol": NSNull(),
    "reason": reason,
  ]
}

@available(iOS 14.0, *)
private func protocolName(for settings: NEDNSSettings?) -> String? {
  if settings is NEDNSOverHTTPSSettings {
    return "doh"
  }
  if settings is NEDNSOverTLSSettings {
    return "dot"
  }
  return nil
}

private enum DNSSettingsError: Error, LocalizedError {
  case invalidRequest(String)

  var errorDescription: String? {
    switch self {
    case .invalidRequest(let message):
      return message
    }
  }
}
