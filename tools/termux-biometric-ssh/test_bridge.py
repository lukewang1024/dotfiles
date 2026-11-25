import hashlib
import importlib.machinery
import importlib.util
import io
import os
import pathlib
import socket
import ssl
import struct
import tempfile
import threading
import unittest
from unittest.mock import patch

loader=importlib.machinery.SourceFileLoader("askpass",str(pathlib.Path(__file__).parent/"bin/termux-biometric-askpass"))
spec=importlib.util.spec_from_loader(loader.name,loader)
helper=importlib.util.module_from_spec(spec); loader.exec_module(helper)

class BridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp=tempfile.TemporaryDirectory()
        self.env=patch.dict(os.environ,{"XDG_STATE_HOME":self.temp.name}); self.env.start()
    def tearDown(self): self.env.stop(); self.temp.cleanup()
    def invoke(self, payload, bad_first=False, bad_pin=False):
        errors=[]; threads=[]
        def launch(args,**kwargs):
            port=int(args[args.index("port")+1]); token=args[args.index("token")+1]; pin=args[args.index("pin")+1]
            def connect(token_to_send,expected_pin):
                ctx=ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
                with ctx.wrap_socket(socket.socket(),server_hostname="localhost") as conn:
                    conn.connect(("127.0.0.1",port))
                    actual=hashlib.sha256(conn.getpeercert(binary_form=True)).hexdigest()
                    if actual!=expected_pin: return
                    conn.sendall(token_to_send.encode()); conn.sendall(payload)
                    if token_to_send==token and len(payload)>=4:
                        size=struct.unpack('>I',payload[:4])[0]
                        complete=(0<size<=65536 and len(payload)==size+4)
                        complete=complete or (size==0 and len(payload)>=8 and len(payload)==8+struct.unpack('>I',payload[4:8])[0])
                        if complete:
                            conn.settimeout(3)
                            self.assertEqual(conn.recv(1),b'\x01')
            def run():
                try:
                    if bad_first: connect("x"*48,pin)
                    if bad_pin: connect(token,"0"*64)
                    connect(token,pin)
                except Exception as e: errors.append(e)
            t=threading.Thread(target=run); t.start(); threads.append(t)
            return type("Result",(),dict(returncode=0,stdout=b"",stderr=b""))()
        output=type("Output",(),{"buffer":io.BytesIO()})()
        try:
            with patch.object(helper.subprocess,"run",launch),patch.object(helper.sys,"stdout",output),patch.object(helper.sys,"stderr",io.StringIO()): helper.main()
            return output.buffer.getvalue()
        finally:
            for t in threads:t.join(timeout=5)
            if errors:raise errors[0]
    def test_success(self): self.assertEqual(self.invoke(struct.pack(">I",11)+b"test-secret"),b"test-secret\n")
    def test_wrong_token_rejected(self): self.assertEqual(self.invoke(struct.pack(">I",1)+b"x",bad_first=True),b"x\n")
    def test_wrong_certificate_rejected(self): self.assertEqual(self.invoke(struct.pack(">I",1)+b"x",bad_pin=True),b"x\n")
    def test_cancelled(self):
        with self.assertRaises(RuntimeError): self.invoke(b"")
    def test_truncated(self):
        with self.assertRaises(RuntimeError): self.invoke(struct.pack(">I",10)+b"x")
    def test_oversized(self):
        with self.assertRaises(RuntimeError): self.invoke(struct.pack(">I",65537))
    def test_identity_persistent(self):
        self.assertEqual(helper.identity()[1],helper.identity()[1])
        key=pathlib.Path(self.temp.name)/"termux-biometric-ssh/transport-key.pem"
        self.assertEqual(key.stat().st_mode&0o777,0o600)
    def test_application_error_reported(self):
        error='操作失败：初始化口令解密 / InvalidKeyException'.encode()
        with self.assertRaisesRegex(RuntimeError,'Android 应用：操作失败'):
            self.invoke(struct.pack('>II',0,len(error))+error)
    def test_error_length_rejected(self):
        with self.assertRaisesRegex(RuntimeError,'无效错误长度'):
            self.invoke(struct.pack('>II',0,1025))
    def test_not_configured_reports_setup_steps(self):
        error='尚未保存 SSH 口令。请打开 SSH 指纹解锁保存口令。'.encode()
        with self.assertRaisesRegex(RuntimeError,'尚未保存 SSH 口令'):
            self.invoke(struct.pack('>II',0,len(error))+error)
    def test_biometric_cancel_reports_error(self):
        error='用户取消指纹认证'.encode()
        with self.assertRaisesRegex(RuntimeError,'用户取消指纹认证'):
            self.invoke(struct.pack('>II',0,len(error))+error)
    def test_app_not_installed_fails_without_waiting(self):
        result=type('Result',(),dict(returncode=1,stdout=b'Error: Activity does not exist',stderr=b''))()
        with patch.object(helper.subprocess,'run',return_value=result),patch.object(helper.sys,'stderr',io.StringIO()):
            with self.assertRaisesRegex(RuntimeError,'先安装'):
                helper.main()
    def test_system_language_defaults_to_english(self):
        for value, expected in [(b"zh-CN", "zh"), (b"en-US", "en"), (b"fr-FR", "fr"), (b"", "en")]:
            with patch.object(helper.subprocess, "check_output", return_value=value):
                self.assertEqual(helper.system_language(), expected)
        with patch.object(helper.subprocess, "check_output", side_effect=OSError()):
            self.assertEqual(helper.system_language(), "en")
        with patch.object(helper, "LANGUAGE", "fr"):
            self.assertEqual(helper.text("English", "中文"), "English")

    def test_wrong_saved_passphrase_does_not_reprompt(self):
        with patch.object(helper.sys,'argv',['askpass','Bad passphrase, try again for key:']),patch.object(helper,'identity',side_effect=AssertionError('authentication restarted')):
            with self.assertRaisesRegex(RuntimeError,'口令.*不匹配'):
                helper.main()

helper.LANGUAGE = "zh"
if __name__=="__main__":unittest.main()
