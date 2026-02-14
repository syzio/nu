# Nushell Tools

Random useful Nushell scripts.

## Install

```nu
mkdir ($nu.data-dir | path join "vendor/autoload")
```

## Scripts

### loc.nu

Lines of code counter. Counts code, comments, and blanks grouped by file extension.

```nu
http get https://raw.githubusercontent.com/syzio/nu/main/loc.nu
    | save --force ($nu.data-dir | path join "vendor/autoload/oizys.loc.nu")
```

Pipe file paths into it:

```nu
git ls-files | lines | loc
glob **/*.rs | loc
ls src/ | loc
loc --top 5
```
