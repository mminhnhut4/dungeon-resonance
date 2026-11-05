CREATE TABLE IF NOT EXISTS "__EFMigrationsHistory" (
    "MigrationId" character varying(150) NOT NULL,
    "ProductVersion" character varying(32) NOT NULL,
    CONSTRAINT "PK___EFMigrationsHistory" PRIMARY KEY ("MigrationId")
);

START TRANSACTION;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261030131148_InitialAccountProgress') THEN
    CREATE TABLE "Accounts" (
        "Id" uuid NOT NULL,
        "Email" character varying(254) NOT NULL,
        "NormalizedEmail" character varying(254) NOT NULL,
        "PasswordHash" text NOT NULL,
        CONSTRAINT "PK_Accounts" PRIMARY KEY ("Id")
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261030131148_InitialAccountProgress') THEN
    CREATE TABLE "Progress" (
        "UserId" uuid NOT NULL,
        "Revision" bigint NOT NULL,
        "CapsuleJson" text NOT NULL,
        "UpdatedAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Progress" PRIMARY KEY ("UserId"),
        CONSTRAINT "FK_Progress_Accounts_UserId" FOREIGN KEY ("UserId") REFERENCES "Accounts" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261030131148_InitialAccountProgress') THEN
    CREATE TABLE "Receipts" (
        "UserId" uuid NOT NULL,
        "OperationId" uuid NOT NULL,
        "Fingerprint" character varying(64) NOT NULL,
        "Revision" bigint NOT NULL,
        CONSTRAINT "PK_Receipts" PRIMARY KEY ("UserId", "OperationId"),
        CONSTRAINT "FK_Receipts_Accounts_UserId" FOREIGN KEY ("UserId") REFERENCES "Accounts" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261030131148_InitialAccountProgress') THEN
    CREATE TABLE "Sessions" (
        "Id" uuid NOT NULL,
        "UserId" uuid NOT NULL,
        "TokenHash" character varying(64) NOT NULL,
        "ExpiresAt" timestamp with time zone NOT NULL,
        CONSTRAINT "PK_Sessions" PRIMARY KEY ("Id"),
        CONSTRAINT "FK_Sessions_Accounts_UserId" FOREIGN KEY ("UserId") REFERENCES "Accounts" ("Id") ON DELETE CASCADE
    );
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261030131148_InitialAccountProgress') THEN
    CREATE UNIQUE INDEX "IX_Accounts_NormalizedEmail" ON "Accounts" ("NormalizedEmail");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261030131148_InitialAccountProgress') THEN
    CREATE INDEX "IX_Sessions_ExpiresAt" ON "Sessions" ("ExpiresAt");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261030131148_InitialAccountProgress') THEN
    CREATE UNIQUE INDEX "IX_Sessions_TokenHash" ON "Sessions" ("TokenHash");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261030131148_InitialAccountProgress') THEN
    CREATE INDEX "IX_Sessions_UserId" ON "Sessions" ("UserId");
    END IF;
END $EF$;

DO $EF$
BEGIN
    IF NOT EXISTS(SELECT 1 FROM "__EFMigrationsHistory" WHERE "MigrationId" = '20261030131148_InitialAccountProgress') THEN
    INSERT INTO "__EFMigrationsHistory" ("MigrationId", "ProductVersion")
    VALUES ('20261030131148_InitialAccountProgress', '9.0.22');
    END IF;
END $EF$;
COMMIT;
