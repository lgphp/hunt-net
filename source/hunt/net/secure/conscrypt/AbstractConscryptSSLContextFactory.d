module hunt.net.secure.conscrypt.AbstractConscryptSSLContextFactory;

import hunt.net.ssl.KeyManager;
import hunt.net.secure.ProtocolSelector;
import hunt.net.secure.conscrypt.ConscryptALPNSelector;

import hunt.net.secure.SSLContextFactory;
import hunt.net.ssl;

import hunt.io.common;

import hunt.util.exception;
import hunt.util.datetime;
import hunt.util.TypeUtils;

import kiss.logger;

import std.datetime;
import std.typecons;


/**
*/
abstract class AbstractConscryptSSLContextFactory : SSLContextFactory {

    private enum string provideName = "Conscrypt";
    private string[] supportedProtocols;

    // static this() {
    //     // Provider provider = Conscrypt.newProvider();
    //     // provideName = provider.getName();
    //     // Security.addProvider(provider);
    //     // provideName = "Conscrypt";
    //     infof("add Conscrypt security provider");
    // }

    static string getProvideName() {
        return provideName;
    }

    SSLContext getSSLContextWithManager(KeyManager[] km, TrustManager[] tm){
        long start = Clock.currStdTime;
        SSLContext sslContext = SSLContext.getInstance("TLSv1.2", provideName);
        sslContext.init(km, tm);
        long end = Clock.currStdTime;
        long d = convert!(TimeUnits.HectoNanosecond, TimeUnits.Millisecond)(end - start);
        version(HuntDebugMode) tracef("creating Conscrypt SSL context spends %d ms", d);
        return sslContext;
    }

    SSLContext getSSLContext(InputStream inputStream, string keystorePassword, string keyPassword) {
        return getSSLContext(inputStream, keystorePassword, keyPassword, null, null, null);
    }

    SSLContext getSSLContext(InputStream inputStream, string keystorePassword, string keyPassword,
                                    string keyManagerFactoryType, string trustManagerFactoryType, string sslProtocol) {
        // long start = Millisecond100Clock.currentTimeMillis();
        // SSLContext sslContext;

        // KeyStore ks = KeyStore.getInstance("JKS");
        // ks.load(inputStream, keystorePassword !is null ? keystorePassword.toCharArray() : null);

        // // PKIX,SunX509
        // KeyManagerFactory kmf = KeyManagerFactory.getInstance(keyManagerFactoryType == null ? "SunX509" : keyManagerFactoryType);
        // kmf.init(ks, keyPassword !is null ? keyPassword.toCharArray() : null);

        // TrustManagerFactory tmf = TrustManagerFactory.getInstance(trustManagerFactoryType == null ? "SunX509" : trustManagerFactoryType);
        // tmf.init(ks);

        // // TLSv1 TLSv1.2
        // sslContext = SSLContext.getInstance(sslProtocol == null ? "TLSv1.2" : sslProtocol, provideName);
        // sslContext.init(kmf.getKeyManagers(), tmf.getTrustManagers(), null);

        // long end = Millisecond100Clock.currentTimeMillis();
        // infof("creating Conscrypt SSL context spends %s ms", (end - start));
        // return sslContext;
        implementationMissing();
        return null;
    }

    abstract SSLContext getSSLContext();

    override
    Pair!(SSLEngine, ProtocolSelector) createSSLEngine(bool clientMode) {
        SSLEngine sslEngine = getSSLContext().createSSLEngine();
        sslEngine.setUseClientMode(clientMode);
        return makePair(sslEngine, cast(ProtocolSelector)new ConscryptALPNSelector(sslEngine, supportedProtocols));
    }

    override
    Pair!(SSLEngine, ProtocolSelector) createSSLEngine(bool clientMode, string peerHost, int peerPort) {
        SSLEngine sslEngine = getSSLContext().createSSLEngine(peerHost, peerPort);
        sslEngine.setUseClientMode(clientMode);
        return makePair(sslEngine, cast(ProtocolSelector)new ConscryptALPNSelector(sslEngine, supportedProtocols));
    }

    override
    string[] getSupportedProtocols() {
        return supportedProtocols;
    }

    override
    void setSupportedProtocols(string[] supportedProtocols) {
        this.supportedProtocols = supportedProtocols;
    }
}
