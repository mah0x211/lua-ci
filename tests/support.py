"""Real-process helpers; temporary files stay in the repository's .codex tree."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
ENV = {**os.environ, "GIT_CONFIG_GLOBAL": os.devnull,
       "GIT_CONFIG_NOSYSTEM": "1",
       "GIT_CEILING_DIRECTORIES": str(ROOT / ".codex"),
       "GIT_AUTHOR_NAME": "Test",
       "GIT_AUTHOR_EMAIL": "test@example.invalid",
       "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.invalid"}

for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE"):
    ENV.pop(key, None)


def run(args, cwd=ROOT, **env):
    return subprocess.run(args, cwd=cwd, env={**ENV, **env}, text=True,
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)


def git(cwd, *args):
    p = run(["git", *args], cwd)
    if p.returncode:
        raise AssertionError(p.stdout)
    return p.stdout.strip()


class FixtureTest(unittest.TestCase):
    def setUp(self):
        parent = ROOT / ".codex" / "test-tmp"
        parent.mkdir(parents=True, exist_ok=True)
        self.tmp = tempfile.TemporaryDirectory(dir=parent)
        self.addCleanup(self.tmp.cleanup)
        self.work = Path(self.tmp.name)

    def repository(self, name="repo"):
        p = self.work / name
        p.mkdir()
        git(p, "init", "-b", "master")
        git(p, "commit", "--allow-empty", "-m", "initial")
        return p

    def script(self, name, cwd=None, **env):
        return run(["bash", str(ROOT / name)], cwd or self.work, **env)

    def assertExit(self, result, expected):
        self.assertEqual(result.returncode, expected, result.stdout)


def docker_validation(kind):
    """Execute the actual Dockerfile guard, with its inputs supplied by fixtures."""
    lines = [line for line in (ROOT / "Dockerfile").read_text().splitlines()
             if line.strip() and not line.lstrip().startswith("#")]
    if kind == "checksum":
        start = next(i for i, line in enumerate(lines) if "EXPECTED=" in line)
        end = next(i for i, line in enumerate(lines[start:], start)
                   if line.lstrip().startswith("tar -xzf"))
        lines = lines[start:end]
    else:
        start = next(i for i, line in enumerate(lines)
                     if line.lstrip().startswith("normalize_path_list()"))
        end = start
        while lines[end].rstrip().endswith("\\"):
            end += 1
        lines = lines[start:end + 1]
        # Metadata acquisition is outside this guard. Test the real validation
        # against explicit expected values without replacing the lenv executable.
        lines = [line for line in lines if not line.lstrip().startswith(
            ("expected_lua_path=", "expected_lua_cpath="))]
    return "set -euo pipefail\n" + "\n".join(
        line.removesuffix("\\").rstrip() for line in lines) + "\nprintf 'VERIFIED\\n'\n"
