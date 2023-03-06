CREATE TABLE "UserGroup" (
    "Username"	TEXT NOT NULL,
    "GroupName"	TEXT NOT NULL,
    PRIMARY KEY("Username", "GroupName"),
    FOREIGN KEY("Username") REFERENCES "User"("Username"),
    FOREIGN KEY("GroupName") REFERENCES "Group"("GroupName")
)