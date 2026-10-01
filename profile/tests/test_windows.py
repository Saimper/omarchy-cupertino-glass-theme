import importlib.machinery, importlib.util, json, pathlib, tempfile, unittest

ROOT=pathlib.Path(__file__).resolve().parents[1]
loader=importlib.machinery.SourceFileLoader('cupertino_window',str(ROOT/'bin/cupertino-window'))
spec=importlib.util.spec_from_loader(loader.name,loader)
mod=importlib.util.module_from_spec(spec);loader.exec_module(mod)

class WindowRecovery(unittest.TestCase):
    def setUp(self):
        self.tmp=tempfile.TemporaryDirectory();self.addCleanup(self.tmp.cleanup)
        self.old=(mod.STATE,mod.MINIMIZED,mod.query,mod.dispatch)
        self.addCleanup(self.restore_module)
        mod.STATE=pathlib.Path(self.tmp.name);mod.MINIMIZED=mod.STATE/'minimized.json'
        self.windows=[dict(address='0x'+str(i),stableId=i,pid=i,floating=True,fullscreen=0,fullscreenClient=0,at=[0,0],size=[500,400]) for i in (1,2)]
        for w in self.windows:mod.save(mod.STATE/(str(w['stableId'])+'.json'),w|{'floating':False})
        mod.query=lambda kind:[dict(w) for w in self.windows]
        self.restored=[]
    def restore_module(self):mod.STATE,mod.MINIMIZED,mod.query,mod.dispatch=self.old
    def test_closed_window_does_not_strand_other_windows(self):
        def dispatch(name,address,**options):
            if address=='0x1':
                self.windows=[w for w in self.windows if w['address']!=address]
                raise RuntimeError('Window closed during dispatch')
            self.restored.append((address,options.get('action')))
        mod.dispatch=dispatch;mod.revert_profile()
        self.assertEqual(self.restored,[('0x2','unset')])
        self.assertEqual(list(mod.STATE.glob('*.json')),[])
    def test_real_failure_retains_recovery_but_restores_other_windows(self):
        def dispatch(name,address,**options):
            if address=='0x1':raise RuntimeError('Compositor temporarily rejected action')
            self.restored.append(address)
        mod.dispatch=dispatch
        with self.assertRaises(RuntimeError):mod.revert_profile()
        self.assertEqual(self.restored,['0x2'])
        self.assertTrue((mod.STATE/'1.json').exists())
        self.assertFalse((mod.STATE/'2.json').exists())

if __name__=='__main__':unittest.main()
