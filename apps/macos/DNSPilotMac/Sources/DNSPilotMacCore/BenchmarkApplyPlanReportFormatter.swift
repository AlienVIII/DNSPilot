public enum BenchmarkApplyPlanReportFormatter {
    public static func appendApplyPlan(
        outcome: BenchmarkApplyPlanLoadOutcome?,
        isLoading: Bool,
        to report: String
    ) -> String {
        if isLoading {
            return [
                report,
                "",
                "Apply policy",
                "Apply policy: checking",
            ].joined(separator: "\n")
        }

        switch outcome {
        case .loaded(let viewModel):
            return [
                report,
                "",
                "Apply policy",
                viewModel.copyText,
            ].joined(separator: "\n")
        case .failed(let message):
            return [
                report,
                "",
                "Apply policy",
                "Apply policy unavailable",
                message,
            ].joined(separator: "\n")
        case nil:
            return report
        }
    }
}
