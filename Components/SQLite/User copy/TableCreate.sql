CREATE TABLE "Group" (
    "Name"	TEXT NOT NULL,
    "Group"	TEXT NOT NULL,
    PRIMARY KEY("Name"),
    FOREIGN KEY("Name") REFERENCES "User"("Name")
)