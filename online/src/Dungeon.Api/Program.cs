using Dungeon.Api;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Identity;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;
using System.Threading.RateLimiting;

public partial class Program
{
    public static async Task Main(string[] args)
    {
        var app = Build(args.Where(x => x != "--migrate").ToArray());
        if (args.Contains("--migrate"))
        {
            await using var scope = app.Services.CreateAsyncScope();
            await scope.ServiceProvider.GetRequiredService<GameDb>().Database.MigrateAsync();
            return;
        }
        await app.RunAsync();
    }
    public static WebApplication Build(string[] args, Action<WebApplicationBuilder>? testServices = null)
    {
        var builder = WebApplication.CreateBuilder(args);
        var passwordFile = Environment.GetEnvironmentVariable("AMD201_DB_PASSWORD_FILE");
        if (!string.IsNullOrWhiteSpace(passwordFile))
        {
            var connection = new Npgsql.NpgsqlConnectionStringBuilder(builder.Configuration.GetConnectionString("Game")
                ?? "Host=127.0.0.1;Database=dungeon;Username=dungeon");
            connection.Password = File.ReadAllText(passwordFile).TrimEnd('\r', '\n');
            builder.Configuration["ConnectionStrings:Game"] = connection.ConnectionString;
        }
        builder.WebHost.ConfigureKestrel(x => x.Limits.MaxRequestBodySize = 2_097_152);
        builder.Services.AddDbContext<GameDb>(x => x.UseNpgsql(builder.Configuration.GetConnectionString("Game")
            ?? "Host=127.0.0.1;Database=dungeon;Username=dungeon;Timeout=3"));
        builder.Services.AddSingleton(TimeProvider.System);
        builder.Services.Configure<PasswordHasherOptions>(x => x.IterationCount = 300_000);
        builder.Services.AddScoped<IPasswordHasher<PlayerAccount>, PasswordHasher<PlayerAccount>>();
        builder.Services.AddScoped<AccountService>(); builder.Services.AddScoped<ProgressService>();
        builder.Services.AddAuthentication(SessionAuthentication.SchemeName).AddScheme<AuthenticationSchemeOptions, SessionAuthentication>(SessionAuthentication.SchemeName, _ => { });
        builder.Services.AddAuthorization();
        builder.Services.AddRateLimiter(x =>
        {
            x.RejectionStatusCode = 429;
            x.AddPolicy("auth", context => RateLimitPartition.GetFixedWindowLimiter(context.Connection.RemoteIpAddress?.ToString() ?? "loopback", _ => new() { PermitLimit = 12, Window = TimeSpan.FromMinutes(1), QueueLimit = 0 }));
        });
        testServices?.Invoke(builder);
        var app = builder.Build();
        app.Use(async (ctx, next) =>
        {
            ctx.Response.Headers.CacheControl = "no-store";
            ctx.Response.Headers.XContentTypeOptions = "nosniff";
            ctx.Response.Headers["Referrer-Policy"] = "no-referrer";
            ctx.Response.Headers["Content-Security-Policy"] = "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none'; base-uri 'self'";
            try { await next(); }
            catch (DomainFailure e) { await Results.Problem(statusCode: e.Status, title: e.Code).ExecuteAsync(ctx); }
            catch (BadHttpRequestException e) { await Results.Problem(statusCode: e.StatusCode, title: e.StatusCode == 413 ? "request_too_large" : "invalid_request").ExecuteAsync(ctx); }
            catch (OperationCanceledException) when (ctx.RequestAborted.IsCancellationRequested) { }
            catch (Exception e)
            {
                // Do not log bodies, tokens, credentials, connection strings or save data.
                app.Logger.LogError("Request failed: {Type}", e.GetType().Name);
                await Results.Problem(statusCode: 503, title: "service_temporarily_unavailable").ExecuteAsync(ctx);
            }
        });
        app.UseRateLimiter(); app.UseAuthentication(); app.UseAuthorization();
        app.MapGet("/health", () => Results.Ok(new { status = "ok" }));
        app.MapGet("/health/ready", async (GameDb db, CancellationToken ct) => await db.Database.CanConnectAsync(ct) ? Results.Ok(new { status = "ready" }) : Results.StatusCode(503));
        var auth = app.MapGroup("/api/auth");
        auth.MapPost("/register", async (Credentials body, AccountService service, CancellationToken ct) =>
            Results.Created("/api/me", new { id = await service.Register(body, ct) })).RequireRateLimiting("auth");
        auth.MapPost("/login", async (Credentials body, AccountService service, CancellationToken ct) => Results.Ok(await service.Login(body, ct))).RequireRateLimiting("auth");
        auth.MapPost("/logout", async (ClaimsPrincipal principal, GameDb db, CancellationToken ct) =>
        {
            var id = Guid.Parse(principal.FindFirstValue("session_id")!);
            await db.Sessions.Where(x => x.Id == id).ExecuteDeleteAsync(ct); return Results.NoContent();
        }).RequireAuthorization();
        app.MapGet("/api/me", async (ClaimsPrincipal principal, GameDb db, CancellationToken ct) =>
        {
            var id = Guid.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)!);
            return await db.Accounts.Where(x => x.Id == id).Select(x => new { x.Id, x.Email }).SingleAsync(ct);
        }).RequireAuthorization();
        app.MapGet("/api/progress", async (ClaimsPrincipal principal, ProgressService service, HttpResponse response, CancellationToken ct) =>
        {
            var result = await service.Read(Guid.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)!), ct);
            response.Headers.ETag = $"\"rev-{result.Revision}\""; return Results.Ok(result);
        }).RequireAuthorization();
        app.MapPut("/api/progress", async (ClaimsPrincipal principal, SaveProgress body, ProgressService service, HttpRequest request, HttpResponse response, CancellationToken ct) =>
        {
            if (!Guid.TryParse(request.Headers["Idempotency-Key"], out var operation)) throw new DomainFailure(422, "idempotency_key_required");
            var result = await service.Save(Guid.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)!), operation, body, ct);
            response.Headers.ETag = $"\"rev-{result.CurrentRevision}\""; return Results.Ok(result);
        }).RequireAuthorization();
        app.MapGet("/api/progress/summary", async (ClaimsPrincipal principal, ProgressService service, CancellationToken ct) =>
        {
            var result = await service.Read(Guid.Parse(principal.FindFirstValue(ClaimTypes.NameIdentifier)!), ct);
            return Results.Ok(new { result.Revision, result.UpdatedAt, result.Summary });
        }).RequireAuthorization();
        app.UseDefaultFiles(); app.UseStaticFiles();
        app.MapFallback("/api/{**path}", () => Results.Problem(statusCode: 404, title: "endpoint_not_found"));
        app.MapFallbackToFile("index.html");
        return app;
    }
}
