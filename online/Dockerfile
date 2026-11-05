# Prepared only; Docker is not installed/run on the development PC.
FROM node:24-bookworm-slim AS portal
WORKDIR /web
COPY web/package.json web/pnpm-lock.yaml ./
RUN npm install --global pnpm@11.25.0 && pnpm install --frozen-lockfile --ignore-scripts
COPY web/index.html web/vite.config.js ./
COPY web/src ./src
RUN pnpm build

FROM mcr.microsoft.com/dotnet/sdk:9.0 AS api
WORKDIR /source
COPY src/Dungeon.Api/Dungeon.Api.csproj src/Dungeon.Api/packages.lock.json ./
RUN dotnet restore --locked-mode
COPY src/Dungeon.Api/ ./
RUN dotnet publish --no-restore -c Release -o /out /p:UseAppHost=false
COPY --from=portal /src/Dungeon.Api/wwwroot /out/wwwroot

FROM mcr.microsoft.com/dotnet/aspnet:9.0-bookworm-slim AS runtime
WORKDIR /app
COPY --from=api /out ./
ENV ASPNETCORE_HTTP_PORTS=8080
USER $APP_UID
EXPOSE 8080
ENTRYPOINT ["dotnet", "Dungeon.Api.dll"]
