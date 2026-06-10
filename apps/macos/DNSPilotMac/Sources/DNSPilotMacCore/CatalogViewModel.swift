public protocol DNSPilotCatalogBridge {
    func loadCatalog() throws -> CatalogSnapshot
}

public struct CatalogViewModel {
    public let catalog: CatalogSnapshot?
    public let loadErrorMessage: String?

    public init(bridge: DNSPilotCatalogBridge) {
        do {
            catalog = try bridge.loadCatalog()
            loadErrorMessage = nil
        } catch {
            catalog = nil
            loadErrorMessage = error.localizedDescription
        }
    }
}
