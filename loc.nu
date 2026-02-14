module loc {
    # Parse a single file and return its extension and line counts.
    # Tracks block comments (/* */, {- -}, <!-- -->) and line comments (#, //, --)
    def count_lines [path: string]: nothing -> record {
        let parsed = $path | path parse
        let ext = if ($parsed.extension | is-empty) { $parsed.stem } else { $parsed.extension }

        let stats = try {
            let lines = open --raw $path | lines
            let total = $lines | length
            let blanks = $lines | where ($it | str trim | is-empty) | length

            let openers = ['/*' '{-' '<!--']
            let closers = ['*/' '-}' '-->']
            let singles = ['#' '//' '--']

            mut comments = 0
            mut in_block = false
            mut idx = 0

            for line in $lines {
                let t = $line | str trim
                if $in_block {
                    $comments += 1
                    if ($closers | get $idx | $t | str ends-with $in) { $in_block = false }
                } else {
                    let m = $openers | enumerate | where {|it| $t | str starts-with $it.item } | first
                    if ($m | is-not-empty) {
                        $comments += 1
                        $idx = $m.index
                        if not ($t | str ends-with ($closers | get $idx)) { $in_block = true }
                    } else if ($singles | any {|p| $t | str starts-with $p }) {
                        $comments += 1
                    }
                }
            }

            { lines: $total code: ($total - $blanks - $comments) comments: $comments blanks: $blanks }
        } catch {
            { lines: 0 code: 0 comments: 0 blanks: 0 }
        }

        { ext: $ext lines: $stats.lines code: $stats.code comments: $stats.comments blanks: $stats.blanks }
    }

    # build a summary row from aggregated data
    def summary [label: string, rows: table]: nothing -> record {
        let l = $rows.Lines | math sum
        let c = $rows.Code | math sum
        {
            Extension: $label
            Files: ($rows.Files | math sum)
            Lines: $l
            Code: $c
            Comments: ($rows.Comments | math sum)
            Blanks: ($rows.Blanks | math sum)
            Density: (if $l > 0 { ($c / $l) * 100 | math round --precision 1 } else { 0 })
        }
    }

    # Count lines of code, comments, and blanks grouped by file extension
    # Pipe file paths into it: `git ls-files | lines | loc`
    export def main [
        --top (-t): int # show only the top N extensions
    ] {
        let input = $in
        if ($input == null) or ($input | is-empty) {
            error make { msg: "pipe a list of file paths into loc (e.g. `git ls-files | lines | loc`)" }
        }

        # normalize records (e.g. from `ls`) to plain path strings
        let paths = $input | each {|it|
            if ($it | describe | str starts-with "record") { $it.name } else { $it }
        }

        # single `file` call to filter out binaries
        let sources = (
            file --brief --mime ...$paths
            | lines
            | zip $paths
            | where { $in.0 | str contains "charset=binary" | not $in }
            | each { $in.1 }
        )

        # count lines, blanks, and comments per file
        let counts = $sources | par-each {|path| count_lines $path }

        # aggregate by extension
        let data = (
            $counts
            | group-by ext
            | transpose Extension rows
            | insert Files { $in.rows | length }
            | insert Lines { $in.rows.lines | math sum }
            | insert Code { $in.rows.code | math sum }
            | insert Comments { $in.rows.comments | math sum }
            | insert Blanks { $in.rows.blanks | math sum }
            | insert Density {
                if $in.Lines > 0 {
                    ($in.Code / $in.Lines) * 100 | math round --precision 1
                } else { 0 }
            }
            | select Extension Files Lines Code Comments Blanks Density
            | sort-by -r Code
        )

        if $top != null and $top < ($data | length) {
            let shown = $data | first $top
            $shown
            | append (summary "Shown" $shown)
            | append (summary "Total" $data)
        } else {
            $data | append (summary "Total" $data)
        }
    }
}

use loc
