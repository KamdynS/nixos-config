//! Screen brightness control interface
//!
//! Controls backlight brightness via /sys/class/backlight

use serde::Serialize;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{info, warn};
use zbus::{interface, object_server::SignalEmitter, Connection};

pub type SharedBrightnessState = Arc<RwLock<BrightnessState>>;

#[derive(Debug, Clone, Serialize)]
pub struct Display {
    pub name: String,
    pub path: PathBuf,
    pub brightness: f64,     // 0.0-1.0
    pub max_brightness: u32,
    pub current: u32,
}

#[derive(Debug, Clone, Default)]
pub struct BrightnessState {
    pub displays: Vec<Display>,
    pub primary_brightness: f64, // Main display brightness 0.0-1.0
}

impl BrightnessState {
    pub fn new() -> Self {
        let mut state = Self::default();
        state.scan_backlights();
        state
    }

    /// Scan /sys/class/backlight for available displays
    fn scan_backlights(&mut self) {
        self.displays.clear();
        let backlight_path = Path::new("/sys/class/backlight");

        if let Ok(entries) = fs::read_dir(backlight_path) {
            for entry in entries.filter_map(Result::ok) {
                let path = entry.path();
                let name = entry.file_name().to_string_lossy().to_string();

                if let (Some(max), Some(current)) = (
                    read_brightness_file(&path.join("max_brightness")),
                    read_brightness_file(&path.join("brightness")),
                ) {
                    let brightness = if max > 0 {
                        current as f64 / max as f64
                    } else {
                        0.0
                    };

                    self.displays.push(Display {
                        name,
                        path,
                        brightness,
                        max_brightness: max,
                        current,
                    });
                }
            }
        }

        // Set primary brightness from first display
        if let Some(display) = self.displays.first() {
            self.primary_brightness = display.brightness;
        }
    }

    /// Refresh brightness values from sysfs
    pub fn refresh(&mut self) {
        for display in &mut self.displays {
            if let Some(current) = read_brightness_file(&display.path.join("brightness")) {
                display.current = current;
                display.brightness = if display.max_brightness > 0 {
                    current as f64 / display.max_brightness as f64
                } else {
                    0.0
                };
            }
        }

        if let Some(display) = self.displays.first() {
            self.primary_brightness = display.brightness;
        }
    }
}

fn read_brightness_file(path: &Path) -> Option<u32> {
    fs::read_to_string(path)
        .ok()?
        .trim()
        .parse()
        .ok()
}

fn write_brightness_file(path: &Path, value: u32) -> bool {
    fs::write(path, value.to_string()).is_ok()
}

/// DBus interface for brightness control
pub struct BrightnessInterface {
    state: SharedBrightnessState,
}

impl BrightnessInterface {
    pub fn new(state: SharedBrightnessState) -> Self {
        Self { state }
    }
}

#[interface(name = "org.caelestia.Brightness")]
impl BrightnessInterface {
    /// Primary display brightness (0.0-1.0)
    #[zbus(property)]
    async fn brightness(&self) -> f64 {
        let mut state = self.state.write().await;
        state.refresh();
        state.primary_brightness
    }

    /// All displays with brightness info as JSON
    #[zbus(property)]
    async fn displays(&self) -> String {
        let mut state = self.state.write().await;
        state.refresh();
        serde_json::to_string(&state.displays).unwrap_or_else(|_| "[]".to_string())
    }

    /// DDC/CI support available (not implemented yet)
    #[zbus(property)]
    async fn ddc_supported(&self) -> bool {
        false // TODO: implement DDC/CI
    }

    /// Set brightness for primary display
    async fn set_brightness(&self, value: f64) -> bool {
        let value = value.clamp(0.0, 1.0);
        let state = self.state.read().await;

        if let Some(display) = state.displays.first() {
            let raw_value = (value * display.max_brightness as f64).round() as u32;
            let path = display.path.join("brightness");
            return write_brightness_file(&path, raw_value);
        }
        false
    }

    /// Set brightness for a specific display by name
    async fn set_display_brightness(&self, name: String, value: f64) -> bool {
        let value = value.clamp(0.0, 1.0);
        let state = self.state.read().await;

        if let Some(display) = state.displays.iter().find(|d| d.name == name) {
            let raw_value = (value * display.max_brightness as f64).round() as u32;
            let path = display.path.join("brightness");
            return write_brightness_file(&path, raw_value);
        }
        false
    }

    /// Increase brightness by delta, return new brightness
    async fn increase_brightness(&self, delta: f64) -> f64 {
        let mut state = self.state.write().await;
        state.refresh();

        if let Some(display) = state.displays.first() {
            let new_value = (display.brightness + delta).clamp(0.0, 1.0);
            let raw_value = (new_value * display.max_brightness as f64).round() as u32;
            let path = display.path.join("brightness");
            if write_brightness_file(&path, raw_value) {
                state.refresh();
                return state.primary_brightness;
            }
        }
        state.primary_brightness
    }

    /// Decrease brightness by delta, return new brightness
    async fn decrease_brightness(&self, delta: f64) -> f64 {
        let mut state = self.state.write().await;
        state.refresh();

        if let Some(display) = state.displays.first() {
            let new_value = (display.brightness - delta).clamp(0.0, 1.0);
            let raw_value = (new_value * display.max_brightness as f64).round() as u32;
            let path = display.path.join("brightness");
            if write_brightness_file(&path, raw_value) {
                state.refresh();
                return state.primary_brightness;
            }
        }
        state.primary_brightness
    }

    /// Signal: brightness level changed
    #[zbus(signal)]
    async fn brightness_level_changed(ctx: &SignalEmitter<'_>, value: f64) -> zbus::Result<()>;
}

/// Register the Brightness interface
pub async fn run_brightness_dbus(conn: &Connection, state: SharedBrightnessState) -> anyhow::Result<()> {
    let iface = BrightnessInterface::new(state.clone());
    conn.object_server()
        .at("/org/caelestia/Brightness", iface)
        .await?;

    let display_count = state.read().await.displays.len();
    if display_count > 0 {
        info!("Brightness interface registered at /org/caelestia/Brightness ({} displays)", display_count);
    } else {
        warn!("Brightness interface registered but no backlight displays found");
    }

    Ok(())
}
