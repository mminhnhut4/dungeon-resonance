using Microsoft.EntityFrameworkCore;
using System.Text.Json;

namespace Dungeon.Api;

public sealed class ProgressService(GameDb db, TimeProvider time)
{
    public async Task<CloudProgress> Read(Guid user, CancellationToken ct)
    {
        var row = await db.Progress.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == user, ct)
            ?? throw new DomainFailure(404, "no_cloud_progress");
        var capsule = JsonSerializer.Deserialize<CloudCapsule>(row.CapsuleJson, CapsulePolicy.Json)!;
        return new(row.Revision, row.UpdatedAt, capsule, CapsulePolicy.ValidateStored(capsule));
    }
    public async Task<SaveResult> Save(Guid user, Guid operation, SaveProgress request, CancellationToken ct)
    {
        if (operation == Guid.Empty || request.ExpectedRevision < 0 || request.ExpectedRevision == long.MaxValue)
            throw new DomainFailure(422, "invalid_revision_or_operation");
        CapsulePolicy.Validate(request.Capsule);
        var fingerprint = CapsulePolicy.Fingerprint(request);
        var replay = await Replay(user, operation, fingerprint, ct);
        if (replay is not null) return replay;
        await using var tx = await db.Database.BeginTransactionAsync(ct);
        var row = await db.Progress.SingleOrDefaultAsync(x => x.UserId == user, ct);
        if ((row?.Revision ?? 0) != request.ExpectedRevision)
        {
            // A concurrent identical operation may have committed after the
            // first receipt lookup but before this row read (READ COMMITTED).
            replay = await Replay(user, operation, fingerprint, ct);
            if (replay is not null) return replay;
            throw new DomainFailure(409, "revision_conflict");
        }
        if (row is null) { row = new() { UserId = user }; db.Progress.Add(row); }
        row.Revision++;
        row.UpdatedAt = time.GetUtcNow().UtcDateTime;
        row.CapsuleJson = JsonSerializer.Serialize(request.Capsule, CapsulePolicy.Json);
        db.Receipts.Add(new() { UserId = user, OperationId = operation, Fingerprint = fingerprint, Revision = row.Revision });
        try
        {
            await db.SaveChangesAsync(ct);
            await tx.CommitAsync(ct);
            return new(row.Revision, row.Revision, false);
        }
        catch (DbUpdateException e) when (e is DbUpdateConcurrencyException || e.InnerException is Npgsql.PostgresException { SqlState: "23505" })
        {
            await tx.RollbackAsync(ct); await tx.DisposeAsync(); db.ChangeTracker.Clear();
            replay = await Replay(user, operation, fingerprint, ct);
            if (replay is not null) return replay;
            throw new DomainFailure(409, "concurrent_save_conflict");
        }
    }
    private async Task<SaveResult?> Replay(Guid user, Guid operation, string fingerprint, CancellationToken ct)
    {
        var receipt = await db.Receipts.AsNoTracking().SingleOrDefaultAsync(x => x.UserId == user && x.OperationId == operation, ct);
        if (receipt is null) return null;
        if (receipt.Fingerprint != fingerprint) throw new DomainFailure(409, "operation_key_reuse");
        var current = await db.Progress.AsNoTracking().Where(x => x.UserId == user).Select(x => x.Revision).SingleAsync(ct);
        return new(receipt.Revision, current, true);
    }
}
