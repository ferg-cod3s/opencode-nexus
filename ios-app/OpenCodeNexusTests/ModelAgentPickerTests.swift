import XCTest
@testable import OpenCodeNexus

final class ModelAgentPickerTests: XCTestCase {

    func testGroupedModelsEmpty() {
        let result = groupedModels([], providers: [])
        XCTAssertTrue(result.isEmpty)
    }

    func testGroupedModelsSorting() {
        let models: [(providerID: String, modelID: String, name: String)] = [
            ("b", "m2", "Beta"),
            ("a", "m1", "Alpha"),
            ("b", "m3", "Gamma"),
        ]
        let providers = [
            ProviderInfo(id: "a", name: "A Provider", models: nil),
            ProviderInfo(id: "b", name: "B Provider", models: nil),
        ]
        let result = groupedModels(models, providers: providers)
        XCTAssertEqual(result.count, 2)
        XCTAssertEqual(result[0].providerID, "a")
        XCTAssertEqual(result[1].providerID, "b")
        XCTAssertEqual(result[1].models.map(\.name), ["Beta", "Gamma"])
    }

    func testGroupedModelsFallbackProviderName() {
        let models: [(providerID: String, modelID: String, name: String)] = [
            ("unknown", "m1", "Model"),
        ]
        let result = groupedModels(models, providers: [])
        XCTAssertEqual(result.first?.providerName, "unknown")
    }
}
