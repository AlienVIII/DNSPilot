public enum BenchmarkApplyPlanReportFormatter {
    public static func appendApplyPlan(
        outcome: BenchmarkApplyPlanLoadOutcome?,
        isLoading: Bool,
        restoreSnapshot: SystemDNSResolverSnapshot? = nil,
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
            var lines = [
                report,
                "",
                "Apply policy",
                viewModel.copyText,
            ]
            if let restoreSnapshot {
                lines += [
                    "",
                    GuidedApplyRestoreViewModel(snapshot: restoreSnapshot).copyText,
                ]
            }
            return lines.joined(separator: "\n")
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
