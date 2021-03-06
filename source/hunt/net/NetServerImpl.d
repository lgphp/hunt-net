module hunt.net.NetServerImpl;

import hunt.net.Connection;
import hunt.net.codec;
import hunt.net.NetServer;
import hunt.net.NetServerOptions;
import hunt.net.TcpConnection;

import hunt.event; 
import hunt.io;
import hunt.logging;
import hunt.util.Lifecycle;

import core.atomic;
import std.conv;
import std.parallelism;
import std.socket;

enum ThreadMode {
    Single,
    Multi
}

import hunt.util.DateTime;

shared static this() {
    DateTime.startClock();
}

shared static ~this() @nogc {
    DateTime.stopClock();
}


/**
*/
class NetServerImpl(ThreadMode threadModel = ThreadMode.Single) : AbstractLifecycle, NetServer {
    private string _host = NetServerOptions.DEFAULT_HOST;
    private int _port = NetServerOptions.DEFAULT_PORT;
    protected bool _isStarted;
    private shared int _connectionId;
    private NetServerOptions _options;
    private Codec _codec;
    private NetConnectionHandler _connectHandler;
    protected EventLoopGroup _group = null;

	protected Address _address;

    this(EventLoopGroup loopGroup) {
        this(loopGroup, new NetServerOptions());
    }

    this(EventLoopGroup loopGroup, NetServerOptions options) {
        this._group = loopGroup;
        _options = options;
    }

    NetServerOptions getOptions() {
        return _options;
    }
    
    NetServer setOptions(NetServerOptions options) {
        _options = options;
        return this;
    }

    NetServer setCodec(Codec codec) {
        this._codec = codec;
        return this;
    }

    Codec getCodec() {
        return this._codec;
    }

    NetConnectionHandler getHandler() {
        return _connectHandler;
    }

    NetServer setHandler(NetConnectionHandler handler) {
        _connectHandler = handler;
        return this;
    }

    @property Address bindingAddress() {
		return _address;
	}


    void listen() {
        listen("0.0.0.0", 0);
    }

    void listen(int port) {
        listen("0.0.0.0", port);
    }

    void listen(string host, int port) {
        _host = host;
        _port = port;

        if (_isStarted)
			return;
        _address = new InternetAddress(host, cast(ushort)port);

		version(HUNT_DEBUG) infof("Start to listen on %s:%d", host, port);
        _group.start();

        try {

            static if(threadModel == ThreadMode.Multi) {   
                listeners = new TcpListener[_group.size];         
                for (size_t i = 0; i < _group.size; ++i) {
                    listeners[i] = createServer(_group[i]);
                    version(HUNT_DEBUG) infof("lister[%d] created", i);
                }
                version(HUNT_DEBUG) infof("All the servers are listening on %s.", _address.toString());
            } else {
                tcpListener = new TcpSocket();

                version (Windows) {
                    import core.sys.windows.winsock2;
                    bool flag = this._options.isReuseAddress() || this._options.isReusePort();
                    tcpListener.setOption(SocketOptionLevel.SOCKET, cast(SocketOption) SO_EXCLUSIVEADDRUSE, !flag);
                } else {
                    tcpListener.setOption(SocketOptionLevel.SOCKET, 
                        SocketOption.REUSEADDR, _options.isReuseAddress());

                    tcpListener.setOption(SocketOptionLevel.SOCKET, 
                        cast(SocketOption) SO_REUSEPORT, _options.isReusePort());
                }

                tcpListener.bind(_address);
                tcpListener.listen(1000);

                version(HUNT_DEBUG) {
                    infof("Server is listening on %s%s.", _address.toString(), 
                        _options.isSsl ? " (with SSL)" : "");
                }
            }     

		    _isStarted = true;
            
        } catch (Exception e) {
            warning(e.message);
            if (_connectHandler !is null)
                _connectHandler.failedOpeningConnection(0, e);
        }

        // if (handler !is null)
        //     handler(result);

        static if(threadModel == ThreadMode.Single) {
            auto theTask = task(&waitingForAccept);
            // taskPool.put(theTask);
            theTask.executeInNewThread();
        }
    }

    override protected void initialize() {
        listen(_host, _port);
    }

static if(threadModel == ThreadMode.Multi){
    private TcpListener[] listeners;

    protected TcpListener createServer(EventLoop loop) {
		TcpListener listener = new TcpListener(loop, _address.addressFamily);

		listener.reusePort(true);
		listener.bind(_address).listen(1024);
        listener.onConnectionAccepted((TcpListener sender, TcpStream stream) {
                auto currentId = atomicOp!("+=")(_connectionId, 1);
                version(HUNT_DEBUG) tracef("new tcp connection: id=%d", currentId);
                TcpConnection connection = new TcpConnection(currentId, _options, _connectHandler, stream);
                // connection.setState(ConnectionState.Opened);
                if (_connectHandler !is null)
                    _connectHandler.notifyConnectionOpened(connection);
            });
		listener.start();

        return listener;
	}

    override protected void destroy() {
        if(_isStarted) {
            foreach(TcpListener ls; listeners) {
                if (ls !is null)
                    ls.close();
            }
        }
    }

} else {
    private Socket tcpListener;

    private void waitingForAccept() {
        while (_isStarted) {
			try {
				version (HUNT_DEBUG) {
					tracef("Waiting for accept on %s:%d...", _host, _port);
                }
				Socket client = tcpListener.accept();
                // processClient(client);
                
                auto processTask = task(&processClient, client);
                taskPool.put(processTask);
			} catch (Throwable e) {
				warningf("Failure on accept %s", e.msg);
				version(HUNT_DEBUG) warning(e);
				_isStarted = false;
			}
		}
    }
    
	private void processClient(Socket socket) {
        version(HUNT_METRIC) {
            import core.time;
            import hunt.util.DateTime;
            debug trace("processing client...");
            MonoTime startTime = MonoTime.currTime;
        }
        
		version (HUNT_DEBUG) {
			infof("new connection from %s, fd=%d", socket.remoteAddress.toString(), socket.handle());
		}

        TcpStreamOptions streamOptions = _options.toStreamOptions();

		EventLoop loop = _group.nextLoop();
		TcpStream stream = new TcpStream(loop, socket, streamOptions);

        auto currentId = atomicOp!("+=")(_connectionId, 1);
        version(HUNT_DEBUG) tracef("new tcp connection: id=%d", currentId);
        Connection connection = new TcpConnection(currentId, _options, _connectHandler, _codec, stream);
        // connection.setState(ConnectionState.Opened);
        if (_connectHandler !is null) {
            _connectHandler.connectionOpened(connection);
        }
		stream.start();

        version(HUNT_METRIC) { 
            Duration timeElapsed = MonoTime.currTime - startTime;
            warningf("peer connection processing done in: %d microseconds",
                timeElapsed.total!(TimeUnit.Microsecond)());
        }
	}

    int actualPort() {
        return _port;
    }

    override void close() {
        this.stop();
    }

    override protected void destroy() {
        if(_isStarted && tcpListener !is null) {
            tcpListener.close();
        }
    }

    bool isOpen() {
        return _isStarted;
    }
}    
}
