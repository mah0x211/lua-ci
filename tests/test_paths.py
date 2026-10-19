from support import FixtureTest, docker_validation, run


class PathTests(FixtureTest):
    LUA = "/lenv/?.lua;/lenv/?/init.lua;;"
    C = "/lenv/?.so;;"

    def check(self, lua=LUA, c=C):
        return run(["bash", "-c", docker_validation("paths")],
                   LUA_PATH=lua, LUA_CPATH=c,
                   expected_lua_path=self.LUA, expected_lua_cpath=self.C)

    def test_matching_segments_in_either_order(self):
        self.assertExit(self.check(), 0)
        self.assertExit(self.check(lua="/lenv/?/init.lua;/lenv/?.lua;;"), 0)

    def test_empty_segments_keep_existing_behavior(self):
        self.assertExit(self.check(lua=self.LUA.removesuffix(";;")), 0)
        self.assertExit(self.check(c=self.C.removesuffix(";;")), 0)

    def test_missing_extra_or_changed_segments_are_rejected(self):
        for lua in ("", "/lenv/?.lua;;",
                    "/other/?.lua;/lenv/?/init.lua;;",
                    "/lenv/?.lua;" + self.LUA):
            with self.subTest(lua=lua):
                self.assertNotEqual(self.check(lua=lua).returncode, 0)
        for c in ("", "/other/?.so;;", "/lenv/?.so;" + self.C):
            with self.subTest(c=c):
                self.assertNotEqual(self.check(c=c).returncode, 0)
