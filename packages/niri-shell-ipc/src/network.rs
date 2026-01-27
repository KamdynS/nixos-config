//! Network state interface via NetworkManager
//!
//! Provides WiFi and network connection state via NetworkManager DBus API.

use futures::StreamExt;
use serde::Serialize;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, error, info, warn};
use zbus::{interface, object_server::SignalEmitter, proxy, Connection};

pub type SharedNetworkState = Arc<RwLock<NetworkState>>;

#[derive(Debug, Clone, Default, Serialize)]
pub struct ConnectionInfo {
    pub id: String,
    pub uuid: String,
    pub connection_type: String,
    pub device: String,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct WifiInfo {
    pub ssid: String,
    pub signal_strength: u8,
    pub security: String,
    pub connected: bool,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct WifiNetwork {
    pub ssid: String,
    pub signal_strength: u8,
    pub security: String,
    pub connected: bool,
    pub saved: bool,
}

#[derive(Debug, Clone, Default)]
pub struct NetworkState {
    pub state: String, // "connected", "disconnected", "connecting"
    pub wifi_enabled: bool,
    pub wifi: Option<WifiInfo>,
    pub active_connections: Vec<ConnectionInfo>,
    pub wifi_networks: Vec<WifiNetwork>,
}

// NetworkManager proxies
#[proxy(
    interface = "org.freedesktop.NetworkManager",
    default_service = "org.freedesktop.NetworkManager",
    default_path = "/org/freedesktop/NetworkManager"
)]
trait NetworkManager {
    #[zbus(property)]
    fn state(&self) -> zbus::Result<u32>;

    #[zbus(property)]
    fn wireless_enabled(&self) -> zbus::Result<bool>;

    #[zbus(property)]
    fn wireless_hardware_enabled(&self) -> zbus::Result<bool>;

    #[zbus(property)]
    fn active_connections(&self) -> zbus::Result<Vec<zbus::zvariant::OwnedObjectPath>>;

    #[zbus(property)]
    fn primary_connection(&self) -> zbus::Result<zbus::zvariant::OwnedObjectPath>;

    fn get_devices(&self) -> zbus::Result<Vec<zbus::zvariant::OwnedObjectPath>>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Connection.Active",
    default_service = "org.freedesktop.NetworkManager"
)]
trait ActiveConnection {
    #[zbus(property)]
    fn id(&self) -> zbus::Result<String>;

    #[zbus(property)]
    fn uuid(&self) -> zbus::Result<String>;

    #[zbus(property, name = "Type")]
    fn connection_type(&self) -> zbus::Result<String>;

    #[zbus(property)]
    fn devices(&self) -> zbus::Result<Vec<zbus::zvariant::OwnedObjectPath>>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.Device.Wireless",
    default_service = "org.freedesktop.NetworkManager"
)]
trait WirelessDevice {
    #[zbus(property)]
    fn active_access_point(&self) -> zbus::Result<zbus::zvariant::OwnedObjectPath>;

    fn get_access_points(&self) -> zbus::Result<Vec<zbus::zvariant::OwnedObjectPath>>;

    fn request_scan(&self, options: HashMap<String, zbus::zvariant::Value<'_>>) -> zbus::Result<()>;
}

#[proxy(
    interface = "org.freedesktop.NetworkManager.AccessPoint",
    default_service = "org.freedesktop.NetworkManager"
)]
trait AccessPoint {
    #[zbus(property)]
    fn ssid(&self) -> zbus::Result<Vec<u8>>;

    #[zbus(property)]
    fn strength(&self) -> zbus::Result<u8>;

    #[zbus(property)]
    fn flags(&self) -> zbus::Result<u32>;

    #[zbus(property)]
    fn wpa_flags(&self) -> zbus::Result<u32>;

    #[zbus(property)]
    fn rsn_flags(&self) -> zbus::Result<u32>;
}

fn nm_state_to_string(state: u32) -> String {
    match state {
        0 => "unknown",
        10 => "asleep",
        20 => "disconnected",
        30 => "disconnecting",
        40 => "connecting",
        50 => "connected_local",
        60 => "connected_site",
        70 => "connected",
        _ => "unknown",
    }
    .to_string()
}

fn get_security_string(flags: u32, wpa_flags: u32, rsn_flags: u32) -> String {
    if rsn_flags != 0 {
        "WPA2/WPA3".to_string()
    } else if wpa_flags != 0 {
        "WPA".to_string()
    } else if flags & 0x1 != 0 {
        // NM_802_11_AP_FLAGS_PRIVACY
        "WEP".to_string()
    } else {
        "Open".to_string()
    }
}

/// DBus interface for network state
pub struct NetworkInterface {
    state: SharedNetworkState,
}

impl NetworkInterface {
    pub fn new(state: SharedNetworkState) -> Self {
        Self { state }
    }
}

#[interface(name = "org.caelestia.Network")]
impl NetworkInterface {
    /// Network connection state
    #[zbus(property)]
    async fn state(&self) -> String {
        self.state.read().await.state.clone()
    }

    /// Primary connection info as JSON
    #[zbus(property)]
    async fn primary_connection(&self) -> String {
        let state = self.state.read().await;
        if let Some(conn) = state.active_connections.first() {
            serde_json::to_string(conn).unwrap_or_else(|_| "{}".to_string())
        } else {
            "{}".to_string()
        }
    }

    /// WiFi info as JSON (current connection)
    #[zbus(property)]
    async fn wifi(&self) -> String {
        let state = self.state.read().await;
        if let Some(wifi) = &state.wifi {
            serde_json::to_string(wifi).unwrap_or_else(|_| "{}".to_string())
        } else {
            "{}".to_string()
        }
    }

    /// WiFi enabled status
    #[zbus(property)]
    async fn wifi_enabled(&self) -> bool {
        self.state.read().await.wifi_enabled
    }

    /// Available WiFi networks as JSON
    #[zbus(property)]
    async fn wifi_networks(&self) -> String {
        let state = self.state.read().await;
        serde_json::to_string(&state.wifi_networks).unwrap_or_else(|_| "[]".to_string())
    }

    /// All active connections as JSON
    #[zbus(property)]
    async fn active_connections(&self) -> String {
        let state = self.state.read().await;
        serde_json::to_string(&state.active_connections).unwrap_or_else(|_| "[]".to_string())
    }

    /// Signal: network state changed
    #[zbus(signal)]
    async fn network_state_changed(ctx: &SignalEmitter<'_>, state: &str) -> zbus::Result<()>;

    /// Signal: WiFi networks list changed
    #[zbus(signal)]
    async fn wifi_networks_updated(ctx: &SignalEmitter<'_>) -> zbus::Result<()>;
}

/// Register the Network interface
pub async fn run_network_dbus(conn: &Connection, state: SharedNetworkState) -> anyhow::Result<()> {
    let iface = NetworkInterface::new(state);
    conn.object_server()
        .at("/org/caelestia/Network", iface)
        .await?;

    info!("Network interface registered at /org/caelestia/Network");
    Ok(())
}

/// Fetch current network state from NetworkManager
async fn fetch_network_state(system_conn: &Connection) -> Option<NetworkState> {
    let nm = NetworkManagerProxy::new(system_conn).await.ok()?;

    let state_num = nm.state().await.ok()?;
    let wifi_enabled = nm.wireless_enabled().await.unwrap_or(false);

    let mut net_state = NetworkState {
        state: nm_state_to_string(state_num),
        wifi_enabled,
        wifi: None,
        active_connections: Vec::new(),
        wifi_networks: Vec::new(),
    };

    // Get active connections
    if let Ok(active_conns) = nm.active_connections().await {
        for conn_path in active_conns {
            if let Ok(conn_proxy) = ActiveConnectionProxy::builder(system_conn)
                .path(conn_path.clone())
                .ok()?
                .build()
                .await
            {
                let id = conn_proxy.id().await.unwrap_or_default();
                let uuid = conn_proxy.uuid().await.unwrap_or_default();
                let conn_type = conn_proxy.connection_type().await.unwrap_or_default();
                let devices = conn_proxy.devices().await.unwrap_or_default();
                let device_str = devices.first().map(|d| d.to_string()).unwrap_or_default();

                net_state.active_connections.push(ConnectionInfo {
                    id,
                    uuid,
                    connection_type: conn_type,
                    device: device_str,
                });
            }
        }
    }

    // Get WiFi info from devices
    if let Ok(devices) = nm.get_devices().await {
        for device_path in devices {
            // Try to get wireless device proxy
            if let Ok(wireless_proxy) = WirelessDeviceProxy::builder(system_conn)
                .path(device_path.clone())
                .ok()?
                .build()
                .await
            {
                // Get active access point
                if let Ok(ap_path) = wireless_proxy.active_access_point().await {
                    if ap_path.as_str() != "/" {
                        if let Ok(ap_proxy) = AccessPointProxy::builder(system_conn)
                            .path(ap_path)
                            .ok()?
                            .build()
                            .await
                        {
                            let ssid_bytes = ap_proxy.ssid().await.unwrap_or_default();
                            let ssid = String::from_utf8_lossy(&ssid_bytes).to_string();
                            let strength = ap_proxy.strength().await.unwrap_or(0);
                            let flags = ap_proxy.flags().await.unwrap_or(0);
                            let wpa_flags = ap_proxy.wpa_flags().await.unwrap_or(0);
                            let rsn_flags = ap_proxy.rsn_flags().await.unwrap_or(0);

                            net_state.wifi = Some(WifiInfo {
                                ssid,
                                signal_strength: strength,
                                security: get_security_string(flags, wpa_flags, rsn_flags),
                                connected: true,
                            });
                        }
                    }
                }

                // Get available networks
                if let Ok(aps) = wireless_proxy.get_access_points().await {
                    for ap_path in aps {
                        if let Ok(ap_proxy) = AccessPointProxy::builder(system_conn)
                            .path(ap_path)
                            .ok()?
                            .build()
                            .await
                        {
                            let ssid_bytes = ap_proxy.ssid().await.unwrap_or_default();
                            let ssid = String::from_utf8_lossy(&ssid_bytes).to_string();
                            if ssid.is_empty() {
                                continue;
                            }

                            let strength = ap_proxy.strength().await.unwrap_or(0);
                            let flags = ap_proxy.flags().await.unwrap_or(0);
                            let wpa_flags = ap_proxy.wpa_flags().await.unwrap_or(0);
                            let rsn_flags = ap_proxy.rsn_flags().await.unwrap_or(0);

                            let connected = net_state.wifi.as_ref().map(|w| w.ssid == ssid).unwrap_or(false);

                            // Avoid duplicates
                            if !net_state.wifi_networks.iter().any(|n| n.ssid == ssid) {
                                net_state.wifi_networks.push(WifiNetwork {
                                    ssid,
                                    signal_strength: strength,
                                    security: get_security_string(flags, wpa_flags, rsn_flags),
                                    connected,
                                    saved: false, // TODO: check against saved connections
                                });
                            }
                        }
                    }
                }
            }
        }
    }

    // Sort networks by signal strength
    net_state.wifi_networks.sort_by(|a, b| b.signal_strength.cmp(&a.signal_strength));

    Some(net_state)
}

/// Run the network service
pub async fn run_network_service(state: SharedNetworkState, session_conn: Connection) {
    // Connect to system bus for NetworkManager
    let system_conn = match Connection::system().await {
        Ok(c) => c,
        Err(e) => {
            warn!("Failed to connect to system bus for NetworkManager: {}", e);
            std::future::pending::<()>().await;
            return;
        }
    };

    // Initial fetch
    if let Some(net_state) = fetch_network_state(&system_conn).await {
        let wifi_count = net_state.wifi_networks.len();
        *state.write().await = net_state;
        info!("Network service running (found {} WiFi networks)", wifi_count);
    } else {
        warn!("NetworkManager not available");
        std::future::pending::<()>().await;
        return;
    }

    // Watch for state changes
    let nm = match NetworkManagerProxy::new(&system_conn).await {
        Ok(p) => p,
        Err(e) => {
            error!("Failed to create NetworkManager proxy: {}", e);
            std::future::pending::<()>().await;
            return;
        }
    };

    let mut state_stream = nm.receive_state_changed().await;

    while let Some(change) = state_stream.next().await {
        if let Ok(new_state) = change.get().await {
            debug!("NetworkManager state changed: {}", nm_state_to_string(new_state));

            // Refetch full state
            if let Some(net_state) = fetch_network_state(&system_conn).await {
                *state.write().await = net_state;

                // Emit signal
                if let Ok(iface_ref) = session_conn
                    .object_server()
                    .interface::<_, NetworkInterface>("/org/caelestia/Network")
                    .await
                {
                    let ctx = iface_ref.signal_emitter();
                    let state_str = nm_state_to_string(new_state);
                    let _ = NetworkInterface::network_state_changed(&ctx, &state_str).await;
                }
            }
        }
    }
}
