//! Bluetooth interface via BlueZ
//!
//! Provides Bluetooth device state and control via BlueZ DBus API.

use futures::StreamExt;
use serde::Serialize;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info, warn};
use zbus::{interface, object_server::SignalEmitter, proxy, Connection};

pub type SharedBluetoothState = Arc<RwLock<BluetoothState>>;

#[derive(Debug, Clone, Default, Serialize)]
pub struct BluetoothDevice {
    pub address: String,
    pub name: String,
    pub icon: String,
    pub paired: bool,
    pub connected: bool,
    pub trusted: bool,
    pub battery: Option<u8>,
}

#[derive(Debug, Clone, Default)]
pub struct BluetoothState {
    pub powered: bool,
    pub discoverable: bool,
    pub discovering: bool,
    pub adapter_path: String,
    pub devices: Vec<BluetoothDevice>,
}

// BlueZ proxies
#[proxy(
    interface = "org.bluez.Adapter1",
    default_service = "org.bluez"
)]
trait Adapter1 {
    #[zbus(property)]
    fn powered(&self) -> zbus::Result<bool>;

    #[zbus(property)]
    fn discoverable(&self) -> zbus::Result<bool>;

    #[zbus(property)]
    fn discovering(&self) -> zbus::Result<bool>;

    #[zbus(property)]
    fn address(&self) -> zbus::Result<String>;

    fn start_discovery(&self) -> zbus::Result<()>;
    fn stop_discovery(&self) -> zbus::Result<()>;
}

#[proxy(
    interface = "org.bluez.Device1",
    default_service = "org.bluez"
)]
trait Device1 {
    #[zbus(property)]
    fn address(&self) -> zbus::Result<String>;

    #[zbus(property)]
    fn name(&self) -> zbus::Result<String>;

    #[zbus(property)]
    fn icon(&self) -> zbus::Result<String>;

    #[zbus(property)]
    fn paired(&self) -> zbus::Result<bool>;

    #[zbus(property)]
    fn connected(&self) -> zbus::Result<bool>;

    #[zbus(property)]
    fn trusted(&self) -> zbus::Result<bool>;

    fn connect(&self) -> zbus::Result<()>;
    fn disconnect(&self) -> zbus::Result<()>;
    fn pair(&self) -> zbus::Result<()>;
}

#[proxy(
    interface = "org.bluez.Battery1",
    default_service = "org.bluez"
)]
trait Battery1 {
    #[zbus(property)]
    fn percentage(&self) -> zbus::Result<u8>;
}

#[proxy(
    interface = "org.freedesktop.DBus.ObjectManager",
    default_service = "org.bluez",
    default_path = "/"
)]
trait ObjectManager {
    fn get_managed_objects(
        &self,
    ) -> zbus::Result<
        HashMap<
            zbus::zvariant::OwnedObjectPath,
            HashMap<String, HashMap<String, zbus::zvariant::OwnedValue>>,
        >,
    >;
}

/// DBus interface for bluetooth
pub struct BluetoothInterface {
    state: SharedBluetoothState,
    system_conn: Connection,
}

impl BluetoothInterface {
    pub fn new(state: SharedBluetoothState, system_conn: Connection) -> Self {
        Self { state, system_conn }
    }

    async fn get_adapter(&self) -> Option<Adapter1Proxy<'_>> {
        let adapter_path = self.state.read().await.adapter_path.clone();
        if adapter_path.is_empty() {
            return None;
        }
        Adapter1Proxy::builder(&self.system_conn)
            .path(adapter_path)
            .ok()?
            .build()
            .await
            .ok()
    }
}

#[interface(name = "org.caelestia.Bluetooth")]
impl BluetoothInterface {
    /// Bluetooth powered on/off
    #[zbus(property)]
    async fn powered(&self) -> bool {
        self.state.read().await.powered
    }

    /// Discoverable mode
    #[zbus(property)]
    async fn discoverable(&self) -> bool {
        self.state.read().await.discoverable
    }

    /// Currently scanning for devices
    #[zbus(property)]
    async fn discovering(&self) -> bool {
        self.state.read().await.discovering
    }

    /// All known devices as JSON
    #[zbus(property)]
    async fn devices(&self) -> String {
        let state = self.state.read().await;
        serde_json::to_string(&state.devices).unwrap_or_else(|_| "[]".to_string())
    }

    /// Currently connected devices as JSON
    #[zbus(property)]
    async fn connected_devices(&self) -> String {
        let state = self.state.read().await;
        let connected: Vec<&BluetoothDevice> = state.devices.iter().filter(|d| d.connected).collect();
        serde_json::to_string(&connected).unwrap_or_else(|_| "[]".to_string())
    }

    /// Start bluetooth discovery
    async fn start_discovery(&self) -> bool {
        if let Some(adapter) = self.get_adapter().await {
            return adapter.start_discovery().await.is_ok();
        }
        false
    }

    /// Stop bluetooth discovery
    async fn stop_discovery(&self) -> bool {
        if let Some(adapter) = self.get_adapter().await {
            return adapter.stop_discovery().await.is_ok();
        }
        false
    }

    /// Connect to device by address
    async fn connect(&self, address: String) -> bool {
        let state = self.state.read().await;
        // Find device path from address
        for device in &state.devices {
            if device.address == address {
                // Device paths are like /org/bluez/hci0/dev_AA_BB_CC_DD_EE_FF
                let dev_path = format!(
                    "{}/dev_{}",
                    state.adapter_path,
                    address.replace(':', "_")
                );
                if let Some(builder) = Device1Proxy::builder(&self.system_conn).path(dev_path).ok() {
                    if let Ok(proxy) = builder.build().await {
                        return proxy.connect().await.is_ok();
                    }
                }
            }
        }
        false
    }

    /// Disconnect device by address
    async fn disconnect(&self, address: String) -> bool {
        let state = self.state.read().await;
        let dev_path = format!(
            "{}/dev_{}",
            state.adapter_path,
            address.replace(':', "_")
        );
        if let Some(builder) = Device1Proxy::builder(&self.system_conn).path(dev_path).ok() {
            if let Ok(proxy) = builder.build().await {
                return proxy.disconnect().await.is_ok();
            }
        }
        false
    }

    /// Signal: device list changed
    #[zbus(signal)]
    async fn devices_updated(ctx: &SignalEmitter<'_>) -> zbus::Result<()>;

    /// Signal: device connected
    #[zbus(signal)]
    async fn device_connected(ctx: &SignalEmitter<'_>, address: &str) -> zbus::Result<()>;

    /// Signal: device disconnected
    #[zbus(signal)]
    async fn device_disconnected(ctx: &SignalEmitter<'_>, address: &str) -> zbus::Result<()>;
}

/// Register the Bluetooth interface
pub async fn run_bluetooth_dbus(
    conn: &Connection,
    state: SharedBluetoothState,
    system_conn: Connection,
) -> anyhow::Result<()> {
    let iface = BluetoothInterface::new(state, system_conn);
    conn.object_server()
        .at("/org/caelestia/Bluetooth", iface)
        .await?;

    info!("Bluetooth interface registered at /org/caelestia/Bluetooth");
    Ok(())
}

/// Fetch bluetooth state from BlueZ
async fn fetch_bluetooth_state(system_conn: &Connection) -> Option<BluetoothState> {
    let obj_manager = ObjectManagerProxy::new(system_conn).await.ok()?;
    let objects = obj_manager.get_managed_objects().await.ok()?;

    let mut bt_state = BluetoothState::default();

    // Find adapter and devices
    for (path, interfaces) in objects {
        let path_str = path.as_str();

        // Check for adapter
        if interfaces.contains_key("org.bluez.Adapter1") {
            bt_state.adapter_path = path_str.to_string();

            if let Ok(adapter) = Adapter1Proxy::builder(system_conn)
                .path(path_str)
                .ok()?
                .build()
                .await
            {
                bt_state.powered = adapter.powered().await.unwrap_or(false);
                bt_state.discoverable = adapter.discoverable().await.unwrap_or(false);
                bt_state.discovering = adapter.discovering().await.unwrap_or(false);
            }
        }

        // Check for device
        if interfaces.contains_key("org.bluez.Device1") {
            if let Ok(device) = Device1Proxy::builder(system_conn)
                .path(path_str)
                .ok()?
                .build()
                .await
            {
                let address = device.address().await.unwrap_or_default();
                let name = device.name().await.unwrap_or_else(|_| address.clone());
                let icon = device.icon().await.unwrap_or_else(|_| "bluetooth".to_string());
                let paired = device.paired().await.unwrap_or(false);
                let connected = device.connected().await.unwrap_or(false);
                let trusted = device.trusted().await.unwrap_or(false);

                // Try to get battery level
                let battery = if interfaces.contains_key("org.bluez.Battery1") {
                    Battery1Proxy::builder(system_conn)
                        .path(path_str)
                        .ok()
                        .map(|b| b.build())
                        .and_then(|f| futures::executor::block_on(f).ok())
                        .and_then(|p| futures::executor::block_on(p.percentage()).ok())
                } else {
                    None
                };

                bt_state.devices.push(BluetoothDevice {
                    address,
                    name,
                    icon,
                    paired,
                    connected,
                    trusted,
                    battery,
                });
            }
        }
    }

    // Sort: connected first, then paired, then by name
    bt_state.devices.sort_by(|a, b| {
        match (a.connected, b.connected) {
            (true, false) => std::cmp::Ordering::Less,
            (false, true) => std::cmp::Ordering::Greater,
            _ => match (a.paired, b.paired) {
                (true, false) => std::cmp::Ordering::Less,
                (false, true) => std::cmp::Ordering::Greater,
                _ => a.name.cmp(&b.name),
            },
        }
    });

    Some(bt_state)
}

/// Run the bluetooth service
pub async fn run_bluetooth_service(state: SharedBluetoothState, session_conn: Connection) {
    // Connect to system bus for BlueZ
    let system_conn = match Connection::system().await {
        Ok(c) => c,
        Err(e) => {
            warn!("Failed to connect to system bus for BlueZ: {}", e);
            std::future::pending::<()>().await;
            return;
        }
    };

    // Initial fetch
    if let Some(bt_state) = fetch_bluetooth_state(&system_conn).await {
        let device_count = bt_state.devices.len();
        let powered = bt_state.powered;
        *state.write().await = bt_state;
        info!(
            "Bluetooth service running (powered: {}, {} devices)",
            powered, device_count
        );
    } else {
        warn!("BlueZ not available");
        std::future::pending::<()>().await;
        return;
    }

    // Poll for changes every 5 seconds (BlueZ property changes are complex to watch)
    loop {
        tokio::time::sleep(tokio::time::Duration::from_secs(5)).await;

        if let Some(bt_state) = fetch_bluetooth_state(&system_conn).await {
            let old_state = state.read().await.clone();

            // Check for connection changes
            for device in &bt_state.devices {
                let old_device = old_state.devices.iter().find(|d| d.address == device.address);
                if let Some(old) = old_device {
                    if device.connected && !old.connected {
                        debug!("Device connected: {}", device.name);
                        if let Ok(iface_ref) = session_conn
                            .object_server()
                            .interface::<_, BluetoothInterface>("/org/caelestia/Bluetooth")
                            .await
                        {
                            let ctx = iface_ref.signal_emitter();
                            let _ = BluetoothInterface::device_connected(&ctx, &device.address).await;
                        }
                    } else if !device.connected && old.connected {
                        debug!("Device disconnected: {}", device.name);
                        if let Ok(iface_ref) = session_conn
                            .object_server()
                            .interface::<_, BluetoothInterface>("/org/caelestia/Bluetooth")
                            .await
                        {
                            let ctx = iface_ref.signal_emitter();
                            let _ = BluetoothInterface::device_disconnected(&ctx, &device.address).await;
                        }
                    }
                }
            }

            *state.write().await = bt_state;
        }
    }
}
