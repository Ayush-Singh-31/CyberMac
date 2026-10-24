import Foundation

/// Prints a manual command; CyberMac never executes it against the game.
/// Clone beside the source, verify it, then rename on the same volume. A failed
/// clone must never remove the destination, as `cp -c source destination` can.
enum VerifiedFileReplacement {
    static func command(source: String, target: String, sha256: String, requiresAdministrator: Bool = true) -> String {
        let ownership = requiresAdministrator ? "sudo /usr/sbin/chown root:wheel \"$payload\"" : ":"
        let move = requiresAdministrator ? "sudo /bin/mv" : "/bin/mv"
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
        actual=$(/usr/bin/shasum -a 256 "$payload")
        [ "${actual%% *}" = "$expected" ] || fail 'Replacement hash does not match; destination was left unchanged.'
        /bin/chmod 644 "$payload"
        \(ownership)
        \(move) -f "$payload" "$target"
        actual=$(/usr/bin/shasum -a 256 "$target")
        [ "${actual%% *}" = "$expected" ] || fail 'Installed file failed verification.'
        """
        return "/bin/sh -c \(PathSafety.shellQuoted(script))"
    }
}
