CREATE TABLE "Session" (
    "sessionId" TEXT NOT NULL UNIQUE,
    "data" JSON,
    "expiry" DATETIME
)