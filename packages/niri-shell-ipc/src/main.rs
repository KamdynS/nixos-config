mod dbus;
mod niri;
mod state;

use anyhow::Result;
use tracing::{info, error};
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

    // Create shared state
    let state = state::SharedState::new();

    // Start niri client (event stream listener)
    let niri_state = state.clone();
    let niri_handle = tokio::spawn(async move {
        if let Err(e) = niri::run_client(&socket_path, niri_state).await {
            error!("Niri client error: {}", e);
        }
    });

    // Start DBus server
    let dbus_state = state.clone();
    let dbus_handle = tokio::spawn(async move {
        if let Err(e) = dbus::run_server(dbus_state).await {
            error!("DBus server error: {}", e);
        }
    });

    // Wait for both tasks
    tokio::select! {
        _ = niri_handle => {
            error!("Niri client task ended unexpectedly");
        }
        _ = dbus_handle => {
            error!("DBus server task ended unexpectedly");
        }
    }

    Ok(())
}
