from support import FixtureTest, git


class ReleaseTests(FixtureTest):
    def test_output_tags_for_all_suites_and_arches(self):
        image = "example.invalid/lua-ci"
        for suite in ("bullseye", "bookworm", "trixie"):
            base = [f"{image}:{suite}-20261020-10", f"{image}:{suite}"]
            if suite == "bookworm":
                base.append(f"{image}:latest")
            for arch in ("", "amd64", "arm64"):
                with self.subTest(suite=suite, arch=arch):
                    output = self.work / "output"
                    output.write_text("")
                    result = self.script(
                        "compute_tags.sh", IMAGE_NAME=image, TAG="20261020-10",
                        SUITE=suite, LATEST_SUITE="bookworm",
                        WITH_ARCH_SUFFIX="1" if arch else "", ARCH=arch,
                        GITHUB_OUTPUT=str(output))
                    self.assertExit(result, 0)
                    wanted = [tag + f"-{arch}" for tag in base] if arch else base
                    self.assertEqual(output.read_text().splitlines(),
                                     ["tags<<EOF", *wanted, "EOF"])

    def test_arch_is_required(self):
        result = self.script(
            "compute_tags.sh", IMAGE_NAME="example.invalid/lua-ci",
            TAG="20261020", SUITE="bookworm", LATEST_SUITE="bookworm",
            WITH_ARCH_SUFFIX="1", ARCH="")
        self.assertNotEqual(result.returncode, 0)

    def test_older_queued_release_is_rejected_after_new_tag_arrives(self):
        repo = self.repository()
        git(repo, "tag", "20261020")
        self.assertExit(self.script("validate_tag_order.sh", repo, TAG="20261020"), 0)
        git(repo, "tag", "20261021")
        self.assertExit(self.script("validate_tag_order.sh", repo, TAG="20261021"), 0)
        # Once the newer ref exists, the older run may not publish, including
        # when scheduler order differs from tag creation order.
        self.assertExit(self.script("validate_tag_order.sh", repo, TAG="20261020"), 1)
