mod apps;
mod audio;
mod bluetooth;
mod brightness;
mod dbus;
mod media;
mod network;
mod niri;
mod notifications;
mod power;
mod state;
mod system;

use anyhow::Result;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{error, info};
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

#[tokio::main]
async fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| "info".into()))
        .with(tracing_subscriber::fmt::layer())
        .init();

    info!("Starting niri-shell-ipc daemon");

    // Get niri socket path
    let socket_path = std::env::var("NIRI_SOCKET")
        .map_err(|_| anyhow::anyhow!("NIRI_SOCKET environment variable not set. Is niri running?"))?;

    info!("Connecting to niri socket: {}", socket_path);

    // Create shared state for niri
    let state = state::State::new();

    // Create shared state for power
    let power_state: power::SharedPowerState = Arc::new(RwLock::new(power::PowerState::default()));

    // Create shared state for system stats
    let system_state: system::SharedSystemState = Arc::new(RwLock::new(system::SystemState::new()));

    // Create shared state for media
    let media_state: media::SharedMediaState = Arc::new(RwLock::new(media::MediaState::default()));

    // Create shared state for brightness
    let brightness_state: brightness::SharedBrightnessState = Arc::new(RwLock::new(brightness::BrightnessState::new()));

    // Create shared state for network
    let network_state: network::SharedNetworkState = Arc::new(RwLock::new(network::NetworkState::default()));

    // Create shared state for bluetooth
    let bluetooth_state: bluetooth::SharedBluetoothState = Arc::new(RwLock::new(bluetooth::BluetoothState::default()));

    // Create shared state for notifications
    let notifications_state: notifications::SharedNotificationState = Arc::new(RwLock::new(notifications::NotificationState::default()));

    // Start niri client (event stream listener)
    let niri_state = state.clone();
    let niri_handle = tokio::spawn(async move {
        if let Err(e) = niri::run_client(&socket_path, niri_state).await {
            error!("Niri client error: {}", e);
        }
    });

    // Initialize apps state (scans desktop entries)
    info!("Scanning desktop entries...");
    let apps_state = apps::init_apps_state().await;

    // Create DBus connection with Niri interface
    let conn = dbus::create_connection(state.clone()).await?;

    // Register power interface on same connection
    let power_state_dbus = power_state.clone();
    power::run_power_dbus(&conn, power_state_dbus).await?;

    // Register apps interface
    apps::run_apps_dbus(&conn, apps_state.clone()).await?;

    // Initialize audio (spawns PulseAudio thread)
    let (audio_state, audio_cmd_tx) = audio::init_audio_state();
    // Give PulseAudio a moment to connect
    tokio::time::sleep(tokio::time::Duration::from_millis(200)).await;
    audio::run_audio_dbus(&conn, audio_state.clone(), audio_cmd_tx).await?;

    // Register system interface
    system::run_system_dbus(&conn, system_state.clone()).await?;

    // Register media interface
    media::run_media_dbus(&conn, media_state.clone()).await?;

    // Register brightness interface
    brightness::run_brightness_dbus(&conn, brightness_state.clone()).await?;

    // Register network interface
    network::run_network_dbus(&conn, network_state.clone()).await?;

    // Register bluetooth interface (needs system bus connection)
    let bt_system_conn = zbus::Connection::system().await.ok();
    if let Some(system_conn) = bt_system_conn {
        bluetooth::run_bluetooth_dbus(&conn, bluetooth_state.clone(), system_conn).await?;
    } else {
        info!("Bluetooth: system bus unavailable, skipping");
    }

    // Register notifications interface (claims org.freedesktop.Notifications)
    notifications::run_notifications_dbus(&conn, notifications_state.clone()).await?;

    // Start power monitor (connects to system bus UPower)
    let power_state_monitor = power_state.clone();
    let power_handle = tokio::spawn(async move {
        if let Err(e) = power::run_power_service(power_state_monitor).await {
            error!("Power service error: {}", e);
        }
    });

    // Start system stats collection
    let system_state_service = system_state.clone();
    let system_conn = conn.clone();
    let system_handle = tokio::spawn(async move {
        system::run_system_service(system_state_service, system_conn).await;
    });

    // Start media service (MPRIS aggregator)
    let media_state_service = media_state.clone();
    let media_conn = conn.clone();
    let media_handle = tokio::spawn(async move {
        media::run_media_service(media_state_service, media_conn).await;
    });

    // Start network service (NetworkManager watcher)
    let network_state_service = network_state.clone();
    let network_conn = conn.clone();
    let network_handle = tokio::spawn(async move {
        network::run_network_service(network_state_service, network_conn).await;
    });

    // Start bluetooth service (BlueZ watcher)
    let bluetooth_state_service = bluetooth_state.clone();
    let bluetooth_conn = conn.clone();
    let bluetooth_handle = tokio::spawn(async move {
        bluetooth::run_bluetooth_service(bluetooth_state_service, bluetooth_conn).await;
    });

    // Start DBus event loop (signal emitter)
    let dbus_state = state.clone();
    let dbus_handle = tokio::spawn(async move {
        if let Err(e) = dbus::run_server(conn, dbus_state).await {
            error!("DBus server error: {}", e);
        }
    });

    // Wait for tasks
    tokio::select! {
        _ = niri_handle => {
            error!("Niri client task ended unexpectedly");
        }
        _ = dbus_handle => {
            error!("DBus server task ended unexpectedly");
        }
        _ = power_handle => {
            error!("Power service task ended unexpectedly");
        }
        _ = system_handle => {
            error!("System service task ended unexpectedly");
        }
        _ = media_handle => {
            error!("Media service task ended unexpectedly");
        }
        _ = network_handle => {
            error!("Network service task ended unexpectedly");
        }
        _ = bluetooth_handle => {
            error!("Bluetooth service task ended unexpectedly");
        }
    }

    Ok(())
}
