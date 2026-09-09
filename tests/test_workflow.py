"""Local workflow regression checks; Git commits exist only in disposable fixtures."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]


class MainWorkflowTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.repo = Path(self.tmp.name) / 'workspace'
        self.repo.mkdir()
        shutil.copytree(ROOT / 'ops', self.repo / 'ops')
        shutil.copy(ROOT / 'repos.yaml', self.repo / 'repos.yaml')
        shutil.copy(ROOT / '.gitignore', self.repo / '.gitignore')
        self.env = dict(os.environ, GIT_CONFIG_NOSYSTEM='1',
                        GIT_CONFIG_GLOBAL='/dev/null')
        self.git('init', '-b', 'main')
        self.git('add', 'ops', 'repos.yaml', '.gitignore')
        self.git('-c', 'user.name=Fixture', '-c', 'user.email=fixture@example.invalid',
                 '-c', 'commit.gpgsign=false', 'commit', '-m', 'test: fixture')
        self.git('remote', 'add', 'origin', str(self.repo))
        self.git('update-ref', 'refs/remotes/origin/main', 'HEAD')

    def run_cmd(self, *args):
        return subprocess.run(args, cwd=self.repo, env=self.env,
                              capture_output=True, text=True)

    def git(self, *args):
        result = self.run_cmd('git', *args)
        self.assertEqual(result.returncode, 0, result.stderr)
        return result.stdout.strip()

    def test_clean_main_preflight_never_creates_branch_or_commit(self):
        head = self.git('rev-parse', 'HEAD')
        result = self.run_cmd('bash', 'ops/start-task.sh', '--repos', 'workspace', '--dry-run')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(self.git('branch', '--format=%(refname:short)'), 'main')
        self.assertEqual(self.git('rev-parse', 'HEAD'), head)
        self.assertEqual(self.git('status', '--porcelain'), '')

    def test_dirty_main_is_preserved(self):
        (self.repo / 'user-work.txt').write_text('preserve me')
        result = self.run_cmd('bash', 'ops/start-task.sh', '--repos', 'workspace')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('uncommitted changes', result.stderr)
        self.assertEqual((self.repo / 'user-work.txt').read_text(), 'preserve me')

    def test_other_branch_is_rejected(self):
        self.git('switch', '-c', 'old-task')
        result = self.run_cmd('bash', 'ops/start-task.sh', '--repos', 'workspace', '--dry-run')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('must already be on main', result.stderr)

    def test_missing_components_are_reported(self):
        result = self.run_cmd('bash', 'ops/repos-status.sh', '--no-remote-check')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.count('MISSING'), 5)

    def test_environment_trees_are_ignored_by_workspace(self):
        for relative in ('dev/self-checkout-infra/compose.yaml',
                         'dev/new-component/file.txt', 'prod/release/file.txt'):
            target = self.repo / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text('local file')
            result = self.run_cmd('git', 'check-ignore', '-q', relative)
            self.assertEqual(result.returncode, 0, relative)
        self.assertEqual(self.git('status', '--porcelain'), '')

    def test_component_git_paths_resolve_inside_dev(self):
        for component in ('infra', 'admin', 'backend', 'client', 'ml'):
            result = self.run_cmd(
                'bash', '-c',
                '. ops/lib/git-common.sh; git_repo_absolute_path "$1"',
                'test', component)
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(result.stdout.strip(),
                             str(self.repo / 'dev' / ('self-checkout-' + component)))

    def test_legacy_entrypoints_stop_before_external_commands(self):
        for script in sorted((self.repo / 'ops').glob('*.sh')):
            if script.name.startswith('dev-') or script.name == 'prod-status.sh':
                result = self.run_cmd('bash', str(script))
                self.assertEqual(result.returncode, 2, script.name)
                self.assertIn('Legacy remote workflow is disabled', result.stderr)

    def test_finish_reviews_without_deployment(self):
        result = self.run_cmd('bash', 'ops/finish-task.sh', '--repos', 'workspace')
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('Local review only', result.stdout)
        self.assertIn('direct approval summary', result.stdout)


if __name__ == '__main__':
    unittest.main()
