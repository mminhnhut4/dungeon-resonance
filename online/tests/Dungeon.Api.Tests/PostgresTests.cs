using System.Net;
using System.Net.Http.Json;
using Dungeon.Api;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Npgsql;
using Xunit;

namespace Dungeon.Api.Tests;

public sealed class PostgresFactAttribute : FactAttribute
{
    public PostgresFactAttribute()
    {
        if (string.IsNullOrWhiteSpace(Environment.GetEnvironmentVariable("AMD201_TEST_PG")))
            Skip = "PostgreSQL runtime/explicit synthetic database is not approved or configured (AMD201_TEST_PG).";
    }
}
public sealed class PostgresHost : WebApplicationFactory<Program>
{
    public readonly string Schema = "qa_" + Guid.NewGuid().ToString("N");
    private string Connection => Environment.GetEnvironmentVariable("AMD201_TEST_PG") ?? throw new InvalidOperationException("Explicit test database required");
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        var config = new NpgsqlConnectionStringBuilder(Connection) { SearchPath = Schema };
        builder.UseEnvironment("Testing");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<GameDb>>(); services.RemoveAll<IDbContextOptionsConfiguration<GameDb>>();
            services.AddDbContext<GameDb>(x => x.UseNpgsql(config.ConnectionString));
        });
    }
    public async Task<HttpClient> Start()
    {
        await using var connection = new NpgsqlConnection(Connection); await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = $"CREATE SCHEMA {Schema}"; await command.ExecuteNonQueryAsync();
        var client = CreateClient();
        await using var scope = Services.CreateAsyncScope();
        await scope.ServiceProvider.GetRequiredService<GameDb>().Database.MigrateAsync();
        return client;
    }
    public async Task DropSyntheticSchema()
    {
        await using var connection = new NpgsqlConnection(Connection); await connection.OpenAsync();
        await using var command = connection.CreateCommand();
        command.CommandText = $"DROP SCHEMA {Schema} CASCADE"; await command.ExecuteNonQueryAsync();
    }
}
public sealed class PostgresTests
{
    [PostgresFact] public async Task MigrationsConcurrentWritersAndOwnerReloadUseRealPostgres()
    {
        using var host = new PostgresHost(); using var a = await host.Start();
        try
        {
            var token = await Sample.Login(a, "pg-alpha@amd.test");
            using var second = host.CreateClient();
            second.DefaultRequestHeaders.Authorization = a.DefaultRequestHeaders.Authorization;
            var initial = await Task.WhenAll(Sample.Save(a, Guid.NewGuid(), 0, 21), Sample.Save(second, Guid.NewGuid(), 0, 29));
            Assert.Single(initial, x => x.StatusCode == HttpStatusCode.OK);
            Assert.Single(initial, x => x.StatusCode == HttpStatusCode.Conflict);
            var saved = (await a.GetFromJsonAsync<CloudProgress>("/api/progress"))!;
            Assert.Equal(1, saved.Revision); Assert.Contains(saved.Summary.Souls, new long[] { 21, 29 });
            var key = Guid.NewGuid();
            var repeated = await Task.WhenAll(Sample.Save(a, key, 1, 33), Sample.Save(second, key, 1, 33));
            Assert.All(repeated, x => Assert.Equal(HttpStatusCode.OK, x.StatusCode));
            Assert.Equal(2, (await second.GetFromJsonAsync<CloudProgress>("/api/progress"))!.Revision);
            using var b = host.CreateClient(); await Sample.Login(b, "pg-beta@amd.test");
            Assert.Equal(HttpStatusCode.NotFound, (await b.GetAsync("/api/progress")).StatusCode);
            // A new DbContext/HTTP request reloads the same committed bytes.
            Assert.Equal(33, (await a.GetFromJsonAsync<CloudProgress>("/api/progress"))!.Summary.Souls);
        }
        finally { await host.DropSyntheticSchema(); }
    }
}
