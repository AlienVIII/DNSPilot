export function assertNoUnresolvedExpoRoutes(output) {
  const matches = String(output ?? "")
    .split(/\r?\n/)
    .filter((line) => /No route named ["'][^"']+["'] exists/i.test(line));
  if (matches.length > 0) {
    throw new Error(`Expo Router has unresolved routes:\n${matches.join("\n")}`);
  }
}
