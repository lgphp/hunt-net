module hunt.net.secure.conscrypt.NativeSslSession;

version(BoringSSL) {
    version=WithSSL;
} else version(OpenSSL) {
    version=WithSSL;
}
version(WithSSL):

import hunt.net.secure.conscrypt.AbstractSessionContext;
import hunt.net.secure.conscrypt.ClientSessionContext;
import hunt.net.secure.conscrypt.ConscryptSession;
import hunt.net.secure.conscrypt.NativeRef;
import hunt.net.secure.conscrypt.NativeCrypto;
import hunt.net.secure.conscrypt.NativeSsl;

import hunt.net.ssl.SSLSession;
import hunt.net.ssl.SSLSessionContext;

import hunt.security.Principal;
import hunt.security.cert.Certificate;
import hunt.security.cert.X509Certificate;

import hunt.util.exception;

import hunt.container;
import hunt.logging;

import std.algorithm;
import std.conv;



/**
 * A utility wrapper that abstracts operations on the underlying native SSL_SESSION instance.
 *
 * This is abstract only to support mocking for tests.
 */
abstract class NativeSslSession {

    /**
     * Creates a new instance. Since BoringSSL does not provide an API to get access to all
     * session information via the SSL_SESSION, we get some values (e.g. peer certs) from
     * the {@link ConscryptSession} instead (i.e. the SSL object).
     */
    static NativeSslSession newInstance(NativeRef.SSL_SESSION _ref, ConscryptSession session) {
        AbstractSessionContext context = cast(AbstractSessionContext) session.getSessionContext();
        if (typeid(context) == typeid(ClientSessionContext)) {
            return new Impl(context, _ref, session.getPeerHost(), session.getPeerPort(),
                cast(X509Certificate[])session.getPeerCertificates(), getOcspResponse(session),
                session.getPeerSignedCertificateTimestamp());
        }

        // Server's will be cached by ID and won't have any of the extra fields.
        return new Impl(context, _ref, null, -1, null, null, null);
    }

    private static byte[] getOcspResponse(ConscryptSession session) {
        List!(byte[]) ocspResponseList = session.getStatusResponses();
        if (ocspResponseList.size() >= 1) {
            return ocspResponseList.get(0);
        }
        return null;
    }

    /**
     * Creates a new {@link NativeSslSession} instance from the provided serialized bytes, which
     * were generated by {@link #toBytes()}.
     *
     * @return The new instance if successful. If unable to parse the bytes for any reason, returns
     * {@code null}.
     */
    static NativeSslSession newInstance(AbstractSessionContext context, 
        byte[] data, string host, int port) {

            implementationMissing();
            return null;

        // ByteBuffer buf = ByteBuffer.wrap(data);
        // try {
        //     int type = buf.getInt();
        //     if (!isSupportedType(type)) {
        //         throw new IOException("Unexpected type ID: " ~ type.to!string());
        //     }

        //     int length = buf.getInt();
        //     checkRemaining(buf, length);

        //     byte[] sessionData = new byte[length];
        //     buf.get(sessionData);

        //     int count = buf.getInt();
        //     checkRemaining(buf, count);

        //     X509Certificate[] peerCerts =
        //             new X509Certificate[count];
        //     for (int i = 0; i < count; i++) {
        //         length = buf.getInt();
        //         checkRemaining(buf, length);

        //         byte[] certData = new byte[length];
        //         buf.get(certData);
        //         try {
        //             peerCerts[i] = OpenSSLX509Certificate.fromX509Der(certData);
        //         } catch (Exception e) {
        //             throw new IOException("Can not read certificate " ~ i.to!string() ~ "/" ~ count.to!string());
        //         }
        //     }

        //     byte[] ocspData = null;
        //     if (type >= OPEN_SSL_WITH_OCSP.value) {
        //         // We only support one OCSP response now, but in the future
        //         // we may support RFC 6961 which has multiple.
        //         int countOcspResponses = buf.getInt();
        //         checkRemaining(buf, countOcspResponses);

        //         if (countOcspResponses >= 1) {
        //             int ocspLength = buf.getInt();
        //             checkRemaining(buf, ocspLength);

        //             ocspData = new byte[ocspLength];
        //             buf.get(ocspData);

        //             // Skip the rest of the responses.
        //             for (int i = 1; i < countOcspResponses; i++) {
        //                 ocspLength = buf.getInt();
        //                 checkRemaining(buf, ocspLength);
        //                 buf.position(buf.position() + ocspLength);
        //             }
        //         }
        //     }

        //     byte[] tlsSctData = null;
        //     if (type == OPEN_SSL_WITH_TLS_SCT.value) {
        //         int tlsSctDataLength = buf.getInt();
        //         checkRemaining(buf, tlsSctDataLength);

        //         if (tlsSctDataLength > 0) {
        //             tlsSctData = new byte[tlsSctDataLength];
        //             buf.get(tlsSctData);
        //         }
        //     }

        //     if (buf.remaining() != 0) {
        //         log(new AssertionError("Read entire session, but data still remains; rejecting"));
        //         return null;
        //     }

        //     // NativeRef.SSL_SESSION _ref = new NativeRef.SSL_SESSION(NativeCrypto.d2i_SSL_SESSION(sessionData));
        //     // return new Impl(context, _ref, host, port, peerCerts, ocspData, tlsSctData);
        // } catch (IOException e) {
        //     log(e);
        //     return null;
        // } catch (BufferUnderflowException e) {
        //     log(e);
        //     return null;
        // }
    }

    abstract byte[] getId();

    abstract bool isValid();

    abstract void offerToResume(NativeSsl ssl);

    abstract string getCipherSuite();

    abstract string getProtocol();

    abstract string getPeerHost();

    abstract int getPeerPort();

    /**
     * Returns the OCSP stapled response. The returned array is not copied; the caller must
     * either not modify the returned array or make a copy.
     *
     * @see <a href="https://tools.ietf.org/html/rfc6066">RFC 6066</a>
     * @see <a href="https://tools.ietf.org/html/rfc6961">RFC 6961</a>
     */
    abstract byte[] getPeerOcspStapledResponse();

    /**
     * Returns the signed certificate timestamp (SCT) received from the peer. The returned array
     * is not copied; the caller must either not modify the returned array or make a copy.
     *
     * @see <a href="https://tools.ietf.org/html/rfc6962">RFC 6962</a>
     */
    abstract byte[] getPeerSignedCertificateTimestamp();

    /**
     * Converts the given session to bytes.
     *
     * @return session data as bytes or null if the session can't be converted
     */
    abstract byte[] toBytes();

    /**
     * Converts this object to a {@link SSLSession}. The returned session will support only a
     * subset of the {@link SSLSession} API.
     */
    abstract SSLSession toSSLSession();

    /**
     * The session wrapper implementation.
     */
    private static final class Impl : NativeSslSession {
        private NativeRef.SSL_SESSION _ref;

        // BoringSSL offers no API to obtain these values directly from the SSL_SESSION.
        private AbstractSessionContext context;
        private string host;
        private int port;
        private string protocol;
        private string cipherSuite;
        private X509Certificate[] peerCertificates;
        private byte[] peerOcspStapledResponse;
        private byte[] peerSignedCertificateTimestamp;

        private this(AbstractSessionContext context, NativeRef.SSL_SESSION sslRef, string host,
                int port, X509Certificate[] peerCertificates,
                byte[] peerOcspStapledResponse, byte[] peerSignedCertificateTimestamp) {
            this.context = context;
            this.host = host;
            this.port = port;
            this.peerCertificates = peerCertificates;
            this.peerOcspStapledResponse = peerOcspStapledResponse;
            this.peerSignedCertificateTimestamp = peerSignedCertificateTimestamp;
            // this.protocol = NativeCrypto.SSL_SESSION_get_version(_ref.context);
            // this.cipherSuite =
            //         NativeCrypto.cipherSuiteToJava(NativeCrypto.SSL_SESSION_cipher(_ref.context));
            this._ref = _ref;
implementationMissing();
        }

        override
        byte[] getId() {
            return NativeCrypto.SSL_SESSION_session_id(_ref.context);
        }

        private long getCreationTime() {
            return NativeCrypto.SSL_SESSION_get_time(_ref.context);
        }

        override
        bool isValid() {
            // long creationTimeMillis = getCreationTime();
            // // Use the minimum of the timeout from the context and the session.
            // long timeoutMillis = max(0, min(context.getSessionTimeout(),
            //                                      NativeCrypto.SSL_SESSION_get_timeout(_ref.context)))
            //         * 1000;
            // return (System.currentTimeMillis() - timeoutMillis) < creationTimeMillis;
            implementationMissing();
            return true;
        }

        override
        void offerToResume(NativeSsl ssl) {
            ssl.offerToResumeSession(_ref.context);
        }

        override
        string getCipherSuite() {
            return cipherSuite;
        }

        override
        string getProtocol() {
            return protocol;
        }

        override
        string getPeerHost() {
            return host;
        }

        override
        int getPeerPort() {
            return port;
        }

        override
        byte[] getPeerOcspStapledResponse() {
            return peerOcspStapledResponse;
        }

        override
        byte[] getPeerSignedCertificateTimestamp() {
            return peerSignedCertificateTimestamp;
        }

        override
        byte[] toBytes() {
            implementationMissing();
            return null;
            // try {
            //     ByteArrayOutputStream baos = new ByteArrayOutputStream();
            //     DataOutputStream daos = new DataOutputStream(baos);

            //     daos.writeInt(OPEN_SSL_WITH_TLS_SCT.value); // session type ID

            //     // Session data.
            //     byte[] data = NativeCrypto.i2d_SSL_SESSION(_ref.context);
            //     daos.writeInt(data.length);
            //     daos.write(data);

            //     // Certificates.
            //     daos.writeInt(peerCertificates.length);

            //     foreach (Certificate cert ; peerCertificates) {
            //         data = cert.getEncoded();
            //         daos.writeInt(data.length);
            //         daos.write(data);
            //     }

            //     if (peerOcspStapledResponse != null) {
            //         daos.writeInt(1);
            //         daos.writeInt(peerOcspStapledResponse.length);
            //         daos.write(peerOcspStapledResponse);
            //     } else {
            //         daos.writeInt(0);
            //     }

            //     if (peerSignedCertificateTimestamp != null) {
            //         daos.writeInt(peerSignedCertificateTimestamp.length);
            //         daos.write(peerSignedCertificateTimestamp);
            //     } else {
            //         daos.writeInt(0);
            //     }

            //     // TODO: local certificates?

            //     return baos.toByteArray();
            // } catch (IOException e) {
            //     // TODO(nathanmittler): Better error handling?
            //     warningf("Failed to convert saved SSL Session: %s", e.msg);
            //     return null;
            // } catch (Exception e) {
            //     error(e.msg);
            //     return null;
            // }
        }

        override
        SSLSession toSSLSession() {
            return new InnerSSLSession();
        }

        private class InnerSSLSession : SSLSession {
                override
                public byte[] getId() {
                    return this.outer.getId();
                }

                override
                public string getCipherSuite() {
                    return this.outer.getCipherSuite();
                }

                override
                public string getProtocol() {
                    return this.outer.getProtocol();
                }

                override
                public string getPeerHost() {
                    return this.outer.getPeerHost();
                }

                override
                public int getPeerPort() {
                    return this.outer.getPeerPort();
                }

                override
                public long getCreationTime() {
                    return this.outer.getCreationTime();
                }

                override
                public bool isValid() {
                    return this.outer.isValid();
                }

                // UNSUPPORTED OPERATIONS

                override
                public SSLSessionContext getSessionContext() {
                    throw new UnsupportedOperationException("");
                }

                override
                public long getLastAccessedTime() {
                    throw new UnsupportedOperationException("");
                }

                override
                public void invalidate() {
                    throw new UnsupportedOperationException("");
                }

                override
                public void putValue(string s, Object o) {
                    throw new UnsupportedOperationException("");
                }

                override
                public Object getValue(string s) {
                    throw new UnsupportedOperationException("");
                }

                override
                public void removeValue(string s) {
                    throw new UnsupportedOperationException("");
                }

                override
                public string[] getValueNames() {
                    throw new UnsupportedOperationException("");
                }

                override
                public Certificate[] getPeerCertificates() {
                    throw new UnsupportedOperationException("");
                }

                override
                public Certificate[] getLocalCertificates() {
                    throw new UnsupportedOperationException("");
                }

                override
                public X509Certificate[] getPeerCertificateChain() {
                    throw new UnsupportedOperationException("");
                }

                override
                public Principal getPeerPrincipal() {
                    throw new UnsupportedOperationException("");
                }

                override
                public Principal getLocalPrincipal() {
                    throw new UnsupportedOperationException("");
                }

                override
                public int getPacketBufferSize() {
                    throw new UnsupportedOperationException("");
                }

                override
                public int getApplicationBufferSize() {
                    throw new UnsupportedOperationException("");
                }
            }
    }

    // private static void log(Throwable t) {
    //     // TODO(nathanmittler): Better error handling?
    //     logger.log(Level.INFO, "Error inflating SSL session: {0}",
    //             (t.getMessage() != null ? t.getMessage() : t.getClass().getName()));
    // }

    private static void checkRemaining(ByteBuffer buf, int length) {
        if (length < 0) {
            throw new IOException("Length is negative: " ~ length.to!string());
        }
        if (length > buf.remaining()) {
            throw new IOException(
                    "Length of blob is longer than available: " ~ length.to!string() ~ " > " ~ buf.remaining().to!string());
        }
    }
}
