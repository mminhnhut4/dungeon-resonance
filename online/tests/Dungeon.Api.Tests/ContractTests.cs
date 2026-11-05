using System.Net;
using System.Net.Http.Headers;
using System.Net.Http.Json;
using System.Text.Json;
using Dungeon.Api;
using Microsoft.AspNetCore.Hosting;
using Microsoft.AspNetCore.Mvc.Testing;
using Microsoft.Data.Sqlite;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Infrastructure;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.DependencyInjection.Extensions;
using Xunit;

namespace Dungeon.Api.Tests;

public sealed class ContractHost : WebApplicationFactory<Program>
{
    private readonly SqliteConnection connection = new("Data Source=:memory:");
    public ContractHost() => connection.Open();
    protected override void ConfigureWebHost(IWebHostBuilder builder)
    {
        builder.UseEnvironment("Testing");
        builder.ConfigureServices(services =>
        {
            services.RemoveAll<DbContextOptions<GameDb>>();
            services.RemoveAll<IDbContextOptionsConfiguration<GameDb>>();
            services.AddDbContext<GameDb>(x => x.UseSqlite(connection));
        });
    }
    public HttpClient Start()
    {
        var client = CreateClient();
        using var scope = Services.CreateScope();
        scope.ServiceProvider.GetRequiredService<GameDb>().Database.EnsureCreated();
        return client;
    }
    protected override void Dispose(bool disposing) { base.Dispose(disposing); if (disposing) connection.Dispose(); }
}
public static class Sample
{
    public static CloudCapsule Capsule(int souls = 12)
    {
        var profile = "{\"version\":2,\"souls\":" + souls + ",\"coins\":7}";
        var npc = "{\"npc_schema\":8,\"tick\":0,\"records\":{}}";
        return new(1, "synthetic-contract-test", 2, new() { ["profile"] = new(profile, CapsulePolicy.Hash(profile)), ["npc"] = new(npc, CapsulePolicy.Hash(npc)) });
    }
    public static CloudCapsule WithFileBytes(CloudCapsule capsule, string key, int size)
    {
        var text = capsule.Files[key].Text;
        text += new string(' ', size - System.Text.Encoding.UTF8.GetByteCount(text));
        var files = capsule.Files.ToDictionary(x => x.Key, x => x.Value);
        files[key] = new(text, CapsulePolicy.Hash(text));
        return capsule with { Files = files };
    }
    public static async Task<string> Login(HttpClient client, string email)
    {
        var input = new Credentials(email, "Synthetic test passphrase 42");
        var registered = await client.PostAsJsonAsync("/api/auth/register", input);
        Assert.Equal(HttpStatusCode.Created, registered.StatusCode);
        var result = await client.PostAsJsonAsync("/api/auth/login", input);
        result.EnsureSuccessStatusCode();
        var token = (await result.Content.ReadFromJsonAsync<JsonElement>()).GetProperty("accessToken").GetString()!;
        client.DefaultRequestHeaders.Authorization = new AuthenticationHeaderValue("Bearer", token);
        return token;
    }
    public static Task<HttpResponseMessage> Save(HttpClient client, Guid operation, long revision, int souls = 12)
    {
        var message = new HttpRequestMessage(HttpMethod.Put, "/api/progress") { Content = JsonContent.Create(new SaveProgress(revision, Capsule(souls))) };
        message.Headers.Add("Idempotency-Key", operation.ToString());
        return client.SendAsync(message);
    }
}
public sealed class PolicyTests
{
    [Fact] public void OpaqueUtf8AndSummaryArePreserved()
    {
        var capsule = Sample.Capsule(18);
        var summary = CapsulePolicy.Validate(capsule);
        Assert.Equal(18, summary.Souls); Assert.Equal(7, summary.Coins);
        var round = JsonSerializer.Deserialize<CloudCapsule>(JsonSerializer.Serialize(capsule, CapsulePolicy.Json), CapsulePolicy.Json)!;
        Assert.Equal(capsule.Files["profile"].Text, round.Files["profile"].Text);
    }
    [Fact] public void CorruptionAndFutureSchemaAreRejected()
    {
        var value = Sample.Capsule();
        Assert.Equal("unsupported_schema", Assert.Throws<DomainFailure>(() => CapsulePolicy.Validate(value with { SchemaVersion = 999 })).Code);
        value.Files["npc"] = value.Files["npc"] with { Text = "changed" };
        Assert.Equal("digest_mismatch", Assert.Throws<DomainFailure>(() => CapsulePolicy.Validate(value)).Code);
    }
    [Fact] public void IdempotencyFingerprintIgnoresFileKeyOrderButIncludesRevision()
    {
        var a = Sample.Capsule(); var b = a with { Files = a.Files.Reverse().ToDictionary(x => x.Key, x => x.Value) };
        Assert.Equal(CapsulePolicy.Fingerprint(new(0, a)), CapsulePolicy.Fingerprint(new(0, b)));
        Assert.NotEqual(CapsulePolicy.Fingerprint(new(0, a)), CapsulePolicy.Fingerprint(new(1, a)));
    }
    [Fact] public void OversizedSaveIsBounded()
    {
        var a = Sample.Capsule(); var text = new string('x', CapsulePolicy.MaximumBytes + 1);
        a.Files["profile"] = new(text, CapsulePolicy.Hash(text));
        Assert.Equal(413, Assert.Throws<DomainFailure>(() => CapsulePolicy.Validate(a)).Status);
    }
    [Theory]
    [InlineData("profile", -1)] [InlineData("profile", 0)] [InlineData("profile", 1)]
    [InlineData("npc", -1)] [InlineData("npc", 0)] [InlineData("npc", 1)]
    public void EachFileMatchesGodotReaderByteBoundary(string key, int offset)
    {
        var limit = key == "profile" ? CapsulePolicy.MaximumProfileBytes : CapsulePolicy.MaximumNpcBytes;
        var capsule = Sample.WithFileBytes(Sample.Capsule(), key, limit + offset);
        if (offset <= 0) Assert.Equal(12, CapsulePolicy.Validate(capsule).Souls);
        else
        {
            var error = Assert.Throws<DomainFailure>(() => CapsulePolicy.Validate(capsule));
            Assert.Equal(413, error.Status); Assert.Equal("capsule_file_too_large", error.Code);
        }
    }
    [Fact] public void FileLimitCountsUtf8BytesAndBothMaximumFilesAreAccepted()
    {
        var capsule = Sample.WithFileBytes(Sample.WithFileBytes(Sample.Capsule(), "profile", CapsulePolicy.MaximumProfileBytes), "npc", CapsulePolicy.MaximumNpcBytes);
        Assert.Equal(12, CapsulePolicy.Validate(capsule).Souls);
        var text = "{\"version\":2,\"note\":\"" + new string('đ', CapsulePolicy.MaximumProfileBytes / 2) + "\"}";
        capsule.Files["profile"] = new(text, CapsulePolicy.Hash(text));
        Assert.True(text.Length < CapsulePolicy.MaximumProfileBytes);
        Assert.Equal(413, Assert.Throws<DomainFailure>(() => CapsulePolicy.Validate(capsule)).Status);
    }
}
public sealed class HttpContractTests
{
    [Theory] [InlineData("profile")] [InlineData("npc")]
    public async Task LegacyCloudBytesRemainReadableAndRejectedUploadDoesNotOverwriteThem(string key)
    {
        using var host = new ContractHost(); using var client = host.Start();
        await Sample.Login(client, "legacy@amd.test");
        var limit = key == "profile" ? CapsulePolicy.MaximumProfileBytes : CapsulePolicy.MaximumNpcBytes;
        var legacy = Sample.WithFileBytes(Sample.Capsule(41), key, limit + 1);
        var storedJson = JsonSerializer.Serialize(legacy, CapsulePolicy.Json);
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GameDb>();
            db.Progress.Add(new() { UserId = (await db.Accounts.SingleAsync()).Id, Revision = 3, UpdatedAt = DateTime.UtcNow, CapsuleJson = storedJson });
            await db.SaveChangesAsync();
        }
        var read = (await client.GetFromJsonAsync<CloudProgress>("/api/progress"))!;
        Assert.Equal(3, read.Revision); Assert.Equal(legacy.Files[key].Text, read.Capsule.Files[key].Text);
        var request = new HttpRequestMessage(HttpMethod.Put, "/api/progress") { Content = JsonContent.Create(new SaveProgress(3, legacy)) };
        request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        Assert.Equal(HttpStatusCode.RequestEntityTooLarge, (await client.SendAsync(request)).StatusCode);
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GameDb>();
            var row = await db.Progress.SingleAsync();
            Assert.Equal(3, row.Revision); Assert.Equal(storedJson, row.CapsuleJson); Assert.Empty(await db.Receipts.ToListAsync());
        }
        // A subsequent valid upload still follows the existing revision contract.
        Assert.Equal(HttpStatusCode.OK, (await Sample.Save(client, Guid.NewGuid(), 3, 42)).StatusCode);
        Assert.Equal(4, (await client.GetFromJsonAsync<CloudProgress>("/api/progress"))!.Revision);
    }
    [Fact] public async Task PrivateProgressRequiresSessionAndUnknownApiIs404()
    {
        using var host = new ContractHost(); using var client = host.Start();
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/progress")).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/api/not-a-route")).StatusCode);
    }
    [Fact] public async Task OwnershipIsAlwaysTakenFromAuthenticatedSession()
    {
        using var host = new ContractHost(); using var a = host.Start(); using var b = host.CreateClient();
        await Sample.Login(a, "alpha@amd.test"); await Sample.Login(b, "beta@amd.test");
        (await Sample.Save(a, Guid.NewGuid(), 0, 44)).EnsureSuccessStatusCode();
        Assert.Equal(HttpStatusCode.NotFound, (await b.GetAsync("/api/progress")).StatusCode);
        (await Sample.Save(b, Guid.NewGuid(), 0, 9)).EnsureSuccessStatusCode();
        Assert.Equal(44, (await a.GetFromJsonAsync<CloudProgress>("/api/progress"))!.Summary.Souls);
        Assert.Equal(9, (await b.GetFromJsonAsync<CloudProgress>("/api/progress"))!.Summary.Souls);
    }
    [Fact] public async Task LostResponseRetryIsIdempotentAndStaleWritersCannotOverwrite()
    {
        using var host = new ContractHost(); using var client = host.Start(); await Sample.Login(client, "retry@amd.test");
        var key = Guid.NewGuid();
        Assert.Equal(1, (await (await Sample.Save(client, key, 0)).Content.ReadFromJsonAsync<SaveResult>())!.Revision);
        var replay = (await (await Sample.Save(client, key, 0)).Content.ReadFromJsonAsync<SaveResult>())!;
        Assert.True(replay.Replayed); Assert.Equal(1, replay.CurrentRevision);
        Assert.Equal(HttpStatusCode.Conflict, (await Sample.Save(client, Guid.NewGuid(), 0, 999)).StatusCode);
        Assert.Equal(HttpStatusCode.Conflict, (await Sample.Save(client, key, 0, 999)).StatusCode);
        (await Sample.Save(client, Guid.NewGuid(), 1, 21)).EnsureSuccessStatusCode();
        replay = (await (await Sample.Save(client, key, 0)).Content.ReadFromJsonAsync<SaveResult>())!;
        Assert.Equal(1, replay.Revision); Assert.Equal(2, replay.CurrentRevision);
        Assert.Equal(21, (await client.GetFromJsonAsync<CloudProgress>("/api/progress"))!.Summary.Souls);
    }
    [Fact] public async Task LogoutRevokesTokenAndPasswordsAreNeverStoredInPlaintext()
    {
        using var host = new ContractHost(); using var client = host.Start(); await Sample.Login(client, "logout@amd.test");
        using (var scope = host.Services.CreateScope())
        {
            var db = scope.ServiceProvider.GetRequiredService<GameDb>();
            Assert.DoesNotContain("Synthetic", (await db.Accounts.SingleAsync()).PasswordHash);
            Assert.NotEqual(client.DefaultRequestHeaders.Authorization!.Parameter, (await db.Sessions.SingleAsync()).TokenHash);
        }
        Assert.Equal(HttpStatusCode.NoContent, (await client.PostAsync("/api/auth/logout", null)).StatusCode);
        Assert.Equal(HttpStatusCode.Unauthorized, (await client.GetAsync("/api/me")).StatusCode);
    }
    [Fact] public async Task InvalidPayloadAndRepeatedRegisterHaveExplicitStatusCodes()
    {
        using var host = new ContractHost(); using var client = host.Start();
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await client.PostAsJsonAsync("/api/auth/register", new Credentials("x@amd.test", "short"))).StatusCode);
        await Sample.Login(client, "validation@amd.test");
        Assert.Equal(HttpStatusCode.Conflict, (await client.PostAsJsonAsync("/api/auth/register", new Credentials("validation@amd.test", "Synthetic test passphrase 42"))).StatusCode);
        var bad = new SaveProgress(0, Sample.Capsule() with { SchemaVersion = 9 });
        var request = new HttpRequestMessage(HttpMethod.Put, "/api/progress") { Content = JsonContent.Create(bad) };
        request.Headers.Add("Idempotency-Key", Guid.NewGuid().ToString());
        Assert.Equal(HttpStatusCode.UnprocessableEntity, (await client.SendAsync(request)).StatusCode);
        Assert.Equal(HttpStatusCode.NotFound, (await client.GetAsync("/api/progress")).StatusCode);
    }
}
