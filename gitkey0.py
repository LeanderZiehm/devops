#!/usr/bin/env python3

import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def run(cmd, **kwargs):
    return subprocess.run(cmd, check=True, **kwargs)


def parse_github_url(url):
    patterns = [
        r"^git@github\.com:([^/]+)/([^/]+?)(?:\.git)?$",
        r"^https://github\.com/([^/]+)/([^/]+?)(?:\.git)?$",
    ]

    for pattern in patterns:
        match = re.match(pattern, url)
        if match:
            return match.group(1), match.group(2).removesuffix(".git")

    raise ValueError(
        "Unsupported GitHub URL.\n"
        "Expected:\n"
        "  git@github.com:OWNER/REPO.git\n"
        "  https://github.com/OWNER/REPO.git"
    )


def update_ssh_config(config_path, host_alias, key_file, owner, repo):
    config_path.parent.mkdir(parents=True, exist_ok=True)
    config_path.touch(exist_ok=True)
    os.chmod(config_path, 0o600)

    existing = config_path.read_text()

    # Remove an existing block for this exact Host.
    lines = existing.splitlines()
    output = []
    skip = False

    for line in lines:
        if line.startswith("Host "):
            current_host = line.split(maxsplit=1)[1]

            if current_host == host_alias:
                skip = True
                continue

            if skip:
                skip = False

        if not skip:
            output.append(line)

    block = f"""
# GitHub repository: {owner}/{repo}
Host {host_alias}
    HostName github.com
    User git
    IdentityFile {key_file}
    IdentitiesOnly yes
"""

    new_config = "\n".join(output).rstrip() + "\n" + block
    config_path.write_text(new_config)
    os.chmod(config_path, 0o600)


def test_ssh(host_alias):
    print("\nTesting SSH authentication...")

    result = subprocess.run(
        [
            "ssh",
            "-o",
            "BatchMode=yes",
            "-o",
            "StrictHostKeyChecking=accept-new",
            "-T",
            host_alias,
        ],
        capture_output=True,
        text=True,
    )

    combined = result.stdout + result.stderr

    if "successfully authenticated" in combined:
        print("✓ GitHub SSH authentication succeeded.")
        return True

    print("\nSSH authentication failed.")
    print("\nDebug output:")
    print(combined)

    return False


def main():
    if len(sys.argv) != 2:
        print(f"Usage: {sys.argv[0]} <github-repo-url>")
        print()
        print("Example:")
        print(f"  {sys.argv[0]} git@github.com:leanderziehm/phone-usage-app.git")
        sys.exit(1)

    repo_url = sys.argv[1]

    try:
        owner, repo = parse_github_url(repo_url)
    except ValueError as exc:
        print(f"Error: {exc}")
        sys.exit(1)

    home = Path.home()

    ssh_root = home / ".ssh"
    repos_root = ssh_root / "github-repos"

    key_dir = repos_root / owner / repo
    key_file = key_dir / "id_ed25519"
    public_key = key_dir / "id_ed25519.pub"

    ssh_config = ssh_root / "config"

    host_alias = f"github-{owner}-{repo}"

    clone_dir = Path.cwd() / repo

    print()
    print("GitHub repository:")
    print(f"  {owner}/{repo}")
    print()
    print("SSH key:")
    print(f"  {key_file}")
    print()
    print("SSH host alias:")
    print(f"  {host_alias}")
    print()

    # ---------------------------------------------------------
    # Check required commands
    # ---------------------------------------------------------

    for command in ("ssh", "ssh-keygen", "git"):
        if shutil.which(command) is None:
            print(f"Error: '{command}' is not installed or not in PATH.")
            sys.exit(1)

    # ---------------------------------------------------------
    # Generate SSH key
    # ---------------------------------------------------------

    key_dir.mkdir(parents=True, exist_ok=True)

    os.chmod(ssh_root, 0o700)
    os.chmod(repos_root, 0o700)
    os.chmod(key_dir, 0o700)

    if key_file.exists():
        print("SSH key already exists:")
        print(f"  {key_file}")
        print()

        answer = input("Use existing key? [Y/n] ").strip() or "Y"

        if answer.lower() != "y":
            print("Aborted.")
            sys.exit(1)

    else:
        print("Generating new SSH key...")

        run(
            [
                "ssh-keygen",
                "-t",
                "ed25519",
                "-f",
                str(key_file),
                "-C",
                f"github-{owner}-{repo}",
                "-N",
                "",
            ]
        )

        os.chmod(key_file, 0o600)
        os.chmod(public_key, 0o644)

        print("✓ SSH key generated.")

    # ---------------------------------------------------------
    # Configure SSH
    # ---------------------------------------------------------

    update_ssh_config(
        ssh_config,
        host_alias,
        key_file,
        owner,
        repo,
    )

    print("✓ SSH config updated.")

    # ---------------------------------------------------------
    # Show public key
    # ---------------------------------------------------------

    public_key_text = public_key.read_text().strip()

    print()
    print("=" * 60)
    print(" ADD THIS DEPLOY KEY TO GITHUB")
    print("=" * 60)
    print()
    print("Repository:")
    print(f"  https://github.com/{owner}/{repo}/settings/keys")
    print()
    print("IMPORTANT: enable:")
    print()
    print("  ☑ Allow write access")
    print()
    print("Public key:")
    print()
    print(public_key_text)
    print()
    print("=" * 60)
    print()

    input("Press ENTER after you added the key to GitHub...")

    # ---------------------------------------------------------
    # Test SSH
    # ---------------------------------------------------------

    if not test_ssh(host_alias):
        print()
        print("Make sure:")
        print("  1. The deploy key was added to the correct repository.")
        print("  2. 'Allow write access' was enabled.")
        print("  3. You copied the entire public key.")
        sys.exit(1)

    # ---------------------------------------------------------
    # Clone
    # ---------------------------------------------------------

    if clone_dir.exists():
        print()
        print("Directory already exists:")
        print(f"  {clone_dir}")
        print()
        print("Skipping clone.")

    else:
        print()
        print("Cloning repository...")

        clone_url = f"git@{host_alias}:{owner}/{repo}.git"

        run(
            [
                "git",
                "clone",
                clone_url,
                str(clone_dir),
            ]
        )

        print("✓ Repository cloned.")

    # ---------------------------------------------------------
    # Configure repo-local Git SSH command
    # ---------------------------------------------------------

    os.chdir(clone_dir)

    run(
        [
            "git",
            "config",
            "--local",
            "core.sshCommand",
            f"ssh -o Host={host_alias}",
        ]
    )

    print("✓ Repository-specific SSH configured.")

    # ---------------------------------------------------------
    # Verify
    # ---------------------------------------------------------

    ssh_command = subprocess.check_output(
        ["git", "config", "--local", "--get", "core.sshCommand"],
        text=True,
    ).strip()

    print()
    print("=" * 60)
    print(" DONE")
    print("=" * 60)
    print()
    print("Repository:")
    print(f"  {clone_dir}")
    print()
    print("SSH key:")
    print(f"  {key_file}")
    print()
    print("Git SSH command:")
    print(f"  {ssh_command}")
    print()
    print("Remote:")
    subprocess.run(["git", "remote", "-v"])
    print()
    print("From this repository or any subdirectory:")
    print()
    print("  git pull")
    print("  git push")
    print()
    print("will automatically use:")
    print(f"  {key_file}")
    print()


if __name__ == "__main__":
    main()
