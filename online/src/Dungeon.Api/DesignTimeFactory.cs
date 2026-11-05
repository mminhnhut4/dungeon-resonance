using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Design;

namespace Dungeon.Api;
public sealed class DesignTimeFactory : IDesignTimeDbContextFactory<GameDb>
{
    public GameDb CreateDbContext(string[] args) => new(new DbContextOptionsBuilder<GameDb>()
        .UseNpgsql(Environment.GetEnvironmentVariable("ConnectionStrings__Game") ?? "Host=127.0.0.1;Database=dungeon;Username=dungeon").Options);
}
