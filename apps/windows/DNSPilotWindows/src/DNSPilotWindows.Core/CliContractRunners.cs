namespace DNSPilotWindows.Core;

public sealed class CatalogRunner
{
    private readonly string _executablePath;
    private readonly ICliProcessRunner _processRunner;

    public CatalogRunner(string executablePath, ICliProcessRunner? processRunner = null)
    {
        _executablePath = executablePath;
        _processRunner = processRunner ?? new SystemCliProcessRunner();
    }

    public CatalogSnapshot Load()
    {
        var output = _processRunner.Run(_executablePath, new[] { "catalog" }, progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("Catalog", output);
        return CatalogJsonDecoder.Decode(output.StandardOutput);
    }
}

public sealed class CapabilityMatrixRunner
{
    private readonly string _executablePath;
    private readonly ICliProcessRunner _processRunner;

    public CapabilityMatrixRunner(string executablePath, ICliProcessRunner? processRunner = null)
    {
        _executablePath = executablePath;
        _processRunner = processRunner ?? new SystemCliProcessRunner();
    }

    public CapabilityMatrix Load()
    {
        var output = _processRunner.Run(_executablePath, new[] { "capabilities" }, progressHandler: null);
        CliContractRunnerErrors.EnsureSuccess("Capabilities", output);
        return CapabilityMatrixJsonDecoder.Decode(output.StandardOutput);
    }
}

internal static class CliContractRunnerErrors
{
    public static void EnsureSuccess(string commandName, CliProcessOutput output)
    {
        if (output.ExitCode == 0)
        {
            return;
        }

        var message = !string.IsNullOrWhiteSpace(output.StandardError)
            ? output.StandardError.Trim()
            : !string.IsNullOrWhiteSpace(output.StandardOutput)
                ? output.StandardOutput.Trim()
                : $"{commandName} command exited with code {output.ExitCode}.";
        throw new CliContractCommandException(commandName, output.ExitCode, message);
    }
}

public sealed class CliContractCommandException : InvalidOperationException
{
    public CliContractCommandException(string commandName, int exitCode, string message)
        : base(message)
    {
        CommandName = commandName;
        ExitCode = exitCode;
    }

    public string CommandName { get; }
    public int ExitCode { get; }
}
