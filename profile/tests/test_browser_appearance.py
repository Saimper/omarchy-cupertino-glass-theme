import json, os, pathlib, sys, tempfile, unittest
sys.path.insert(0, str(pathlib.Path(__file__).resolve().parents[1]/'scripts'))
import browser_profile as browser
from vscode_profile import parse_settings

class Appearance(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.home=pathlib.Path(self.tmp.name)
        self.folder=self.home/'.config/chromium'
        self.prefs=self.folder/'Default/Preferences';self.prefs.parent.mkdir(parents=True)
        self.original={'extensions':{'theme':{'id':'my-theme'}},'session':{'restore_on_startup':1}}
        self.prefs.write_text(json.dumps(self.original))

    def test_only_appearance_changes_and_restores(self):
        browser.sync(self.home,'chromium',True)
        changed=json.loads(self.prefs.read_text())
        changed['session']['restore_on_startup']=4
        self.prefs.write_text(json.dumps(changed))
        browser.sync(self.home,'chromium',False)
        restored=json.loads(self.prefs.read_text())
        self.assertEqual(restored['extensions'],self.original['extensions'])
        self.assertEqual(restored['session']['restore_on_startup'],4)
        self.assertNotIn('custom_chrome_frame',restored.get('browser',{}))

    def test_running_profile_is_not_rewritten(self):
        (self.folder/'SingletonLock').symlink_to('test-'+str(os.getpid()))
        before=self.prefs.read_bytes()
        self.assertEqual(browser.sync(self.home,'chromium',True),'pending')
        self.assertEqual(self.prefs.read_bytes(),before)

    def test_explicit_user_theme_change_is_preserved(self):
        browser.sync(self.home,'chromium',True)
        changed=json.loads(self.prefs.read_text());changed['extensions']['theme']['id']='new-theme'
        self.prefs.write_text(json.dumps(changed))
        browser.sync(self.home,'chromium',False)
        self.assertEqual(json.loads(self.prefs.read_text())['extensions']['theme']['id'],'new-theme')

    def test_code_jsonc_keeps_strings_and_preferences(self):
        self.assertEqual(parse_settings('{/* comment */ "url":"https://example.test/a,}", // hi\n "zoom":2,}'),
                         {'url':'https://example.test/a,}','zoom':2})

if __name__=='__main__':unittest.main()
