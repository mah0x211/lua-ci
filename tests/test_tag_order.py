from support import FixtureTest, git


class TagOrderTests(FixtureTest):
    def test_numeric_order(self):
        cases = [
            ([], "20261020", True),
            (["20261020-9", "20261020-11"], "20261020-10", False),
            (["20261020-9"], "20261020-10", True),
            (["20261020-9"], "20261020-08", False),
            (["20261020-08"], "20261020-09", True),
            (["20261020-1"], "20261020-2", True),
            (["20261020-2"], "20261020-1", False),
            (["20261020"], "20261020-0", False),
            (["20261020-00"], "20261020", False),
            (["20261020-0001"], "20261020-1", False),
            (["20261020-999"], "20261021", True),
            (["20261021"], "20261020-999", False),
            (["20261020-" + "9" * 80], "20261020-1" + "0" * 80, True),
            (["20261020-1" + "0" * 80], "20261020-" + "9" * 80, False),
            (["v1.0.0", "2026-invalid", "20261020"], "20261020", True),
        ]
        for n, (tags, tag, accepted) in enumerate(cases):
            with self.subTest(tags=tags, tag=tag):
                repo = self.repository(str(n))
                for previous in tags:
                    git(repo, "tag", previous)
                result = self.script("validate_tag_order.sh", repo, TAG=tag)
                self.assertEqual(result.returncode == 0, accepted, result.stdout)
                self.assertNotIn("value too great", result.stdout)

    def test_git_failure(self):
        self.assertNotEqual(self.script("validate_tag_order.sh", TAG="20261020").returncode, 0)

    def test_format_validation(self):
        for tag in ("20261020", "20261020-08", "20261020-" + "9" * 80):
            self.assertExit(self.script("validate_tag_format.sh", TAG=tag), 0)
        for tag in ("", "not-a-date", "20261020-", "20261020--1"):
            with self.subTest(tag=tag):
                result = self.script("validate_tag_format.sh", TAG=tag)
                self.assertNotEqual(result.returncode, 0)
