#!/usr/bin/env python3

import os
import re
import shlex
import shutil
import subprocess
import sys
from pathlib import Path


# ============================================================
# Configuration
# ============================================================

SSH_ROOT = Path.home() / ".ssh"
REPO_KEYS_ROOT = SSH_ROOT / "github-repos"


# ============================================================
# Helpers
# ============================================================

def die(message, code=1):
    print(f"\nError: {message}")
    sys.exit(code)


def run(command, *, capture=False, check=True):
    """
    Run a command and optionally capture stdout/stderr.
    """
    print(f"  $ {' '.join(shlex.quote(str(x)) for x in command)}")

    return subprocess.run(
        command,
        check=check,
        text=True,
        capture_output=capture,
    )


def command_exists(command):
    return shutil.which(command) is not None


def parse_github_url(url):
    """
    Accept:

        git@github.com:OWNER/REPO.git
        git@github.com:OWNER/REPO
        https://github.com/OWNER/REPO.git
        https://github.com/OWNER/REPO
        ssh://git@github.com/OWNER/REPO.git

    Returns:

        OWNER, REPO
    """

    patterns = [
        r"^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$",
        r"^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?$",
        r"^ssh://git@github\.com/([^/]+)/([^/]+?)(?:\.git)?$",
    ]

    for pattern in patterns:
        match = re.fullmatch(pattern, url)

        if match:
            owner = match.group(1)
            repo = match.group(2)

            repo = repo.removesuffix(".git")

            return owner, repo

    raise ValueError(
        "Unsupported GitHub repository URL.\n\n"
        "Examples:\n"
        "  git@github.com:OWNER/REPO.git\n"
        "  https://github.com/OWNER/REPO.git\n"
        "  ssh://git@github.com/OWNER/REPO.git"
    )


def ensure_directory(path, mode=0o700):
    path.mkdir(parents=True, exist_ok=True)

    try:
        os.chmod(path, mode)
    except PermissionError:
        pass


def configure_permissions(private_key, public_key):
    if private_key.exists():
        os.chmod(private_key, 0o600)

    if public_key.exists():
        os.chmod(public_key, 0o644)


def generate_key(private_key, owner, repo):
    """
    Generate an Ed25519 key without a passphrase.

    The key is intentionally generated without a passphrase because
    this script is designed for non-interactive git pull/push operations.
    """

    print("\nGenerating SSH key...")

    run(
        [
            "ssh-keygen",
            "-t",
            "ed25519",
            "-f",
            str(private_key),
            "-C",
            f"github-deploy-{owner}-{repo}",
            "-N",
            "",
        ]
    )

    configure_permissions(
        private_key,
        Path(f"{private_key}.pub"),
    )

    print("✓ SSH key generated.")


def get_public_key(public_key):
    if not public_key.exists():
        die(f"Public key does not exist:\n  {public_key}")

    return public_key.read_text().strip()


def test_github_key(private_key):
    """
    Test the exact key against GitHub.

    We deliberately specify:
      -i <private key>
      -o IdentitiesOnly=yes

    so SSH cannot accidentally authenticate using another key.
    """

    print("\nTesting GitHub SSH authentication...")
    print(f"Using key:\n  {private_key}")

    command = [
        "ssh",
        "-i",
        str(private_key),
        "-o",
        "IdentitiesOnly=yes",
        "-o",
        "BatchMode=yes",
        "-o",
        "StrictHostKeyChecking=accept-new",
        "-T",
        "git@github.com",
    ]

    result = subprocess.run(
        command,
        text=True,
        capture_output=True,
    )

    output = (result.stdout + result.stderr).strip()

    if "successfully authenticated" in output:
        print("✓ GitHub SSH authentication succeeded.")
        return True

    print("\nSSH authentication failed.")
    print()
    print(output)

    return False


def build_ssh_command(private_key):
    """
    Build the command that Git will store in .git/config.

    Example:

        ssh -i /home/user/.ssh/github-repos/foo/bar/id_ed25519 \
            -o IdentitiesOnly=yes
    """

    return (
        f"ssh "
        f"-i {shlex.quote(str(private_key))} "
        f"-o IdentitiesOnly=yes"
    )


def configure_repository(repo_dir, private_key):
    """
    Configure only this repository.

    This writes:

        repo/.git/config

    and does NOT affect global Git configuration.
    """

    ssh_command = build_ssh_command(private_key)

    print("\nConfiguring repository-specific SSH...")

    run(
        [
            "git",
            "-C",
            str(repo_dir),
            "config",
            "--local",
            "core.sshCommand",
            ssh_command,
        ]
    )

    print("✓ Repository-specific SSH configured.")


def get_git_config(repo_dir, key):
    result = subprocess.run(
        [
            "git",
            "-C",
            str(repo_dir),
            "config",
            "--local",
            "--get",
            key,
        ],
        text=True,
        capture_output=True,
    )

    if result.returncode != 0:
        return None

    return result.stdout.strip()


def print_summary(repo_dir, private_key):
    ssh_command = get_git_config(
        repo_dir,
        "core.sshCommand",
    )

    print()
    print("=" * 64)
    print(" DONE")
    print("=" * 64)
    print()
    print("Repository:")
    print(f"  {repo_dir}")
    print()
    print("SSH key:")
    print(f"  {private_key}")
    print()
    print("Git SSH command:")
    print(f"  {ssh_command}")
    print()
    print("Remote:")
    subprocess.run(
        [
            "git",
            "-C",
            str(repo_dir),
            "remote",
            "-v",
        ]
    )
    print()
    print("From this repository or ANY subdirectory:")
    print()
    print("  git pull")
    print("  git push")
    print("  git fetch")
    print()
    print("will use this repository's dedicated SSH key.")
    print()


# ============================================================
# Main
# ============================================================

def main():
    if len(sys.argv) != 2:
        print(
            f"Usage:\n"
            f"  {Path(sys.argv[0]).name} <github-repository-url>\n"
        )

        print("Example:")
        print(
            f"  {Path(sys.argv[0]).name} "
            "git@github.com:leanderziehm/phone-usage-app.git"
        )

        sys.exit(1)

    repo_url = sys.argv[1]

    # --------------------------------------------------------
    # Check dependencies
    # --------------------------------------------------------

    print("\nChecking dependencies...")

    for command in ("git", "ssh", "ssh-keygen"):
        if not command_exists(command):
            die(
                f"Required command '{command}' was not found.\n"
                f"Please install it and try again."
            )

    print("✓ git")
    print("✓ ssh")
    print("✓ ssh-keygen")

    # --------------------------------------------------------
    # Parse repository
    # --------------------------------------------------------

    try:
        owner, repo = parse_github_url(repo_url)
    except ValueError as exc:
        die(str(exc))

    # --------------------------------------------------------
    # Paths
    # --------------------------------------------------------

    key_dir = REPO_KEYS_ROOT / owner / repo

    private_key = key_dir / "id_ed25519"
    public_key = key_dir / "id_ed25519.pub"

    clone_dir = Path.cwd() / repo

    github_repo_url = (
        f"git@github.com:{owner}/{repo}.git"
    )

    print()
    print("=" * 64)
    print(" GitHub per-repository SSH setup")
    print("=" * 64)
    print()
    print("Repository:")
    print(f"  {owner}/{repo}")
    print()
    print("Clone directory:")
    print(f"  {clone_dir}")
    print()
    print("Private key:")
    print(f"  {private_key}")
    print()

    # --------------------------------------------------------
    # Create directories
    # --------------------------------------------------------

    ensure_directory(SSH_ROOT, 0o700)
    ensure_directory(REPO_KEYS_ROOT, 0o700)
    ensure_directory(REPO_KEYS_ROOT / owner, 0o700)
    ensure_directory(key_dir, 0o700)

    # --------------------------------------------------------
    # Generate or reuse key
    # --------------------------------------------------------

    if private_key.exists():
        print("An SSH key already exists for this repository:")
        print()
        print(f"  {private_key}")
        print()

        answer = (
            input("Use the existing key? [Y/n] ")
            .strip()
            .lower()
        )

        if answer and answer != "y":
            print("Aborted.")
            sys.exit(0)

        configure_permissions(
            private_key,
            public_key,
        )

        print("✓ Using existing SSH key.")

    else:
        generate_key(
            private_key,
            owner,
            repo,
        )

    # --------------------------------------------------------
    # Display public key
    # --------------------------------------------------------

    public_key_text = get_public_key(public_key)

    print()
    print("=" * 64)
    print(" ADD THIS DEPLOY KEY TO GITHUB")
    print("=" * 64)
    print()
    print("Open:")
    print()
    print(
        f"  https://github.com/{owner}/{repo}/settings/keys"
    )
    print()
    print("Then:")
    print()
    print("  1. Click 'Add deploy key'")
    print("  2. Give it a name, e.g. 'dev machine'")
    print("  3. Paste the public key below")
    print("  4. ENABLE 'Allow write access'")
    print()
    print("Public key:")
    print()
    print(public_key_text)
    print()
    print("=" * 64)
    print()

    input(
        "Press ENTER after you have added the deploy key to GitHub..."
    )

    # --------------------------------------------------------
    # Test authentication
    # --------------------------------------------------------

    if not test_github_key(private_key):
        print()
        print("The key was not accepted by GitHub.")
        print()
        print("Check that:")
        print()
        print("  • You added the key to the correct repository")
        print("  • You pasted the complete public key")
        print("  • 'Allow write access' is enabled")
        print()
        print("You can run this script again later.")
        sys.exit(1)

    # --------------------------------------------------------
    # Clone
    # --------------------------------------------------------

    if clone_dir.exists():
        print()
        print("Clone directory already exists:")
        print()
        print(f"  {clone_dir}")
        print()

        if not (clone_dir / ".git").is_dir():
            die(
                "The directory exists but does not appear to be "
                "a Git repository."
            )

        print("✓ Existing Git repository detected.")

    else:
        print()
        print("Cloning repository...")
        print()

        run(
            [
                "git",
                "clone",
                github_repo_url,
                str(clone_dir),
            ]
        )

        print()
        print("✓ Repository cloned.")

    # --------------------------------------------------------
    # Configure local Git SSH
    # --------------------------------------------------------

    configure_repository(
        clone_dir,
        private_key,
    )

    # --------------------------------------------------------
    # Verify configuration
    # --------------------------------------------------------

    configured_command = get_git_config(
        clone_dir,
        "core.sshCommand",
    )

    if not configured_command:
        die(
            "Could not verify the repository's "
            "core.sshCommand configuration."
        )

    # --------------------------------------------------------
    # Verify remote
    # --------------------------------------------------------

    remote_result = subprocess.run(
        [
            "git",
            "-C",
            str(clone_dir),
            "remote",
            "get-url",
            "origin",
        ],
        text=True,
        capture_output=True,
    )

    if remote_result.returncode != 0:
        die("Could not read the repository's origin remote.")

    # --------------------------------------------------------
    # Final output
    # --------------------------------------------------------

    print_summary(
        clone_dir,
        private_key,
    )


if __name__ == "__main__":
    main()
