//
//  ExplainPlanViewModel.swift
//  PostgresGUI
//

import Foundation

@Observable
@MainActor
final class ExplainPlanViewModel {
    enum State {
        case idle
        case loading
        case loaded(ExplainPlanResult)
        case error(String)
    }

    var state: State = .idle
    /// Original SQL the user asked us to explain — kept for the sheet header.
    var sourceSQL: String = ""

    private let service: ExplainPlanServiceProtocol

    init(service: ExplainPlanServiceProtocol) {
        self.service = service
    }

    func explain(sql: String) async {
        sourceSQL = sql
        state = .loading
        do {
            let result = try await service.explain(sql: sql)
            state = .loaded(result)
        } catch {
            state = .error((error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    /// Resets the sheet so it can be re-presented on a new query.
    func reset() {
        state = .idle
        sourceSQL = ""
    }
}
