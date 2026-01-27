//! System resource monitoring interface
//!
//! Provides CPU, RAM, disk, network, and temperature information via DBus.

use serde::Serialize;
use std::sync::Arc;
use sysinfo::{Components, CpuRefreshKind, Disks, MemoryRefreshKind, Networks, RefreshKind, System};
use tokio::sync::RwLock;
use tracing::info;
use zbus::{interface, object_server::SignalEmitter, Connection};

// Shared state for system stats
pub type SharedSystemState = Arc<RwLock<SystemState>>;

#[derive(Debug, Clone, Default, Serialize)]
pub struct CpuInfo {
    pub usage_percent: f32,
    pub per_core: Vec<f32>,
    pub frequency_mhz: u64,
    pub core_count: usize,
    pub thread_count: usize,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct MemoryInfo {
    pub total_bytes: u64,
    pub used_bytes: u64,
    pub available_bytes: u64,
    pub swap_total: u64,
    pub swap_used: u64,
    pub usage_percent: f32,
}

#[derive(Debug, Clone, Serialize)]
pub struct DiskInfo {
    pub name: String,
    pub mount_point: String,
    pub total_bytes: u64,
    pub available_bytes: u64,
    pub used_bytes: u64,
    pub usage_percent: f32,
    pub file_system: String,
}

#[derive(Debug, Clone, Default, Serialize)]
pub struct NetworkInfo {
    pub interfaces: Vec<NetworkInterface>,
    pub total_rx_bytes: u64,
    pub total_tx_bytes: u64,
}

#[derive(Debug, Clone, Serialize)]
pub struct NetworkInterface {
    pub name: String,
    pub rx_bytes: u64,
    pub tx_bytes: u64,
    pub rx_rate: u64, // bytes per second
    pub tx_rate: u64, // bytes per second
}

#[derive(Debug, Clone, Serialize)]
pub struct Temperature {
    pub label: String,
    pub temperature_celsius: f32,
    pub critical: Option<f32>,
}

#[derive(Debug, Clone, Default)]
pub struct SystemState {
    pub cpu: CpuInfo,
    pub memory: MemoryInfo,
    pub disks: Vec<DiskInfo>,
    pub network: NetworkInfo,
    pub temperatures: Vec<Temperature>,
    pub uptime: u64,
    pub hostname: String,
    pub username: String,

    // For calculating network rates
    prev_rx: u64,
    prev_tx: u64,
}

impl SystemState {
    pub fn new() -> Self {
        let hostname = System::host_name().unwrap_or_else(|| "unknown".to_string());
        let username = std::env::var("USER").unwrap_or_else(|_| "unknown".to_string());

        Self {
            hostname,
            username,
            ..Default::default()
        }
    }
}

/// DBus interface for system stats
pub struct SystemInterface {
    state: SharedSystemState,
}

impl SystemInterface {
    pub fn new(state: SharedSystemState) -> Self {
        Self { state }
    }
}

#[interface(name = "org.caelestia.System")]
impl SystemInterface {
    /// CPU information as JSON
    #[zbus(property)]
    async fn cpu(&self) -> String {
        let state = self.state.read().await;
        serde_json::to_string(&state.cpu).unwrap_or_else(|_| "{}".to_string())
    }

    /// Memory information as JSON
    #[zbus(property)]
    async fn memory(&self) -> String {
        let state = self.state.read().await;
        serde_json::to_string(&state.memory).unwrap_or_else(|_| "{}".to_string())
    }

    /// Disk information as JSON array
    #[zbus(property)]
    async fn disk(&self) -> String {
        let state = self.state.read().await;
        serde_json::to_string(&state.disks).unwrap_or_else(|_| "[]".to_string())
    }

    /// Network information as JSON
    #[zbus(property)]
    async fn network(&self) -> String {
        let state = self.state.read().await;
        serde_json::to_string(&state.network).unwrap_or_else(|_| "{}".to_string())
    }

    /// Temperature readings as JSON array
    #[zbus(property)]
    async fn temperatures(&self) -> String {
        let state = self.state.read().await;
        serde_json::to_string(&state.temperatures).unwrap_or_else(|_| "[]".to_string())
    }

    /// System uptime in seconds
    #[zbus(property)]
    async fn uptime(&self) -> u64 {
        let state = self.state.read().await;
        state.uptime
    }

    /// System hostname
    #[zbus(property)]
    async fn hostname(&self) -> String {
        let state = self.state.read().await;
        state.hostname.clone()
    }

    /// Current username
    #[zbus(property)]
    async fn username(&self) -> String {
        let state = self.state.read().await;
        state.username.clone()
    }

    /// Signal emitted when stats are refreshed
    #[zbus(signal)]
    async fn stats_updated(ctx: &SignalEmitter<'_>) -> zbus::Result<()>;
}

/// Register the System interface on the DBus connection
pub async fn run_system_dbus(conn: &Connection, state: SharedSystemState) -> anyhow::Result<()> {
    let iface = SystemInterface::new(state);
    conn.object_server()
        .at("/org/caelestia/System", iface)
        .await?;

    info!("System interface registered at /org/caelestia/System");
    Ok(())
}

/// Run the system stats collection loop
pub async fn run_system_service(state: SharedSystemState, conn: Connection) {
    // Create sysinfo instances
    let mut sys = System::new_with_specifics(
        RefreshKind::new()
            .with_cpu(CpuRefreshKind::everything())
            .with_memory(MemoryRefreshKind::everything()),
    );
    let mut networks = Networks::new_with_refreshed_list();
    let mut disks = Disks::new_with_refreshed_list();
    let components = Components::new_with_refreshed_list();

    // Initial CPU measurement (needs two samples for accurate usage)
    sys.refresh_cpu_all();
    tokio::time::sleep(tokio::time::Duration::from_millis(500)).await;

    loop {
        // Refresh system info
        sys.refresh_cpu_all();
        sys.refresh_memory();
        networks.refresh();

        // Update state
        {
            let mut s = state.write().await;

            // CPU info
            let cpus = sys.cpus();
            s.cpu = CpuInfo {
                usage_percent: sys.global_cpu_usage(),
                per_core: cpus.iter().map(|c| c.cpu_usage()).collect(),
                frequency_mhz: cpus.first().map(|c| c.frequency()).unwrap_or(0),
                core_count: sys.physical_core_count().unwrap_or(cpus.len()),
                thread_count: cpus.len(),
            };

            // Memory info
            let total = sys.total_memory();
            let used = sys.used_memory();
            let available = sys.available_memory();
            s.memory = MemoryInfo {
                total_bytes: total,
                used_bytes: used,
                available_bytes: available,
                swap_total: sys.total_swap(),
                swap_used: sys.used_swap(),
                usage_percent: if total > 0 {
                    (used as f32 / total as f32) * 100.0
                } else {
                    0.0
                },
            };

            // Network info
            let mut total_rx: u64 = 0;
            let mut total_tx: u64 = 0;
            let mut interfaces = Vec::new();

            for (name, data) in networks.iter() {
                let rx = data.total_received();
                let tx = data.total_transmitted();
                total_rx += rx;
                total_tx += tx;

                interfaces.push(NetworkInterface {
                    name: name.clone(),
                    rx_bytes: rx,
                    tx_bytes: tx,
                    rx_rate: 0, // Will be calculated below
                    tx_rate: 0,
                });
            }

            // Calculate rates (bytes per second, assuming 2s interval)
            if s.prev_rx > 0 {
                let rx_diff = total_rx.saturating_sub(s.prev_rx);
                let tx_diff = total_tx.saturating_sub(s.prev_tx);

                // Update interface rates proportionally
                for iface in &mut interfaces {
                    iface.rx_rate = rx_diff / 2; // 2 second interval
                    iface.tx_rate = tx_diff / 2;
                }
            }
            s.prev_rx = total_rx;
            s.prev_tx = total_tx;

            s.network = NetworkInfo {
                interfaces,
                total_rx_bytes: total_rx,
                total_tx_bytes: total_tx,
            };

            // Disk info (refresh less frequently)
            disks.refresh();
            s.disks = disks
                .iter()
                .map(|d| {
                    let total = d.total_space();
                    let available = d.available_space();
                    let used = total.saturating_sub(available);
                    DiskInfo {
                        name: d.name().to_string_lossy().to_string(),
                        mount_point: d.mount_point().to_string_lossy().to_string(),
                        total_bytes: total,
                        available_bytes: available,
                        used_bytes: used,
                        usage_percent: if total > 0 {
                            (used as f32 / total as f32) * 100.0
                        } else {
                            0.0
                        },
                        file_system: d.file_system().to_string_lossy().to_string(),
                    }
                })
                .collect();

            // Temperatures
            s.temperatures = components
                .iter()
                .map(|c| Temperature {
                    label: c.label().to_string(),
                    temperature_celsius: c.temperature(),
                    critical: c.critical(),
                })
                .collect();

            // Uptime
            s.uptime = System::uptime();
        }

        // Emit signal
        if let Ok(iface_ref) = conn
            .object_server()
            .interface::<_, SystemInterface>("/org/caelestia/System")
            .await
        {
            let ctx = iface_ref.signal_emitter();
            let _ = SystemInterface::stats_updated(&ctx).await;
        }

        // Sleep for 2 seconds before next update
        tokio::time::sleep(tokio::time::Duration::from_secs(2)).await;
    }
}
