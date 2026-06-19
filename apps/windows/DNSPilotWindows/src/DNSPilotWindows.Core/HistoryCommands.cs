namespace DNSPilotWindows.Core;

public sealed record BenchmarkHistoryPersistence(string DatabasePath, string HistoryId)
{
    public IReadOnlyList<string> CommandArguments => new[]
    {
        "--save-db",
        DatabasePath,
        "--history-id",
        HistoryId,
    };
}

public static class HistoryManagementCommands
{
    public static IReadOnlyList<string> List(string databasePath)
    {
        return new[] { "history-list", "--db", databasePath };
    }

    public static IReadOnlyList<string> Delete(string databasePath, string historyId)
    {
        return new[] { "history-delete", "--db", databasePath, "--id", historyId };
    }

    public static IReadOnlyList<string> Clear(string databasePath)
    {
        return new[] { "history-clear", "--db", databasePath };
    }
}
