# Meorawr_GlueXMLInjection

This little trick takes advantage of the fact that saved variables aren't strictly sanitized upon being read into the global environment.

## Usage

Copy the `WTF` folder to the game folder and start the game up.

Upon starting the game client, you'll observe immediately a change to the login screen style. Once authenticating and getting to the character selection screen, things will get a bit more entertaining.

!["Improved" Glue Screen](https://i.imgur.com/dR8616i.jpg)

**Note:** The injection will only work one time per UI reload, however if you fiddle with permissions and prevent the client from deleting/modifying the contents of the `WTF\SavedVariables` folder then you'll be able to keep the injection active.

## Explanation

### Saved Variable Injection

Saved variables for addons are loaded into a restricted environment that has no access to the global scope. If no error occurs during the loading of the variables, the defined variables are then copied as-is to the global environment.

In the case of insecure addons, the resulting globals are always tainted upon being copied. However for secure addons, this isn't strictly the case.

Take for example the following; if we edit our `Blizzard_Commentator` saved variables with the following contents, we can observe some minor holes in the security.

```lua
-- WTF/Account/<Account ID>/SavedVariables/Blizzard_Commentator.lua
TestString = "string"
TestNumber = 500;
TestTable = {
    WithSubkeys = true,
};

TestFunction = function() end;
```

Upon loading these variables, all of the above keys will be copied to the global environment and `issecurevariable` will return `true` for all of them. The special case here is `TestFunction`; in this case the function object itself is secure however the calling it will **always** taint execution.

So at the very most, with specially crafted saved variables we can define global primitives and (nested) tables with secure values. At the moment I've not been able to trigger any escalations with this.

### GlueXML

Instead of toying with FrameXML, we can instead abuse this to get arbitrary code execution in the GlueXML layer. The one caveat is that our code will still be treated as insecure, however it seems that the majority of the GlueXML API functions don't really care about the concept of security.

The `Blizzard_Console` addon is loaded very early in the GlueXML setup process and has a few saved variables for its own console history. If we replace the contents with our own values, we're able to define our own custom globals in the same manner.

So how do we get arbitrary code execution? We need to define a function that, at some point, will be handed access (directly or indirectly) to `_G`.

Thankfully this proved to be rather easy; `Blizzard_StoreUI` (and `Blizzard_AuthChallengeUI`) are addons which are loaded after the user has gotten to the character selection screen. As part of their security setup, early on in their initialization processes they attempt to seal off their environment via a call to `setfenv(1, tbl)`. One interesting part is that while in the GlueXML layer, these explicitly set `tbl._G = _G`.

So using this information, a specially crafted saved variables file for `Blizzard_Console` lets us run untrusted/insecure code in the GlueXML layer after the user has authenticated with the server:

```lua
-- WTF/SavedVariables/Blizzard_Console.lua
setfenv = function(_, env)
    if env._G then
        env._G.C_Login.DisconnectFromServer();
    end
end
```

As a proof of concept, after logging in, this should immediately log you back out.

### Caveats: Persistence

Saved variables are replaced on each UI reload or state transition, meaning the injection only sticks around one time and has to be reinstalled each time.

This can be worked around of course by removing permissions from the `WTF` folder and its contents to prevent the client from replacing files; on Windows this should be the "Full Control" and "Modify" flags.

![Example Permissions](https://i.imgur.com/NkfFfTl.png)

## Recommendations

* The globals created by saved variables files should be restricted to just those listed inside TOC files. This would prevent overwriting unrelated globals with specially crafted files.
* Saved variable loading could additionally outright refuse to copy anything that isn't a table, string, boolean, number, or nil. Unfortunately this gets a bit complicated if you defined a function inside a table.
