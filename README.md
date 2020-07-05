# vault

Password manager written in BASH.

## Usage

```sh
$ vault.sh init
    # Delete all info, reset password and start from scratch.
$ vault.sh add [domain] [user] [*password]
    # Add new credentials to a domain.
    # Run with no options for interactive mode.
    # Leave password blank to auto-generate.
$ vault.sh list [search|domain] [user]
    # List all domains, search domains and users and show passwords.
$ vault.sh edit [domain] [username] [password]
    # Edit password.
    # Run with no options for interactive mode.
$ vault.sh -h, --help
    # Show this text.
```