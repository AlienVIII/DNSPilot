use dnspilot_core::connect_probe::{
    probe_tcp_connect_once, run_tcp_connect_probes_with_connector, ConnectProbeConfig,
    ConnectProbeError, ConnectProbeOutcome, TcpConnectTarget,
};
use std::net::{SocketAddr, TcpListener};
use std::thread;
use std::time::Duration;

#[test]
fn connects_to_local_tcp_listener_and_records_elapsed() {
    let listener = TcpListener::bind("127.0.0.1:0").expect("bind local TCP listener");
    let endpoint = listener.local_addr().expect("listener addr");

    thread::spawn(move || {
        let _ = listener.accept().expect("accept one TCP connection");
    });

    let target = TcpConnectTarget {
        domain: "example.com".into(),
        endpoint,
    };
    let elapsed = probe_tcp_connect_once(&target, Duration::from_millis(500))
        .expect("local TCP listener should accept");

    assert!(elapsed < Duration::from_millis(500));
}

#[test]
fn reports_failure_when_tcp_port_is_closed() {
    let socket = TcpListener::bind("127.0.0.1:0").expect("bind unused TCP port");
    let endpoint = socket.local_addr().expect("listener addr");
    drop(socket);

    let target = TcpConnectTarget {
        domain: "example.com".into(),
        endpoint,
    };
    let error = probe_tcp_connect_once(&target, Duration::from_millis(100))
        .expect_err("closed TCP port should fail");

    assert!(matches!(
        error,
        ConnectProbeError::Timeout | ConnectProbeError::Io(_)
    ));
}

#[test]
fn aggregates_tcp_connect_samples() {
    let target = TcpConnectTarget {
        domain: "example.com".into(),
        endpoint: "127.0.0.1:443".parse::<SocketAddr>().expect("socket addr"),
    };
    let config = ConnectProbeConfig {
        targets: vec![target],
        attempts_per_target: 4,
        timeout: Duration::from_millis(250),
    };
    let mut outcomes = vec![
        Ok(Duration::from_millis(20)),
        Ok(Duration::from_millis(40)),
        Err(ConnectProbeError::Timeout),
        Ok(Duration::from_millis(80)),
    ]
    .into_iter();

    let run = run_tcp_connect_probes_with_connector(&config, |_target| {
        outcomes.next().expect("one outcome per connect attempt")
    });

    assert_eq!(run.samples.len(), 4);
    assert_eq!(run.median_connect_latency_ms, 40.0);
    assert_eq!(run.p95_connect_latency_ms, 80.0);
    assert_eq!(run.failure_rate, 0.25);
    assert_eq!(run.timeout_rate, 0.25);
    assert!(matches!(run.samples[2].outcome, ConnectProbeOutcome::Timeout));
}

