struct CoveRuntimePolicy: Equatable {
    let isPreviewMode: Bool

    var allowsPersistentChanges: Bool {
        !isPreviewMode
    }

    var installsSystemIntegrations: Bool {
        !isPreviewMode
    }

    var arbitratesRunningInstances: Bool {
        !isPreviewMode
    }
}
