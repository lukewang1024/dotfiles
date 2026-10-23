"""Exercise local skill installation only in disposable homes."""

import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
SKILLS = ("code-ship", "codex-reset-card")


@unittest.skipUnless(os.name == "posix", "requires POSIX shell and symlinks")
class AgentSkillInstallTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        self.home = Path(temporary.name)
        self.config = self.home / "config with spaces"
        self.config.mkdir()
        (self.config / "dotfiles").symlink_to(ROOT, target_is_directory=True)
        self.roots = (self.home / ".agents/skills", self.home / ".codex/skills",
                      self.home / ".claude/skills", self.config / "opencode/skills",
                      self.home / ".openclaw/skills")
        binary = self.home / "bin"
        binary.mkdir()
        npx = binary / "npx"
        npx.write_text('#!/bin/sh\nprintf invoked > "$SKILL_INSTALL_NPX_MARKER"\nexit 97\n')
        npx.chmod(0o700)
        self.marker = self.home / "npx-invoked"
        self.environment = dict(os.environ, HOME=str(self.home), XDG_CONFIG_HOME=str(self.config),
                                XDG_DATA_HOME=str(self.home / "data"), XDG_STATE_HOME=str(self.home / "state"),
                                PATH=str(binary) + os.pathsep + os.defpath,
                                SKILL_INSTALL_NPX_MARKER=str(self.marker))

    def install(self):
        result = subprocess.run(["/bin/sh", str(ROOT / "util/agent/agent-skills-install"), "--local-only"],
                                env=self.environment, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(self.marker.exists(), "local-only must not invoke the network installer")
        return result

    def test_local_only_installs_both_skills_and_is_idempotent(self):
        self.install()
        originals = {}
        for root in self.roots:
            for name in SKILLS:
                link = root / name
                self.assertTrue(link.is_symlink())
                self.assertEqual(link.resolve(), (ROOT / "config/agent/skills" / name).resolve())
                self.assertTrue((link / "SKILL.md").is_file())
                originals[link] = link.lstat().st_ino
        self.assertEqual((self.home / ".local/bin/code-ship").resolve(), (ROOT / "util/agent/code-ship").resolve())
        self.install()
        self.assertEqual({path: path.lstat().st_ino for path in originals}, originals)

    def test_preserves_unmanaged_directories_and_links(self):
        custom = self.roots[1] / "codex-reset-card"
        custom.mkdir(parents=True)
        (custom / "SKILL.md").write_text("user-owned skill\n")
        custom_link = self.roots[2] / "code-ship"
        custom_link.parent.mkdir(parents=True)
        custom_link.symlink_to(self.home / "unmanaged-source")
        result = self.install()
        self.assertEqual((custom / "SKILL.md").read_text(), "user-owned skill\n")
        self.assertEqual(os.readlink(custom_link), str(self.home / "unmanaged-source"))
        self.assertIn("preserving " + str(custom), result.stderr)
        self.assertIn("preserving " + str(custom_link), result.stderr)

    def test_preserves_code_ship_legacy_migration(self):
        target = self.roots[0] / "code-ship"
        target.parent.mkdir(parents=True)
        target.symlink_to(self.home / "harness/skills/code-ship")
        self.install()
        self.assertEqual(target.resolve(), (ROOT / "config/agent/skills/code-ship").resolve())

    def test_public_keep_list_preserves_installed_skills(self):
        self.install()
        result = subprocess.run(["/bin/sh", str(ROOT / "util/agent/agent-skills-prune"),
                                 "--keep-file", str(ROOT / "config/agent/skills-keep.txt"), "--apply"],
                                env=self.environment, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        for root in self.roots:
            for name in SKILLS:
                self.assertTrue((root / name / "SKILL.md").is_file())


@unittest.skipUnless(os.name == "posix", "reset-card executor requires POSIX file locks")
class ResetCardSkillTests(unittest.TestCase):
    def test_offline_executor_and_timer_preparation(self):
        result = subprocess.run([sys.executable, "-B", "-m", "unittest", "discover", "-s",
                                 str(ROOT / "config/agent/skills/codex-reset-card/tests"), "-v"],
                                text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)


if __name__ == "__main__":
    unittest.main()
