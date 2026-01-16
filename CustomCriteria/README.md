# Custom Criteria for the Explorer plugin

More about Explorer plugin:  https://observatory.xjph.net/usage/plugins/explorer
More about Custom Criteria:  https://observatory.xjph.net/usage/plugins/explorer/customcriteria

Each criteria file includes a brief description of what it does. Please take a look!

## Using these files

Start with familiarizing yourself with the material here: https://observatory.xjph.net/usage/plugins/explorer/customcriteria

In particular, review the information about the criteria file. A super brief summary follows.

Custom criteria files are structured into a few different sections. First, there's a shared "Global" section marked like this:

```lua
---@Global

-- (stuff here)

---@End
```
... Note that there are multiple `---@End` markers in the file, the first one after `---@Global` denotes the end of the Global section.

Then there two styles of Criteria:

```lua
---@Complex

-- (criteria code goes here)

---@End
```

or:

```lua
---@Simple
scan.ScanType == 'NavBeaconDetail'
---@Detail
'This is a Nav Beacon scan'
```

Some of the files here have only a criteria section, others have a Global section plus one or more criteria sections.

If you don't have any custom criteria setup yet, you can just copy a `.lua` file to a folder of your choice (say `Documents\ObservatoryCustomCriteria\`).
Then, in Observatory Core, open Core Settings and enable custom criteria and then browse to that file.

You can create or edit the custom criteria `.lua` file with any basic text editor such as the Notepad app that comes with Windows.


## Adding to an existing Custom Criteria file

### Global section

If the custom criteria includes a `---@Global` section, select and copy everything **between**, but not including the `---@Global` marker and it's corresponding `---@End` marker and paste it just before the `---@End` of the Global section in your existing custom criteria file.
Ensure the `---@Global` and `---@End` are the only things on its line (so ensure it doesn't just get tagged on the end of another line, for example: `end---@End`).

### Critera sections
Copy the `---@Complex` criteria sections **INCLUDING** the `---@Complex` **AND** `---@End` markers and paste it at the very bottom of your existing custom criteria file (after the last criteria there).

## Testing your Custom Criteria

1.  Save your changes.
1.  In Observatory Core, click Read-All. This may take several minutes, depending on what other plugins you have in stalled and how many journals you have.
1.  If it finishes without showing any errors, great! You can then go to the Explorer tab, click Export and pick a file to export the content to. Open that in a text editor (like Notepad) and take a look at the results. Use the Ctrl+F key (Find in file feature) to locate occurrences of the criteria you are interested in.
1.  If it finishes with errors, you can find errors in your Documents folder in a file called ObservatoryErrorLog.txt. Hopefully the error messages there in combination with the [custom criteria documentation site](https://observatory.xjph.net/usage/plugins/explorer/customcriteria) are helpful enough to help you find the error. If you find yourself really stuck, post up in the Observatory Core discord (see below) and we'll try to help you get it sorted.

You can find the Observatory discord from the [official documentation site](https://observatory.xjph.net/)
