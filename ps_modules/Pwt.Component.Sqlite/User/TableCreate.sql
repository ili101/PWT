CREATE TABLE "User" (
    "Username" TEXT NOT NULL UNIQUE PRIMARY KEY,
    "Password" TEXT,
    "Theme" TEXT,
    "Name" TEXT NOT NULL,
    "Email" TEXT NOT NULL,
    "AuthenticationType" TEXT NOT NULL

    -- "ConfText" TEXT,
    -- "ConfInt" INT,
    -- "ConfBool" BOOLEAN
)