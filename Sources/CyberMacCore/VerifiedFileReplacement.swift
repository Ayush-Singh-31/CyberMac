import Foundation

/// Prints a manual command; CyberMac never executes it against the game.
/// Clone beside the source and verify before placing on the same volume. A
/// rename replaces an existing target; an exclusive hard link creates a new
/// target without overwriting a collision. The source inode is never installed.
enum VerifiedFileReplacement {
    static func command(source: String, target: String, sha256: String, requiresAdministrator: Bool = true,
                        requiresAbsentDestination: Bool = false) -> String {
        let ownership = requiresAdministrator ? "sudo /usr/sbin/chown root:wheel \"$payload\"" : ":"
        let placement = (requiresAdministrator ? "sudo " : "") +
            (requiresAbsentDestination ? "/bin/ln \"$payload\" \"$target\"" : "/bin/mv -f \"$payload\" \"$target\"")
        let script = """
        set -eu
        source=\(PathSafety.shellQuoted(source))
        target=\(PathSafety.shellQuoted(target))
        expected=\(PathSafety.shellQuoted(sha256))
        fail() { printf '%s\\n' "$1" >&2; exit 1; }
        [ -f "$source" ] && [ ! -L "$source" ] || fail 'Replacement source is not a regular file.'
        [ ! -L "$target" ] && [ ! -d "$target" ] || fail 'Destination is a symlink or directory.'
        [ "$(/usr/bin/stat -f %d "$source")" = "$(/usr/bin/stat -f %d "${target%/*}")" ] || fail 'Replacement must stay on the same volume.'
        temporary=$(/usr/bin/mktemp -d "${source%/*}/.cybermac-place.XXXXXX")
        payload="$temporary/payload"
        trap '/bin/rm -f "$payload"; /bin/rmdir "$temporary"' EXIT
        /bin/cp -c "$source" "$payload"
        actual=$(/usr/bin/openssl dgst -sha256 -r "$payload")
        [ "${actual%% *}" = "$expected" ] || fail 'Replacement hash does not match; destination was left unchanged.'
        /bin/chmod 644 "$payload"
        \(ownership)
        \(placement)
        actual=$(/usr/bin/openssl dgst -sha256 -r "$target")
        [ "${actual%% *}" = "$expected" ] || fail 'Installed file failed verification.'
        """
        return "/bin/sh -c \(PathSafety.shellQuoted(script))"
    }
}
