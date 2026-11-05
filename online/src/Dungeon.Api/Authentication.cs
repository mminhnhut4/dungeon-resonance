using System.ComponentModel.DataAnnotations;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text.Encodings.Web;
using Microsoft.AspNetCore.Authentication;
using Microsoft.AspNetCore.Identity;
using Microsoft.EntityFrameworkCore;
using Microsoft.Extensions.Options;

namespace Dungeon.Api;

public sealed class AccountService(GameDb db, IPasswordHasher<PlayerAccount> hasher, TimeProvider time)
{
    private static readonly PlayerAccount Dummy = new();
    private static readonly string DummyHash = new PasswordHasher<PlayerAccount>(Options.Create(new PasswordHasherOptions { IterationCount = 300_000 })).HashPassword(Dummy, "not-an-account-passphrase");
    private static string Email(string? email)
    {
        email = email?.Trim() ?? "";
        if (email.Length > 254 || !new EmailAddressAttribute().IsValid(email)) throw new DomainFailure(422, "invalid_email");
        return email.ToUpperInvariant();
    }
    public async Task<Guid> Register(Credentials input, CancellationToken ct)
    {
        var normalized = Email(input.Email);
        if (input.Password is null || input.Password.Length is < 12 or > 128) throw new DomainFailure(422, "password_length_12_to_128");
        if (await db.Accounts.AnyAsync(x => x.NormalizedEmail == normalized, ct)) throw new DomainFailure(409, "account_unavailable");
        var user = new PlayerAccount { Id = Guid.NewGuid(), Email = input.Email.Trim(), NormalizedEmail = normalized };
        user.PasswordHash = hasher.HashPassword(user, input.Password);
        db.Accounts.Add(user);
        try { await db.SaveChangesAsync(ct); }
        catch (DbUpdateException e) when (e.InnerException is Npgsql.PostgresException { SqlState: "23505" }) { throw new DomainFailure(409, "account_unavailable"); }
        return user.Id;
    }
    public async Task<object> Login(Credentials input, CancellationToken ct)
    {
        var normalized = Email(input.Email);
        if (input.Password is null || input.Password.Length > 128) throw new DomainFailure(401, "invalid_credentials");
        var user = await db.Accounts.SingleOrDefaultAsync(x => x.NormalizedEmail == normalized, ct);
        var verified = hasher.VerifyHashedPassword(user ?? Dummy, user?.PasswordHash ?? DummyHash, input.Password);
        if (user is null || verified == PasswordVerificationResult.Failed)
            throw new DomainFailure(401, "invalid_credentials");
        if (verified == PasswordVerificationResult.SuccessRehashNeeded) user.PasswordHash = hasher.HashPassword(user, input.Password);
        var bytes = RandomNumberGenerator.GetBytes(32);
        var token = Convert.ToBase64String(bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_');
        var session = new AccessSession { Id = Guid.NewGuid(), UserId = user.Id, TokenHash = CapsulePolicy.Hash(token), ExpiresAt = time.GetUtcNow().UtcDateTime.AddHours(8) };
        db.Sessions.Add(session);
        await db.Sessions.Where(x => x.ExpiresAt < time.GetUtcNow().UtcDateTime).ExecuteDeleteAsync(ct);
        await db.SaveChangesAsync(ct);
        return new { accessToken = token, tokenType = "Bearer", expiresAt = session.ExpiresAt, user = new { user.Id, user.Email } };
    }
}
public sealed class SessionAuthentication(IOptionsMonitor<AuthenticationSchemeOptions> options, ILoggerFactory logger,
    UrlEncoder encoder, GameDb db, TimeProvider time) : AuthenticationHandler<AuthenticationSchemeOptions>(options, logger, encoder)
{
    public const string SchemeName = "AccountSession";
    protected override async Task<AuthenticateResult> HandleAuthenticateAsync()
    {
        var header = Request.Headers.Authorization.ToString();
        if (!header.StartsWith("Bearer ", StringComparison.OrdinalIgnoreCase)) return AuthenticateResult.NoResult();
        var token = header[7..];
        if (token.Length != 43 || token.Any(x => !char.IsAsciiLetterOrDigit(x) && x is not '-' and not '_'))
            return AuthenticateResult.Fail("invalid_session");
        var digest = CapsulePolicy.Hash(token);
        var session = await db.Sessions.AsNoTracking().SingleOrDefaultAsync(x => x.TokenHash == digest && x.ExpiresAt > time.GetUtcNow().UtcDateTime, Context.RequestAborted);
        if (session is null) return AuthenticateResult.Fail("expired_or_revoked_session");
        var claims = new[] { new Claim(ClaimTypes.NameIdentifier, session.UserId.ToString()), new Claim("session_id", session.Id.ToString()) };
        return AuthenticateResult.Success(new AuthenticationTicket(new ClaimsPrincipal(new ClaimsIdentity(claims, SchemeName)), SchemeName));
    }
}
