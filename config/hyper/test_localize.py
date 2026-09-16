import json
from pathlib import Path
import unittest
import generate
import localize


class LocalizeTests(unittest.TestCase):
    def test_locale_selection(self):
        for locale in ('zh','ZH','zh_CN.UTF-8','zh-Hans-HK','zh-TW'):
            self.assertEqual(localize.language(locale),'zh')
        for locale in ('en-US','ja_JP','C','',None):
            self.assertEqual(localize.language(locale),'en')
        self.assertEqual(localize.system_language({'LANG':'en_US.UTF-8','LC_MESSAGES':'zh_CN.UTF-8'}),'zh')
        self.assertEqual(localize.system_language({'LANG':'zh_CN.UTF-8','LC_ALL':'C','LANGUAGE':'zh'}),'en')
        self.assertEqual(localize.system_language({}),'en')

    def test_every_bound_and_menu_action_has_both_titles(self):
        data=json.loads(generate.SOURCE.read_text())
        labels=localize.catalog(data)
        actions=[b['action'] for b in generate.bindings(data)]
        actions += [row[2] for rows in data['menus'].values() for row in rows]
        for action in actions:
            for lang in ('en','zh'):
                self.assertIn(action,labels[lang])
                self.assertNotEqual(localize.translate(labels,action,lang),action)
        self.assertIn('截图',localize.keywords(labels,'capture.screenshot'))
        self.assertIn('screenshot',localize.keywords(labels,'capture.screenshot'))
        self.assertEqual(localize.translate(labels,'missing.key','en'),'missing.key')
        self.assertEqual(localize.translate(labels,'ui.count','zh',count=3),'3 项')

    def test_catalog_placeholders_and_generated_ahk_line_limits(self):
        data=json.loads(generate.SOURCE.read_text())
        source=json.loads(Path(__file__).with_name('locales.json').read_text())
        import string
        formatter=string.Formatter()
        for key,pair in source.items():
            fields=[{name for _,name,_,_ in formatter.parse(text) if name} for text in pair]
            self.assertEqual(fields[0],fields[1],key)
        ahk=generate.outputs(data)['config/autohotkey/lib/hyper-generated.ahk']
        self.assertLess(max(map(len,ahk.splitlines())),16383)
