module hunt.net.NetClientImpl;

import hunt.event.EventLoop;
import hunt.io.TcpStream;


import hunt.net.TcpConnection;
import hunt.net.NetClientOptions;
import hunt.net.Connection;
import hunt.net.AsyncResult;
import hunt.net.codec.Codec;
import hunt.net.NetClient;

import hunt.logging;

///
class NetClientImpl : AbstractClient {
    private string _host = "127.0.0.1";
    private int _port = 8080;
    private int _sessionId;
    private NetClientOptions _config;
    private ConnectionEventHandler _netHandler;
    private Codec _codec;
    private AsynchronousTcpSession _tcpSession;
    private bool _isConnected = false;
    private TcpStream _client;
    private int _loopIdleTime = -1;

    this() {
        _loop = new EventLoop();
    }

    this(EventLoop loop) {
        _loop = loop;
    }

    ~this() {
        this.stop();
    }

    string getHost() {
        return _host;
    }

    void setHost(string host) {
        this._host = host;
    }

    int getPort() {
        return _port;
    }

    void setPort(int port) {
        this._port = port;
    }

    void close() {
        this.stop();
    }

    NetClient setCodec(Codec codec) {
        this._codec = codec;
        return this;
    }

    NetClient setHandler(ConnectionEventHandler handler) {
        this._netHandler = handler;
        return this;
    }

    void connect(int sessionId = 0) {
        return connect(_port, _host, sessionId);
    }

    void connect(int port, string host, int sessionId = 0) {
        _host = host;
        _port = port;
        _sessionId = sessionId;

        _client = new TcpStream(_loop);

        _tcpSession = new AsynchronousTcpSession(sessionId,
                _config, _netHandler, _codec, _client);


        _client.onClosed(() {
            _isConnected = false;
            if (_netHandler !is null)
                _netHandler.sessionClosed(_tcpSession);
        });

        _client.onError((string message) {
            _isConnected = false;
            if (_netHandler !is null)
                _netHandler.exceptionCaught(_tcpSession, new Exception(message));
        });

        _client.onConnected((bool suc) {
            // AsyncResult!NetSocket result = null;
            _isConnected = suc;
            if (suc) {
			    version (HUNT_DEBUG) 
                trace("connected to: ", _client.remoteAddress.toString()); 

                // if (_handler !is null)
                //     _handler(_tcpSession);
                // result = succeededResult!(NetSocket)(_tcpSession);
                _isRunning = true;
                if (_netHandler !is null)
                    _netHandler.sessionOpened(_tcpSession);
            }
            else {
			    version (HUNT_DEBUG) 
                    warning("connection failed!"); 
                import std.format;
                string msg = format("Failed to connect to %s:%d", host, port);
                // result = failedResult!(NetSocket)(new Exception(msg));

                if(_netHandler !is null)
                    _netHandler.failedOpeningSession(sessionId, new Exception(msg));
                
                // if(_config !is null)
                //     _config.getHandler().failedOpeningSession(sessionId,
                //         new Exception(msg));
            }

            // if (handler !is null)
            //     handler(result);
        }).connect(host, cast(ushort) port);

        _loop.runAsync(_loopIdleTime);
    }


    int connect(string host, int port) {
        int id = _sessionId + 1;
        connect(port, host, id);
        return id;
    }

    void connect(string host, int port, int sessionId) {
        connect(port, host, sessionId);
    }

    override protected void initialize() {
        connect(_port, _host);
    }

    override protected void destroy() {
        if (_tcpSession !is null) {
            _isConnected = false;
            _loop.stop();
            _tcpSession.close();
        }
    }

    bool isConnected() {
        return _isConnected;
    }

private:
    ///
    EventLoop _loop;
}