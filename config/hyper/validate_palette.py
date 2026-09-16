"""Exercise the installed resident menu session without executing platform actions.

Requires an unlocked desktop. This opens a temporary validation menu.
"""
import uuid

from palette_bridge import Session


def main():
    rid = str(uuid.uuid4())
    def page(name, item):
        return dict(request_id=rid, root=name, menus={name:dict(title='Hyper validation', quick=True, items=[item])})
    session = Session(page('root', dict(id='child', title='Dynamic page', navigate=True)))
    actions = []
    try:
        for event in session.events():
            if event['type'] == 'shown':
                session.command(dict(type='navigate', request_id=rid, action='accept'))
            elif event['type'] == 'action':
                actions.append(event['action'])
                if actions == ['child']:
                    session.command(dict(type='push', request=page('repeat', dict(id='repeat', title='Keep open', keep_open=True))))
                    session.command(dict(type='navigate', request_id=rid, action='accept'))
                elif actions == ['child', 'repeat']:
                    session.command(dict(type='navigate', request_id=rid, action='back'))
                    session.command(dict(type='navigate', request_id=rid, action='accept'))
                elif actions == ['child', 'repeat', 'child']:
                    session.command(dict(type='push', request=page('final', dict(id='done', title='Close'))))
                    session.command(dict(type='navigate', request_id=rid, action='accept'))
            elif event['type'] in ('error', 'dismissed'):
                raise RuntimeError(event)
        assert actions == ['child', 'repeat', 'child', 'done'], actions
        print('PASS: authenticated session, dynamic page, keep-open, Backspace parent, terminal selection')
    finally:
        session.close()


if __name__ == '__main__':
    main()
