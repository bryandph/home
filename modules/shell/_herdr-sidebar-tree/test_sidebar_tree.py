import unittest

from sidebar_tree import BLANK, plan


def space(workspace_id, label, cwd=None):
    return {"workspace_id": workspace_id, "label": label}, {workspace_id: cwd} if cwd else {}


def worktree(workspace_id, label, checkout, repo, linked):
    return {
        "workspace_id": workspace_id,
        "label": label,
        "worktree": {
            "checkout_path": checkout,
            "repo_key": f"{repo}/.git",
            "is_linked_worktree": linked,
        },
    }


def build(*entries):
    workspaces, cwds = [], {}
    for entry in entries:
        if isinstance(entry, tuple):
            workspaces.append(entry[0])
            cwds.update(entry[1])
        else:
            workspaces.append(entry)
    return workspaces, cwds


class PlanTest(unittest.TestCase):
    def test_nests_by_open_ancestor_spaces(self):
        workspaces, cwds = build(
            worktree("w1", "nixspace", "/h/BPH/profile/nixspace", "/h/BPH/profile/nixspace", False),
            space("w2", "finance", "/h/BPH/profile/finance"),
            space("w3", "BPH", "/h/BPH"),
            space("w4", "modules", "/h/BPH/profile/nixspace/modules"),
            space("w5", "tmp", "/tmp"),
        )
        order, tokens = plan(workspaces, cwds)
        self.assertEqual(order, ["w3", "w2", "w1", "w4", "w5"])
        # `profile/` is not a space, so finance and nixspace are BPH's
        # children at depth 1, and modules nests under nixspace.
        self.assertEqual(
            [tokens[w] for w in order],
            ["BPH", "├ finance", "└ nixspace", BLANK + " └ modules", "tmp"],
        )

    def test_closing_an_ancestor_promotes_its_children(self):
        workspaces, cwds = build(
            space("w2", "finance", "/h/BPH/profile/finance"),
            space("w1", "nixspace", "/h/BPH/profile/nixspace"),
        )
        order, tokens = plan(workspaces, cwds)
        self.assertEqual(order, ["w2", "w1"])
        self.assertEqual(tokens, {"w1": "nixspace", "w2": "finance"})

    def test_continuation_line_for_non_last_ancestor(self):
        workspaces, cwds = build(
            space("w1", "root", "/r"),
            space("w2", "a", "/r/a"),
            space("w3", "deep", "/r/a/deep"),
            space("w4", "b", "/r/b"),
        )
        order, tokens = plan(workspaces, cwds)
        self.assertEqual(order, ["w1", "w2", "w3", "w4"])
        self.assertEqual(tokens["w3"], "│ └ deep")
        self.assertEqual(tokens["w4"], "└ b")

    def test_grouped_worktrees_follow_primary_and_never_nest(self):
        repo = "/h/BPH/profile/nixspace"
        workspaces, cwds = build(
            worktree("w9", " bph11-flow", "/h/.herdr/worktrees/nixspace/bph11-flow", repo, True),
            space("w3", "BPH", "/h/BPH"),
            worktree("w1", "nixspace", repo, repo, False),
            # A linked worktree inside the primary must not become a child.
            worktree("w8", "inner", f"{repo}__worktrees/inner", repo, True),
            space("w4", "modules", f"{repo}/modules"),
        )
        order, tokens = plan(workspaces, cwds)
        self.assertEqual(order, ["w3", "w1", "w9", "w8", "w4"])
        self.assertEqual(tokens["w9"], "bph11-flow")
        self.assertEqual(tokens["w4"], BLANK + " └ modules")

    def test_deep_primary_pads_its_worktrees(self):
        repo = "/a/b/c/repo"
        workspaces, cwds = build(
            space("w1", "a", "/a"),
            space("w2", "b", "/a/b"),
            space("w3", "c", "/a/b/c"),
            worktree("w4", "repo", repo, repo, False),
            worktree("w5", "feature", "/wt/feature", repo, True),
        )
        _, tokens = plan(workspaces, cwds)
        self.assertEqual(tokens["w5"], BLANK * 2 + "feature")

    def test_ungrouped_linked_worktree_nests_by_its_checkout(self):
        repo = "/h/repo"
        workspaces, cwds = build(
            space("w1", "h", "/h"),
            worktree("w2", "feature", "/h/repo__worktrees/feature", repo, True),
        )
        _, tokens = plan(workspaces, cwds)
        self.assertEqual(tokens["w2"], "└ feature")

    def test_equal_paths_are_siblings_in_current_order(self):
        workspaces, cwds = build(
            space("w2", "second", "/same"),
            space("w1", "first", "/same"),
        )
        order, tokens = plan(workspaces, cwds)
        self.assertEqual(order, ["w2", "w1"])
        self.assertEqual(tokens, {"w1": "first", "w2": "second"})

    def test_spaces_without_a_path_stay_top_level(self):
        workspaces, cwds = build(space("w1", "nowhere"), space("w2", "root", "/"))
        order, tokens = plan(workspaces, cwds)
        self.assertEqual(order, ["w1", "w2"])
        self.assertEqual(tokens["w1"], "nowhere")


if __name__ == "__main__":
    unittest.main()
