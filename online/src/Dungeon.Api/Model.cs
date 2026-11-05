using Microsoft.EntityFrameworkCore;
using System.Text.Json.Serialization;

namespace Dungeon.Api;

public sealed class PlayerAccount
{
    public Guid Id { get; set; }
    public string Email { get; set; } = "";
    public string NormalizedEmail { get; set; } = "";
    [JsonIgnore] public string PasswordHash { get; set; } = "";
}
public sealed class AccessSession
{
    public Guid Id { get; set; }
    public Guid UserId { get; set; }
    public string TokenHash { get; set; } = "";
    public DateTime ExpiresAt { get; set; }
}
public sealed class PlayerProgress
{
    public Guid UserId { get; set; }
    public long Revision { get; set; }
    public string CapsuleJson { get; set; } = "";
    public DateTime UpdatedAt { get; set; }
}
public sealed class SaveReceipt
{
    public Guid UserId { get; set; }
    public Guid OperationId { get; set; }
    public string Fingerprint { get; set; } = "";
    public long Revision { get; set; }
}
public sealed class GameDb(DbContextOptions<GameDb> options) : DbContext(options)
{
    public DbSet<PlayerAccount> Accounts => Set<PlayerAccount>();
    public DbSet<AccessSession> Sessions => Set<AccessSession>();
    public DbSet<PlayerProgress> Progress => Set<PlayerProgress>();
    public DbSet<SaveReceipt> Receipts => Set<SaveReceipt>();
    protected override void OnModelCreating(ModelBuilder m)
    {
        m.Entity<PlayerAccount>().HasKey(x => x.Id);
        m.Entity<PlayerAccount>().Property(x => x.Email).HasMaxLength(254);
        m.Entity<PlayerAccount>().Property(x => x.NormalizedEmail).HasMaxLength(254);
        m.Entity<PlayerAccount>().HasIndex(x => x.NormalizedEmail).IsUnique();
        m.Entity<AccessSession>().HasKey(x => x.Id);
        m.Entity<AccessSession>().Property(x => x.TokenHash).HasMaxLength(64);
        m.Entity<AccessSession>().HasIndex(x => x.TokenHash).IsUnique();
        m.Entity<AccessSession>().HasIndex(x => x.ExpiresAt);
        m.Entity<AccessSession>().HasOne<PlayerAccount>().WithMany().HasForeignKey(x => x.UserId);
        m.Entity<PlayerProgress>().HasKey(x => x.UserId);
        m.Entity<PlayerProgress>().Property(x => x.Revision).IsConcurrencyToken();
        m.Entity<PlayerProgress>().HasOne<PlayerAccount>().WithMany().HasForeignKey(x => x.UserId);
        m.Entity<SaveReceipt>().HasKey(x => new { x.UserId, x.OperationId });
        m.Entity<SaveReceipt>().Property(x => x.Fingerprint).HasMaxLength(64);
        m.Entity<SaveReceipt>().HasOne<PlayerAccount>().WithMany().HasForeignKey(x => x.UserId);
    }
}
public record Credentials(string Email, string Password);
public record CapsuleFile(string Text, string Sha256);
public record CloudCapsule(int SchemaVersion, string GameBuild, int ProfileSchema, Dictionary<string, CapsuleFile> Files);
public record SaveProgress(long ExpectedRevision, CloudCapsule Capsule);
public record ProgressSummary(long Souls, long Coins, int ClearedFloor, int Realm, int Items);
public record CloudProgress(long Revision, DateTime UpdatedAt, CloudCapsule Capsule, ProgressSummary Summary);
public record SaveResult(long Revision, long CurrentRevision, bool Replayed);
public sealed class DomainFailure(int status, string code) : Exception(code)
{
    public int Status { get; } = status;
    public string Code { get; } = code;
}
