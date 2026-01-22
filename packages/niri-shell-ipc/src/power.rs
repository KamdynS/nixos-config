use anyhow::Result;
use futures::StreamExt;
use serde::Serialize;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, info};
use zbus::{interface, proxy, object_server::SignalContext, Connection};

/// Battery state enum matching UPower's values
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum BatteryState {
    Unknown,
    Charging,
    Discharging,
    Empty,
    Full,
    PendingCharge,
    PendingDischarge,
}

impl From<u32> for BatteryState {
    fn from(v: u32) -> Self {
        match v {
            1 => BatteryState::Charging,
            2 => BatteryState::Discharging,
            3 => BatteryState::Empty,
            4 => BatteryState::Full,
            5 => BatteryState::PendingCharge,
            6 => BatteryState::PendingDischarge,
            _ => BatteryState::Unknown,
        }
    }
}

impl std::fmt::Display for BatteryState {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            BatteryState::Unknown => write!(f, "unknown"),
            BatteryState::Charging => write!(f, "charging"),
            BatteryState::Discharging => write!(f, "discharging"),
            BatteryState::Empty => write!(f, "empty"),
            BatteryState::Full => write!(f, "full"),
            BatteryState::PendingCharge => write!(f, "pending-charge"),
            BatteryState::PendingDischarge => write!(f, "pending-discharge"),
        }
    }
}

/// Power state
#[derive(Debug, Clone, Serialize)]
pub struct PowerState {
    pub has_battery: bool,
    pub on_battery: bool,
    pub percentage: f64,
    pub state: BatteryState,
    pub time_to_empty: i64,
    pub time_to_full: i64,
}

impl Default for PowerState {
    fn default() -> Self {
        Self {
            has_battery: false,
            on_battery: false,
            percentage: 0.0,
            state: BatteryState::Unknown,
            time_to_empty: 0,
            time_to_full: 0,
        }
    }
}

pub type SharedPowerState = Arc<RwLock<PowerState>>;

/// UPower main interface proxy
#[proxy(
    interface = "org.freedesktop.UPower",
    default_service = "org.freedesktop.UPower",
    default_path = "/org/freedesktop/UPower"
)]
trait UPower {
    #[zbus(property)]
    fn on_battery(&self) -> zbus::Result<bool>;
}

/// UPower Device interface proxy (for battery)
#[proxy(
    interface = "org.freedesktop.UPower.Device",
    default_service = "org.freedesktop.UPower"
)]
trait UPowerDevice {
    #[zbus(property)]
    fn percentage(&self) -> zbus::Result<f64>;

    #[zbus(property)]
    fn state(&self) -> zbus::Result<u32>;

    #[zbus(property)]
    fn time_to_empty(&self) -> zbus::Result<i64>;

    #[zbus(property)]
    fn time_to_full(&self) -> zbus::Result<i64>;

    #[zbus(property)]
    fn is_present(&self) -> zbus::Result<bool>;

    #[zbus(property, name = "Type")]
    fn device_type(&self) -> zbus::Result<u32>;
}

/// Our DBus interface for power info
pub struct PowerInterface {
    state: SharedPowerState,
}

impl PowerInterface {
    pub fn new(state: SharedPowerState) -> Self {
        Self { state }
    }
}

#[interface(name = "org.caelestia.Power")]
impl PowerInterface {
    #[zbus(property)]
    async fn has_battery(&self) -> bool {
        self.state.read().await.has_battery
    }

    #[zbus(property)]
    async fn on_battery(&self) -> bool {
        self.state.read().await.on_battery
    }

    #[zbus(property)]
    async fn battery_percent(&self) -> f64 {
        self.state.read().await.percentage
    }

    #[zbus(property)]
    async fn battery_state(&self) -> String {
        self.state.read().await.state.to_string()
    }

    #[zbus(property)]
    async fn time_to_empty(&self) -> i64 {
        self.state.read().await.time_to_empty
    }

    #[zbus(property)]
    async fn time_to_full(&self) -> i64 {
        self.state.read().await.time_to_full
    }

    /// Get all power info as JSON
    #[zbus(property)]
    async fn info(&self) -> String {
        let state = self.state.read().await;
        serde_json::to_string(&*state).unwrap_or_else(|_| "{}".to_string())
    }

    // Signal emitted when battery state changes
    #[zbus(signal)]
    async fn battery_changed(ctx: &SignalContext<'_>) -> zbus::Result<()>;
}

/// Run the power service
pub async fn run_power_service(power_state: SharedPowerState) -> Result<()> {
    // Connect to system bus for UPower
    let system_conn = Connection::system().await?;

    // Get UPower proxy
    let upower = UPowerProxy::new(&system_conn).await?;

    // Try to find display device (aggregated battery) or fall back to first battery
    let device_path = "/org/freedesktop/UPower/devices/DisplayDevice";
    let device = UPowerDeviceProxy::builder(&system_conn)
        .path(device_path)?
        .build()
        .await?;

    // Check if device is present and is a battery (type 2)
    let is_battery = match (device.is_present().await, device.device_type().await) {
        (Ok(present), Ok(dtype)) => present && dtype == 2,
        _ => false,
    };

    if !is_battery {
        info!("No battery found - running on AC power only");
        let mut state = power_state.write().await;
        state.has_battery = false;
        state.on_battery = false;
        drop(state);
        // Keep running but do nothing (desktop/AC-only system)
        std::future::pending::<()>().await;
        return Ok(());
    }

    info!("Battery found, monitoring UPower");

    // Initial state
    {
        let mut state = power_state.write().await;
        state.has_battery = true;
        state.on_battery = upower.on_battery().await.unwrap_or(false);
        state.percentage = device.percentage().await.unwrap_or(0.0);
        state.state = BatteryState::from(device.state().await.unwrap_or(0));
        state.time_to_empty = device.time_to_empty().await.unwrap_or(0);
        state.time_to_full = device.time_to_full().await.unwrap_or(0);
        debug!("Initial power state: {:?}", *state);
    }

    // Watch for property changes
    let mut on_battery_stream = upower.receive_on_battery_changed().await;
    let mut percentage_stream = device.receive_percentage_changed().await;
    let mut state_stream = device.receive_state_changed().await;
    let mut tte_stream = device.receive_time_to_empty_changed().await;
    let mut ttf_stream = device.receive_time_to_full_changed().await;

    loop {
        tokio::select! {
            Some(change) = on_battery_stream.next() => {
                if let Ok(val) = change.get().await {
                    debug!("on_battery changed: {}", val);
                    power_state.write().await.on_battery = val;
                }
            }
            Some(change) = percentage_stream.next() => {
                if let Ok(val) = change.get().await {
                    debug!("percentage changed: {}", val);
                    power_state.write().await.percentage = val;
                }
            }
            Some(change) = state_stream.next() => {
                if let Ok(val) = change.get().await {
                    debug!("battery state changed: {}", val);
                    power_state.write().await.state = BatteryState::from(val);
                }
            }
            Some(change) = tte_stream.next() => {
                if let Ok(val) = change.get().await {
                    power_state.write().await.time_to_empty = val;
                }
            }
            Some(change) = ttf_stream.next() => {
                if let Ok(val) = change.get().await {
                    power_state.write().await.time_to_full = val;
                }
            }
        }
    }
}

/// Start the power DBus interface on the session bus
pub async fn run_power_dbus(
    conn: &Connection,
    power_state: SharedPowerState,
) -> Result<()> {
    let interface = PowerInterface::new(power_state);

    conn.object_server()
        .at("/org/caelestia/Power", interface)
        .await?;

    info!("Power interface registered at /org/caelestia/Power");
    Ok(())
}
