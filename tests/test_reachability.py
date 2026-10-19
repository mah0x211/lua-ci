from support import FixtureTest, git


class ReachabilityTests(FixtureTest):
    def setUp(self):
        super().setUp()
        self.source = self.repository("source")
        git(self.source, "tag", "20261018")
        git(self.source, "tag", "-a", "20261018-1", "-m", "annotated")
        git(self.source, "commit", "--allow-empty", "-m", "middle")
        git(self.source, "commit", "--allow-empty", "-m", "tip")
        git(self.source, "tag", "20261020")
        git(self.source, "switch", "-c", "other")
        git(self.source, "commit", "--allow-empty", "-m", "off master")
        git(self.source, "tag", "20261021")
        git(self.source, "switch", "master")
        self.origin = self.work / "origin.git"
        git(self.work, "clone", "--bare", str(self.source), str(self.origin))

    def clone(self, name):
        repo = self.work / name
        # release.yml uses fetch-depth: 0 before invoking the validator.
        git(self.work, "clone", "--branch", "master", self.origin.as_uri(), str(repo))
        return repo

    def test_full_history_ancestry(self):
        for tag in ("20261018", "20261018-1", "20261020"):
            with self.subTest(tag=tag):
                repo = self.clone(tag)
                git(repo, "checkout", "--detach", tag)
                result = self.script("validate_tag_reachable_from_master.sh", repo, TAG=tag)
                self.assertExit(result, 0)
                self.assertIn("is reachable", result.stdout)
                self.assertEqual(git(repo, "rev-parse", "--is-shallow-repository"), "false")

    def test_non_ancestor_and_missing_reference_are_distinct(self):
        repo = self.clone("clone")
        result = self.script("validate_tag_reachable_from_master.sh", repo, TAG="20261021")
        self.assertExit(result, 1)
        self.assertIn("is not reachable", result.stdout)
        result = self.script("validate_tag_reachable_from_master.sh", repo, TAG="missing")
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("Could not determine", result.stdout)

    def test_fetch_failure(self):
        repo = self.clone("clone")
        git(repo, "remote", "set-url", "origin", str(self.work / "missing.git"))
        result = self.script("validate_tag_reachable_from_master.sh", repo, TAG="20261018")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("is reachable", result.stdout)

    def test_invalid_repository(self):
        result = self.script("validate_tag_reachable_from_master.sh", TAG="20261018")
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("is reachable", result.stdout)
