package local.termux.biometricssh;

import android.app.Activity;
import android.hardware.biometrics.BiometricPrompt;
import javax.net.ssl.*;
import java.net.InetSocketAddress;
import java.security.MessageDigest;
import java.security.cert.X509Certificate;
import android.os.Bundle;
import android.os.CancellationSignal;
import android.security.keystore.KeyGenParameterSpec;
import android.security.keystore.KeyProperties;
import android.text.InputType;
import android.util.Base64;
import android.view.WindowManager;
import android.widget.*;
import java.io.DataOutputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyStore;
import java.util.Arrays;
import javax.crypto.Cipher;
import javax.crypto.KeyGenerator;
import javax.crypto.SecretKey;
import javax.crypto.spec.GCMParameterSpec;

public class MainActivity extends Activity {
    private static final String ALIAS = "ssh-passphrase-v1";
    private CancellationSignal cancel;
    private SSLSocket socket;
    private TextView status;
    private boolean request;
    private String stage;
    private final java.util.concurrent.atomic.AtomicBoolean completed = new java.util.concurrent.atomic.AtomicBoolean();

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        stage = text("Initializing", "初始化");
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        LinearLayout layout = new LinearLayout(this);
        layout.setOrientation(LinearLayout.VERTICAL);
        int pad = (int)(24 * getResources().getDisplayMetrics().density);
        layout.setPadding(pad,pad,pad,pad);
        status = new TextView(this); status.setTextSize(18); layout.addView(status);
        setContentView(layout);
        String name = getIntent().getStringExtra("token");
        request = name != null;
        if (request) {
            status.setText(text("Provide the SSH passphrase to local Termux", "向本机 Termux 提供 SSH 密钥口令"));
            try {
                stage = text("Validating local connection request", "校验本机连接请求");
                if (!name.matches("[0-9a-f]{48}")) throw new SecurityException(text("Invalid request", "无效请求"));
                String pin = getIntent().getStringExtra("pin");
                int port = getIntent().getIntExtra("port",0);
                if (pin == null || !pin.matches("[0-9a-f]{64}") || port < 1024 || port > 65535)
                    throw new SecurityException(text("Invalid connection parameters", "无效连接参数"));
                new android.os.Handler(getMainLooper()).postDelayed(() -> {
                    if (!isFinishing()) reportFailure(text("Authentication timed out", "等待认证超时"));
                },90000);
                String trusted = getPreferences(0).getString("termuxPin",null);
                if (trusted == null) {
                    new android.app.AlertDialog.Builder(this).setTitle(text("First connection to Termux", "首次连接 Termux"))
                        .setMessage(text("Compare this certificate fingerprint with Termux. Allow only if they match exactly:\n\n", "请与 Termux 显示的证书指纹核对，完全一致才允许：\n\n")+pin)
                        .setNegativeButton(text("Cancel", "取消"),(d,w)->connect(port,name,pin,text("Initial certificate pairing canceled", "用户取消首次证书配对")))
                        .setPositiveButton(text("Match; remember connection", "一致，记住此连接"),(d,w)-> {
                            getPreferences(0).edit().putString("termuxPin",pin).commit(); connect(port,name,pin);
                        }).setOnCancelListener(d->connect(port,name,pin,text("Initial certificate pairing canceled", "用户取消首次证书配对"))).show();
                } else {
                    if (!trusted.equals(pin)) connect(port,name,pin,text("The Termux certificate changed. Verify the transport identity, then open the app to pair again.", "Termux 证书发生变化。请核对传输身份，确认后打开应用重新配对。"));
                    else connect(port,name,pin);
                }
            } catch (Exception e) { fail(e); }
        } else {
            status.setText(getPreferences(0).contains("ciphertext") ? text("One SSH passphrase is saved. Saving again replaces it.", "已保存一个 SSH 口令。重新保存会替换它。") : text("Save the SSH private key passphrase", "保存 SSH 私钥的解锁口令"));
            EditText password = new EditText(this);
            password.setHint(text("SSH private key passphrase", "SSH 私钥口令"));
            password.setSingleLine(true);
            password.setInputType(InputType.TYPE_CLASS_TEXT | InputType.TYPE_TEXT_VARIATION_PASSWORD);
            password.setImportantForAutofill(android.view.View.IMPORTANT_FOR_AUTOFILL_NO);
            layout.addView(password);
            Button save = new Button(this); save.setText(text("Encrypt and save with biometrics", "按指纹加密保存")); layout.addView(save);
            save.setOnClickListener(v -> {
                byte[] plain = password.getText().toString().getBytes(StandardCharsets.UTF_8);
                if (plain.length == 0) { status.setText(text("Enter a passphrase", "请输入口令")); return; }
                password.setText("");
                try { encrypt(plain); } catch (Exception e) { Arrays.fill(plain,(byte)0); fail(e); }
            });
            Button delete = new Button(this); delete.setText(text("Delete saved passphrase", "删除已保存的口令")); layout.addView(delete);
            delete.setOnClickListener(v -> new android.app.AlertDialog.Builder(this)
                .setMessage(text("Delete the locally saved passphrase? SSH private key files will remain unchanged.", "删除本机保存的口令？SSH 私钥文件不会改变。"))
                .setNegativeButton(text("Cancel", "取消"),null).setPositiveButton(text("Delete", "删除"),(d,w) -> {
                    try {
                        KeyStore ks = store(); ks.deleteEntry(ALIAS);
                        getPreferences(0).edit().clear().commit(); status.setText(text("Deleted", "已删除"));
                    } catch (Exception e) { fail(e); }
                }).show());
        }
    }
    private String text(String english, String chinese) {
        return "zh".equals(android.content.res.Resources.getSystem().getConfiguration().getLocales().get(0).getLanguage()) ? chinese : english;
    }
    private void connect(int port, String token, String pin) {
        connect(port,token,pin,null);
    }
    private void connect(int port, String token, String pin, String failure) {
        stage = text("Connecting to local encrypted channel", "连接本机加密通道");
        new Thread(() -> {
            try {
                X509TrustManager trust = new X509TrustManager() {
                    public X509Certificate[] getAcceptedIssuers() { return new X509Certificate[0]; }
                    public void checkClientTrusted(X509Certificate[] c,String a) throws java.security.cert.CertificateException { throw new java.security.cert.CertificateException(); }
                    public void checkServerTrusted(X509Certificate[] c,String a) throws java.security.cert.CertificateException {
                        try {
                            if (c.length != 1) throw new java.security.cert.CertificateException();
                            byte[] hash = MessageDigest.getInstance("SHA-256").digest(c[0].getEncoded());
                            StringBuilder hex = new StringBuilder(); for(byte b:hash) hex.append(String.format("%02x",b & 255));
                            if (!pin.equals(hex.toString())) throw new java.security.cert.CertificateException(text("Certificate mismatch", "证书不匹配"));
                        } catch(java.security.cert.CertificateException e) { throw e; }
                        catch(Exception e) { throw new java.security.cert.CertificateException(e); }
                    }
                };
                SSLContext tls = SSLContext.getInstance("TLS"); tls.init(null,new TrustManager[]{trust},null);
                socket = (SSLSocket)tls.getSocketFactory().createSocket();
                socket.connect(new InetSocketAddress("127.0.0.1",port),10000); socket.setSoTimeout(90000);
                socket.startHandshake();
                socket.getOutputStream().write(token.getBytes(StandardCharsets.US_ASCII)); socket.getOutputStream().flush();
                runOnUiThread(() -> {
                    if (failure != null) { reportFailure(failure); return; }
                    try { decrypt(); } catch(Exception e) { fail(e); }
                });
            } catch(Exception e) { runOnUiThread(() -> fail(e)); }
        }).start();
    }
    private KeyStore store() throws Exception {
        KeyStore ks = KeyStore.getInstance("AndroidKeyStore"); ks.load(null); return ks;
    }
    private SecretKey key() throws Exception {
        KeyStore ks = store();
        if (!ks.containsAlias(ALIAS)) {
            KeyGenerator gen = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES,"AndroidKeyStore");
            gen.init(new KeyGenParameterSpec.Builder(ALIAS,KeyProperties.PURPOSE_ENCRYPT | KeyProperties.PURPOSE_DECRYPT)
                .setBlockModes(KeyProperties.BLOCK_MODE_GCM).setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setKeySize(256).setUserAuthenticationRequired(true)
                .setUserAuthenticationParameters(0,KeyProperties.AUTH_BIOMETRIC_STRONG)
                .setInvalidatedByBiometricEnrollment(true).build());
            gen.generateKey();
        }
        return (SecretKey)ks.getKey(ALIAS,null);
    }
    private void encrypt(byte[] plain) throws Exception {
        stage = text("Encrypting passphrase", "加密保存口令");
        if (!biometricsReady(() -> Arrays.fill(plain,(byte)0))) return;
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding"); cipher.init(Cipher.ENCRYPT_MODE,key());
        authenticate(cipher,text("Encrypt and save SSH passphrase", "加密保存 SSH 口令"), () -> {
            try {
                byte[] encrypted = cipher.doFinal(plain);
                boolean ok = getPreferences(0).edit()
                    .putString("iv",Base64.encodeToString(cipher.getIV(),Base64.NO_WRAP))
                    .putString("ciphertext",Base64.encodeToString(encrypted,Base64.NO_WRAP)).commit();
                if (!ok) throw new java.io.IOException(text("Save failed", "保存失败"));
                Toast.makeText(this,text("Passphrase encrypted and saved", "口令已加密保存"),Toast.LENGTH_LONG).show(); finishAndRemoveTask();
            } catch (Exception e) { fail(e); }
            finally { Arrays.fill(plain,(byte)0); }
        }, () -> Arrays.fill(plain,(byte)0));
    }
    private void decrypt() throws Exception {
        if (!getPreferences(0).contains("ciphertext")) {
            reportFailure(text("No SSH passphrase saved. Open SSH Biometric Unlock from the app launcher, save the private key passphrase, then run ssh-agent-connect again.", "尚未保存 SSH 口令。请从应用列表打开“SSH 指纹解锁”，保存私钥口令后再运行 ssh-agent-connect。"));
            return;
        }
        if (!biometricsReady(() -> {})) return;
        stage = text("Initializing passphrase decryption", "初始化口令解密");
        Cipher cipher = Cipher.getInstance("AES/GCM/NoPadding");
        byte[] iv = Base64.decode(getPreferences(0).getString("iv",""),Base64.NO_WRAP);
        cipher.init(Cipher.DECRYPT_MODE,key(),new GCMParameterSpec(128,iv));
        authenticate(cipher,text("Allow Termux to load SSH keys", "允许 Termux 加载 SSH 密钥"), () -> {
            byte[] plain = null;
            try {
                stage = text("Decrypting passphrase", "解密口令");
                plain = cipher.doFinal(Base64.decode(getPreferences(0).getString("ciphertext",""),Base64.NO_WRAP));
                stage = text("Returning passphrase to Termux", "向 Termux 返回口令");
                byte[] response = plain; plain = null;
                new Thread(() -> {
                    try {
                        if (!completed.compareAndSet(false,true)) return;
                        DataOutputStream out = new DataOutputStream(socket.getOutputStream());
                        out.writeInt(response.length); out.write(response); out.flush();
                        if (socket.getInputStream().read() != 1) throw new java.io.IOException(text("Response not acknowledged", "响应未确认"));
                        runOnUiThread(() -> finishAndRemoveTask());
                    } catch(Exception e) {
                        runOnUiThread(() -> {
                            Toast.makeText(this,text("Passphrase transfer failed: ", "口令传输失败：")+e.getClass().getSimpleName(),Toast.LENGTH_LONG).show();
                            finishAndRemoveTask();
                        });
                    }
                    finally { Arrays.fill(response,(byte)0); closeSocket(); }
                }).start();
            } catch (Exception e) { fail(e); }
            finally { if (plain != null) Arrays.fill(plain,(byte)0); }
        }, () -> {});
    }
    private boolean biometricsReady(Runnable cleanup) {
        android.hardware.biometrics.BiometricManager manager = getSystemService(android.hardware.biometrics.BiometricManager.class);
        int available = manager.canAuthenticate(android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG);
        if (available == android.hardware.biometrics.BiometricManager.BIOMETRIC_SUCCESS) return true;
        cleanup.run();
        if (available == android.hardware.biometrics.BiometricManager.BIOMETRIC_ERROR_NONE_ENROLLED)
            reportFailure(text("No usable biometrics enrolled. Enroll fingerprints in Android settings, then open this app to save the SSH passphrase.", "尚未录入可用指纹。请先在 Android 设置中录入指纹，再打开本应用保存 SSH 口令。"));
        else reportFailure(text("Strong biometrics unavailable; code ", "强生物识别当前不可用，代码 ")+available+text(" . Check Android biometric settings or use ordinary ssh-add.", "。请检查 Android 生物识别设置，或使用普通 ssh-add。"));
        return false;
    }
    private void authenticate(Cipher cipher, String title, Runnable success, Runnable cleanup) {
        cancel = new CancellationSignal();
        new BiometricPrompt.Builder(this).setTitle(title).setSubtitle(text("For the local SSH passphrase only", "仅用于本机 SSH 密钥口令"))
            .setAllowedAuthenticators(android.hardware.biometrics.BiometricManager.Authenticators.BIOMETRIC_STRONG)
            .setNegativeButton(text("Cancel", "取消"),getMainExecutor(),(d,w) -> {cleanup.run(); reportFailure(text("Biometric authentication canceled", "用户取消指纹认证"));})
            .build().authenticate(new BiometricPrompt.CryptoObject(cipher),cancel,getMainExecutor(),new BiometricPrompt.AuthenticationCallback() {
                @Override public void onAuthenticationSucceeded(BiometricPrompt.AuthenticationResult result) { success.run(); }
                @Override public void onAuthenticationError(int code,CharSequence message) {
                    cleanup.run();
                    if (request) reportFailure(text("Biometric authentication error; code ", "指纹认证错误，代码 ")+code);
                    else status.setText(message);
                }
            });
    }
    private void fail(Exception e) {
        if (e instanceof android.security.keystore.KeyPermanentlyInvalidatedException) {
            reportFailure(text("Biometric or screen lock changes invalidated the key. Open SSH Biometric Unlock, delete the saved entry, then save the original SSH passphrase again.", "指纹或锁屏设置变更使密钥失效。请打开“SSH 指纹解锁”，删除保存项后重新保存原 SSH 口令。"));
            return;
        }
        Throwable cause = e;
        while (cause.getCause() != null && cause.getCause() != cause) cause = cause.getCause();
        reportFailure(text("Operation failed: ", "操作失败：") + stage + " / " + e.getClass().getSimpleName()+" / "+cause.getClass().getSimpleName());
    }
    private void reportFailure(String message) {
        status.setText(message);
        if (!request) return;
        if (!completed.compareAndSet(false,true)) return;
        Toast.makeText(this,message,Toast.LENGTH_LONG).show();
        new Thread(() -> {
            try {
                if (socket != null && socket.isConnected()) {
                    // Only fixed stage names, exception class names and numeric codes are sent.
                    byte[] error = message.getBytes(StandardCharsets.UTF_8);
                    DataOutputStream out = new DataOutputStream(socket.getOutputStream());
                    out.writeInt(0); out.writeInt(error.length); out.write(error); out.flush();
                    socket.setSoTimeout(3000); socket.getInputStream().read();
                }
            } catch(Exception ignored) {} finally {
                closeSocket(); runOnUiThread(() -> finishAndRemoveTask());
            }
        }).start();
    }
    private void closeSocket() { if (socket != null) try {socket.close();} catch (Exception ignored) {} }
    @Override protected void onDestroy() { if (cancel != null) cancel.cancel(); closeSocket(); super.onDestroy(); }
}
