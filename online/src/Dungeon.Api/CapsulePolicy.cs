using System.Security.Cryptography;
using System.Text;
using System.Text.Json;

namespace Dungeon.Api;

/// Opaque UTF8 documents preserve the Godot numeric seal and the NPC companion.
/// This is private backup, not an anti-cheat authority. Godot validates its own
/// seal/UID/life schema again before activating a restored local slot.
public static class CapsulePolicy
{
    public const int MaximumBytes = 1_048_576;
    public static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);
    public static string Hash(string value) => Convert.ToHexString(SHA256.HashData(Encoding.UTF8.GetBytes(value))).ToLowerInvariant();
    public static ProgressSummary Validate(CloudCapsule? capsule)
    {
        if (capsule is null || capsule.SchemaVersion != 1 || capsule.ProfileSchema is not (1 or 2))
            throw new DomainFailure(422, "unsupported_schema");
        if (string.IsNullOrWhiteSpace(capsule.GameBuild) || capsule.GameBuild.Length > 128 || capsule.Files is null ||
            capsule.Files.Count != 2 || !capsule.Files.ContainsKey("profile") || !capsule.Files.ContainsKey("npc"))
            throw new DomainFailure(422, "invalid_capsule");
        long bytes = 0;
        foreach (var file in capsule.Files.Values)
        {
            if (file is null || file.Text is null || file.Sha256 is null || file.Sha256.Length != 64)
                throw new DomainFailure(422, "invalid_file");
            bytes += Encoding.UTF8.GetByteCount(file.Text);
            if (bytes > MaximumBytes) throw new DomainFailure(413, "capsule_too_large");
            if (!string.Equals(Hash(file.Text), file.Sha256, StringComparison.Ordinal))
                throw new DomainFailure(422, "digest_mismatch");
        }
        try
        {
            using var profile = JsonDocument.Parse(capsule.Files["profile"].Text, new() { MaxDepth = 64 });
            using var npc = JsonDocument.Parse(capsule.Files["npc"].Text, new() { MaxDepth = 64 });
            var root = profile.RootElement;
            if (root.ValueKind != JsonValueKind.Object || Number(root, "version") != capsule.ProfileSchema ||
                npc.RootElement.ValueKind != JsonValueKind.Object || Number(npc.RootElement, "npc_schema") is < 1 or > 8)
                throw new DomainFailure(422, "invalid_game_document");
            long floor = 0;
            if (root.TryGetProperty("event_extensions", out var ext) && ext.TryGetProperty("namespaces", out var scopes))
            {
                if (scopes.TryGetProperty("depth_expedition_v1", out var depth) && depth.TryGetProperty("state", out var state))
                    floor = Math.Min(Number(state, "cleared"), 27) + 3;
                if (scopes.TryGetProperty("member_dungeon_v1", out var member) && member.TryGetProperty("state", out state))
                    floor = Math.Max(floor, Number(state, "cleared"));
            }
            long realm = 0;
            if (root.TryGetProperty("cultivation_progress", out var track) && track.TryGetProperty("actors", out var actors) && actors.TryGetProperty("player", out var player))
                realm = Number(player, "stage");
            var items = 0;
            if (root.TryGetProperty("hub_inventory", out var inventory) && inventory.TryGetProperty("items", out var list) && list.ValueKind == JsonValueKind.Array)
                items = list.GetArrayLength();
            return new(Number(root, "souls"), Number(root, "coins"), (int)Math.Clamp(floor, 0, 30), (int)Math.Clamp(realm, 0, 3), items);
        }
        catch (Exception e) when (e is JsonException or InvalidOperationException or FormatException or OverflowException)
        { throw new DomainFailure(422, "invalid_game_document"); }
    }
    private static long Number(JsonElement element, string key)
    {
        if (!element.TryGetProperty(key, out var item)) return 0;
        if (!item.TryGetDouble(out var value) || !double.IsFinite(value) || value < 0 || value > 9_007_199_254_740_991 || Math.Truncate(value) != value)
            throw new DomainFailure(422, "invalid_game_number");
        return (long)value;
    }
    public static string Fingerprint(SaveProgress request) => Hash(JsonSerializer.Serialize(new
    {
        request.ExpectedRevision, request.Capsule.SchemaVersion, request.Capsule.ProfileSchema,
        request.Capsule.GameBuild,
        Files = request.Capsule.Files.OrderBy(x => x.Key, StringComparer.Ordinal).Select(x => new { x.Key, x.Value.Sha256 })
    }, Json));
}
