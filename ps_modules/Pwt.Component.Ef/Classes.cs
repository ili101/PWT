using System.ComponentModel.DataAnnotations;
using System.Collections.Generic;

namespace Pwt.Ef
{
    public class User
    {
        public string Username { get; set; }
        public string Password { get; set; }
        public Theme Theme { get; set; }

        [Required]
        public string Name { get; set; }

        [Required]
        public string Email { get; set; }

        [Required]
        public string AuthenticationType { get; set; }
        public virtual List<Group> Groups { get; set; }
    }

    public class Group
    {
        public string GroupName { get; set; }
        public virtual List<User> Users { get; set; }
    }

    public enum Theme
    {
        Default,
        Auto,
        Light,
        Dark,
        Terminal
    }
}

/*
        # if (!$Config.ContainsKey('Components')) {
        #     $Config['Components'] = @{}
        # }
        # if (!$Config['Components'].ContainsKey('SQLite')) {
        #     $Config['Components']['SQLite'] = @{}
        # }
        # $Config['Components']['SQLite']['Enable'] = $true
        # if ($SettingsPage) {
        #     $Config['Components']['SQLite']['SettingsPage'] = $true
        # }
        # if ($AdminPage) {
        #     $Config['Components']['SQLite']['AdminPage'] = $true
        # }


        <#
        "Username" TEXT NOT NULL UNIQUE PRIMARY KEY,
        "Password" TEXT,
        "Theme" TEXT,
        "Name" TEXT NOT NULL,
        "Email" TEXT NOT NULL,
        "AuthenticationType" TEXT NOT NULL
        #>
        <#
        Class User {
            [string]$Username
            [string]$Password
            [string]$Theme
            [string]$Name
            [string]$Email
            [string]$AuthenticationType
            [System.Collections.Generic.List[Group]]$Groups
        }
        #>


        <#
        CREATE TABLE "Group" (
            "GroupName"	TEXT NOT NULL UNIQUE PRIMARY KEY
        )
        #>
        <#
        Class Group {
            [string]$GroupName
            [System.Collections.Generic.List[User]]$Users
        }
        #>


        <#
        CREATE TABLE "UserGroup" (
            "Username"	TEXT NOT NULL,
            "GroupName"	TEXT NOT NULL,
            PRIMARY KEY("Username", "GroupName"),
            FOREIGN KEY("Username") REFERENCES "User"("Username"),
            FOREIGN KEY("GroupName") REFERENCES "Group"("GroupName")
        )
        #>
        <#
        Class UserGroup {
            [string]$Username
            [string]$GroupName
        }
        #>
 */
