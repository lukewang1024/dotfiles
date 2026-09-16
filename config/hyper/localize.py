"""Shared UI catalog; language detection never depends on the keyboard layout."""
import json
import os
from pathlib import Path


def language(value):
    return 'zh' if str(value).lower().split('.')[0].replace('_','-').split('-')[0]=='zh' else 'en'


def system_language(env=None):
    env=os.environ if env is None else env
    locale=env.get('LC_ALL') or env.get('LC_MESSAGES') or env.get('LANG') or 'C'
    if locale in ('C','POSIX','C.UTF-8','C.utf8'):
        return 'en'
    return language((env.get('LANGUAGE') or locale).split(':')[0])


def catalog(data):
    source=json.loads(Path(__file__).with_name('locales.json').read_text(encoding='utf-8'))
    result={lang:{key:pair[index] for key,pair in source.items()} for index,lang in enumerate(('en','zh'))}
    for labels in result.values():
        for name,app in data['apps'].items():
            labels.setdefault('launch.'+name,labels['template.launch'].format(name=app['title']))
        for n in range(1,10):
            labels[f'desktop.{n}']=labels['template.desktop'].format(name=n)
            labels[f'desktop.move.{n}']=labels['template.desktopMove'].format(name=n)
        for kind in ('edit','select','mouse','resize','screen','focus'):
            for direction in ('left','right','up','down','home','end','pageup','pagedown'):
                labels.setdefault(kind+'.'+direction,labels['template.'+kind].format(name=labels['direction.'+direction]))
                if kind in ('mouse','resize'):
                    labels[kind+'.fast-'+direction]=labels['template.fast'].format(name=labels['direction.'+direction])
    return result


def translate(labels,key,lang=None,**values):
    lang=lang or system_language()
    text=labels.get(lang,labels['en']).get(key,labels['en'].get(key,key))
    return text.format(**values) if values else text


def keywords(labels,action):
    return ' '.join([action]+[labels[lang].get(action,'') for lang in ('en','zh')])
