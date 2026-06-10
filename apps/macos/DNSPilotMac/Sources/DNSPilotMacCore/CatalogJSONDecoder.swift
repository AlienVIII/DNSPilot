import Foundation

public struct CatalogJSONDecoder {
    private let decoder: JSONDecoder

    public init(decoder: JSONDecoder = JSONDecoder()) {
        self.decoder = decoder
    }

    public func decode(_ data: Data) throws -> CatalogSnapshot {
        try decoder.decode(CatalogSnapshot.self, from: data)
    }
}

public struct CatalogJSONBridge: DNSPilotCatalogBridge {
    private let loadData: () throws -> Data
    private let decoder: CatalogJSONDecoder

    public init(data: Data, decoder: CatalogJSONDecoder = CatalogJSONDecoder()) {
        self.loadData = { data }
        self.decoder = decoder
    }

    public init(
        decoder: CatalogJSONDecoder = CatalogJSONDecoder(),
        loadData: @escaping () throws -> Data
    ) {
        self.loadData = loadData
        self.decoder = decoder
    }

    public func loadCatalog() throws -> CatalogSnapshot {
        try decoder.decode(loadData())
    }
}
