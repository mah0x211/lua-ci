import hashlib
import io
import tarfile

from support import FixtureTest, docker_validation, run


class ChecksumTests(FixtureTest):
    def setUp(self):
        super().setUp()
        self.name = "lenv_Linux_arm64.tar.gz"
        self.archive = self.work / self.name
        with tarfile.open(self.archive, "w:gz") as tf:
            entry = tarfile.TarInfo("lenv")
            entry.size = 7
            tf.addfile(entry, io.BytesIO(b"fixture"))
        self.digest = hashlib.sha256(self.archive.read_bytes()).hexdigest()
        self.checksums = self.work / "checksums.txt"

    def check(self, content):
        self.checksums.write_text(content)
        return run(["bash", "-c", docker_validation("checksum")],
                   TMP_DIR=str(self.work), ARCHIVE_NAME=self.name)

    def test_matching_checksum(self):
        for digest in (self.digest, self.digest.upper()):
            with self.subTest(digest=digest):
                result = self.check(f"{digest}  {self.name}\n")
                self.assertExit(result, 0)
                self.assertIn("VERIFIED", result.stdout)

    def test_missing_duplicate_malformed_mismatch(self):
        good = f"{self.digest}  {self.name}\n"
        cases = [
            "", f"{self.digest}  other.tar.gz\n",
            f"{self.digest}  prefix-{self.name}\n",
            f"{self.digest}  {self.name}.bak\n",
            good + good,
            f"short  {self.name}\n",
            f"{'x' * 64}  {self.name}\n",
            f"{self.digest}  {self.name} extra\n",
            f"{'0' * 64}  {self.name}\n",
        ]
        for content in cases:
            with self.subTest(content=content):
                result = self.check(content)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn("VERIFIED", result.stdout)

    def test_unreadable_metadata_or_archive(self):
        for missing in ("metadata", "archive"):
            with self.subTest(missing=missing):
                self.checksums.write_text(f"{self.digest}  {self.name}\n")
                if missing == "metadata":
                    self.checksums.unlink()
                else:
                    self.archive.unlink()
                result = run(["bash", "-c", docker_validation("checksum")],
                             TMP_DIR=str(self.work), ARCHIVE_NAME=self.name)
                self.assertNotEqual(result.returncode, 0, result.stdout)
                self.assertNotIn("VERIFIED", result.stdout)
