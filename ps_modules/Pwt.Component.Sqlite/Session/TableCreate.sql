CREATE TABLE "Session" (
    "sessionId" TEXT NOT NULL UNIQUE PRIMARY KEY,
    "data" JSON,
    "expiry" DATETIME
)