using Dungeon.Api;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection.Extensions;


internal static class QaHost
{
 public static async Task Main(string[] args)
 {
// Dedicated test executable, not referenced or copied by the production Dockerfile.
// SQLite is a contract-test store only. The shipped API's provider is PostgreSQL.
var root = Environment.GetEnvironmentVariable("DUNGEON_AMD_QA_ROOT");
if (string.IsNullOrWhiteSpace(root) || !Directory.Exists(root)) throw new InvalidOperationException("Explicit existing QA root required");
var dbPath = Path.Combine(Path.GetFullPath(root), "synthetic-contract-test.db");
var app = global::Program.Build(args, builder =>
{
    builder.Services.RemoveAll<DbContextOptions<GameDb>>();
    builder.Services.RemoveAll<IDbContextOptionsConfiguration<GameDb>>();
    builder.Services.AddDbContext<GameDb>(options => options.UseSqlite($"Data Source={dbPath}"));
    builder.WebHost.UseUrls("http://127.0.0.1:5086");
});
await using (var scope = app.Services.CreateAsyncScope())
    await scope.ServiceProvider.GetRequiredService<GameDb>().Database.EnsureCreatedAsync();
// A fixed delayed endpoint belongs ONLY to this synthetic QA executable.
app.MapGet("/api/qa/delay", async (CancellationToken ct) => { await Task.Delay(2000, ct); return Results.Ok(new { delayed = true }); });
await app.RunAsync();

 }
}
