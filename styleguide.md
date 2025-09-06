Bash Style Guide
================

This guide distills best practices, pitfalls, and advanced techniques for robust, maintainable, and idiomatic Bash scripts. It is written in a direct, example-driven style, with rationale and references where appropriate.

Preface
-------

Good Bash style reduces bugs and increases maintainability. This guide is explicit: every rule is justified, and exceptions are noted. Though good style alone won't ensure that your scripts are free from error, it can certainly help narrow the scope for bugs to exist.

---

Aesthetics
----------

### Tabs / Spaces

Tabs.

### Columns

Not to exceed 80.

### Semicolons

Avoid using semicolons in scripts unless required in control statements (e.g., if, while).

```bash
# wrong
name='dave';
echo "hello $name";

# right
name='dave'
echo "hello $name"
```

The exception to this rule is outlined in the `Block Statements` section below. Namely, semicolons should be used for control statements like `if` or `while`.

### Functions

Don't use the `function` keyword. All variables created in a function should be made local.

```bash
# wrong
function foo {
    i=foo # this is now global, wrong depending on intent
}

# right
foo() {
    local i=foo # this is local, preferred
}
```

### Block Statements

`then` should be on the same line as `if`, and `do` should be on the same line as `while`.

```bash
# wrong
if true
then
    ...
fi

# also wrong, though admittedly looks kinda cool
true && {
    ...
}

# right
if true; then
    ...
fi
```

### Spacing

No more than 2 consecutive newline characters (ie. no more than 1 blank line in a row).

### Comments

No explicit style guide for comments. Don't change someone's comments for aesthetic reasons unless you are rewriting or updating them.

---

General Principles
------------------

- Prefer Bash built-ins and parameter expansion over external commands.
- Use arrays for lists, especially when elements may contain spaces or special characters.
- Always quote variables: `"$var"`, `"$@"`, `"${array[@]}"`.
- Use `local` for variables inside functions.
- Split `local var=$(cmd)` into two lines to preserve exit codes.

---

Shebang
-------

Use `#!/usr/bin/env bash` for portability.

```bash
#!/usr/bin/env bash
```

Unless you’re intentionally targeting a specific environment (e.g. `/bin/bash` on Linux servers with restricted PATHs).

---

Quoting & Word Splitting
------------------------

- Always quote variable expansions unless you are intentionally splitting.
- Use `"$@"` to loop over arguments, not `$*` or `$@` unquoted.
- Use double quotes for strings that require variable expansion or command substitution interpolation, and single quotes for all others.
- Use single quotes to prevent variable expansion, double quotes to allow it.
- Escape single quotes inside single-quoted strings by closing, inserting `'\''`, and reopening.
- Use here-docs (`<<EOF`) for multi-line strings; quote the delimiter to prevent expansion.

```bash
# wrong
echo $var

# right
echo "$var"

# single quote inside single quotes
echo 'It'\''s fine'
```

All variables that will undergo word-splitting *must* be quoted. If no splitting will happen, the variable may remain unquoted.

```bash
foo='hello world'

if [[ -n $foo ]]; then   # no quotes needed: [[ ... ]] won't word-split variable expansions
    echo "$foo"          # quotes needed
fi

bar=$foo  # no quotes needed - variable assignment doesn't word-split
```

When in doubt; [quote all expansions](http://mywiki.wooledge.org/Quotes).

---

Arrays and Lists
----------------

- Use arrays for lists of items, not space-separated strings.
- Expand arrays with `"${array[@]}"` to preserve elements.
- Count array elements with `${#array[@]}`.

```bash
# wrong
modules='json httpserver jshint'
for module in $modules; do
    npm install -g "$module"
done

# right
modules=(json httpserver jshint)
for module in "${modules[@]}"; do
    npm install -g "$module"
done

# or, if the command supports multiple arguments:
npm install -g "${modules[@]}"
```

- Use associative arrays for key-value data (Bash 4+).

---

Globbing & File Loops
---------------------

- Use Bash globs (`for f in files/*`) instead of parsing `ls` output.
- Enable `shopt -s nullglob` to avoid literal globs when no files match.
- Quote variables in file loops to handle spaces and newlines.

```bash
# wrong
for f in $(ls); do
    ...
done

# right
shopt -s nullglob
for f in *; do
    echo "$f"
done
```

Never parse the output of `ls` in scripts.

---

Reading Files & Input
---------------------

- Use `while IFS= read -r line; do ...; done < file` to read files line by line.
- Avoid `for line in $(cat file)`; it splits on whitespace, not lines.
- Use `mapfile` (or `readarray`) to read files into arrays efficiently.
- Use `mapfile -t` to trim trailing newlines.

```bash
# wrong
for line in $(cat file); do
    echo "$line"
done

# right
while IFS= read -r line; do
    echo "$line"
done < file

# also right
mapfile -t lines < file
```

---

Command Substitution & Pipelines
--------------------------------

- Prefer `$(...)` over backticks for command substitution.
- Avoid nesting backticks; use `$(...)` for clarity.
- Check pipeline exit codes with `${PIPESTATUS[@]}`.
- Use `set -o pipefail` if you want the pipeline to fail on any command failure.

```bash
# wrong
foo=`date`

# right
foo=$(date)

# pipeline exit codes
set -o pipefail
cmd1 | cmd2
echo "${PIPESTATUS[@]}"
```

---

Parameter Expansion & String Manipulation
-----------------------------------------

- Use curly braces for parameter expansion when needed.
- Use `${var:-default}` for default values.
- Use `${var//search/replace}` for string replacement.
- Use `${var#pattern}` and `${var%pattern}` for trimming.
- Use `${var,,}` and `${var^^}` for case conversion (Bash 4+).
- Use `${var:offset:length}` for substrings.
- For negative offsets, use a space after the colon (`${var: -2}`).

```bash
name='bahamas10'
prog=${0##*/}
nonumbers=${name//[0-9]/}
lower=${name,,}
upper=${name^^}
sub=${name:1:4}
```

Always prefer parameter expansion over external commands like `echo`, `sed`, `awk`, etc.

---

Functions & Scope
-----------------

- Declare functions as `name() { ... }`.
- Use `local` for function-local variables.
- Assign output to a variable first, then declare it local to preserve exit codes.
- Use parentheses to run a function in a subshell for isolation.

```bash
foo() {
    local result
    result=$(cmd)
}

# subshell
(bar)
```

---

Return Codes & Error Handling
-----------------------------

- Check command exit codes with `$?` immediately after the command.
- In pipelines, use `${PIPESTATUS[@]}`.
- Use `set -e` with caution; it can cause scripts to exit unexpectedly.

```bash
cd /some/path || exit
rm file
```

---

Signals, Traps & Job Control
----------------------------

- Use `trap` to handle signals like SIGINT and SIGTERM.
- SIGKILL (`kill -9`) cannot be trapped or ignored.
- Use `&` to run commands in the background.
- Use `jobs` to list background jobs.
- Use `kill %1` to send signals to jobs by job ID.
- Only the shell builtin `kill` understands job IDs like `%1`.
- Use `fg` and `bg` to bring jobs to the foreground or background.
- Zombie processes are caused by parents not reaping children; use `wait`.

```bash
trap 'echo "Interrupted"; exit' SIGINT
sleep 100 &
jobs
kill %1
wait
```

---

Environment Variables
---------------------

- Use `export` to make variables available to child processes.
- Non-exported variables are not visible to external commands.
- Use `env` to view the current environment.
- On Linux, `/proc/self/environ` shows the environment of the current process.

```bash
export FOO=bar
env | grep FOO
cat /proc/self/environ | tr '\0' '\n'
```

---

IO Redirection
--------------

- Redirect output with `>`, errors with `2>`.
- Redirect both stdout and stderr with `&> file` or `> file 2>&1`.
- Order matters when redirecting.
- Use `sudo tee` to write to root-owned files.
- Use `tee` to write output to both a file and the terminal.

```bash
# wrong
sudo echo foo > /root/file

# right
echo foo | sudo tee /root/file

# both stdout and stderr
cmd &> out.txt
```

---

SSH & Remote Commands
---------------------

- Be careful with quoting and variable expansion when running commands over SSH.
- Use single quotes to prevent local expansion, double quotes for remote expansion.
- Use `ssh host command` for remote execution.
- Use `ssh -L` for local port forwarding.
- Use SSH keys and the SSH agent for passwordless authentication.
- Prefer passing data via stdin or files for complex arguments.

```bash
ssh user@host 'echo $HOME'
ssh -L 8080:localhost:80 user@host
```

---

Prompt Customization
--------------------

- Customize the prompt with the `PS1` variable.
- `PS2` is the continuation prompt.
- Use `PS4` for customizing trace output.

```bash
PS1='\u@\h:\w\$ '
PS4='+ '
```

---

Special Characters & Strings
----------------------------

- Use `echo -e` or `$'...'` to interpret escape sequences.
- Store special characters in variables using `$'...'`.

```bash
echo -e "foo\nbar"
newline=$'\n'
```

---

Miscellaneous
-------------

- Read the Bash man page and use `help` for built-in documentation.
- Use `type`, `type -a`, and `help` to distinguish built-ins, functions, and external commands.
- Use `man` for external commands, `help` for shell builtins.
- Be aware of differences between GNU and BSD utilities.
- Use `isatty` (`-t 1`) to check if output is a terminal.
- Use `trap` for cleanup on script exit or interruption.
- Use `set -x` or `bash -x` for debugging scripts.
- Use `jq` or similar tools for JSON manipulation.
- Use `env -i` to run a command with a clean environment.
- Use `xargs` with `-d` for safe argument passing, especially over SSH.
- Use `find ... -print0` and `xargs -0` to handle filenames with special characters.
- Use associative arrays for key-value data (Bash 4+).
- Never parse the output of `ls` in scripts.
- Use `while read -r` instead of `while read` to prevent backslash interpretation.
- Use `IFS` carefully; limit its scope.
- Use `jobs`, `fg`, `bg`, and `%` job specifiers for interactive job control.
- Use `tput smcup` and `tput rmcup` to enter and exit the terminal alternate screen.
- Use `date` and `printf` for date/time formatting.

---

Security & Safety
-----------------

- Never source untrusted configuration files. Parse config files safely to avoid executing arbitrary code.
- Do not run dangerous commands like fork bombs. Understand their effects and use safeguards when experimenting.

---

Common Mistakes
---------------

### Using {} instead of quotes.

Using `${f}` is potentially different than `"$f"` because of how word-splitting is performed. For example:

```bash
for f in '1 space' '2  spaces' '3   spaces'; do
    echo ${f}
done
```

yields:

```
1 space
2 spaces
3 spaces
```

Notice that it loses the amount of spaces. This is due to the fact that the variable is expanded and undergoes word-splitting because it is unquoted.

If the variable was quoted instead:

```bash
for f in '1 space' '2  spaces' '3   spaces'; do
    echo "$f"
done
```

yields:

```
1 space
2  spaces
3   spaces
```

Note that, for the most part `$f` is the same as `${f}` and `"$f"` is the same as `"${f}"`. The curly braces should only be used to ensure the variable name is expanded properly.

### Abusing for-loops when while would work better

`for` loops are great for iteration over arguments, or arrays. Newline separated data is best left to a `while read -r ...` loop.

```bash
users=$(awk -F: '{print $1}' /etc/passwd)
for user in $users; do
    echo "user is $user"
done
```

This approach has a lot of issues if used on other files with data that may contain spaces or tabs.

To rewrite this:

```bash
while IFS=: read -r user _; do
    echo "$user is user"
done < /etc/passwd
```

This will read the file in a streaming fashion, not pulling it all into memory,
and will break on colons extracting the first field and discarding (storing as
the variable `_`) the rest - using nothing but bash builtin commands.

- [YSAP038](https://ysap.sh/v/38/)

---

References
----------

- [YSAP](https://ysap.sh)
- [BashGuide](https://mywiki.wooledge.org/BashGuide)
- [BashPitFalls](http://mywiki.wooledge.org/BashPitfalls)
- [Bash Practices](http://mywiki.wooledge.org/BashGuide/Practices)

Get This Guide
--------------

- `curl style.ysap.sh` - View this guide in your terminal.
- `curl style.ysap.sh/plain` - View this guide without color in your terminal.
- `curl style.ysap.sh/md` - Get the raw markdown.
- [Website](https://style.ysap.sh) - Dedicated website for this guide.
- [GitHub](https://github.com/bahamas10/bash-style-guide) - View the source.

License
-------

MIT License
