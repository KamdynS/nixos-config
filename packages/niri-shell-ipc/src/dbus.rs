use crate::state::{SharedState, StateEvent};
use anyhow::Result;
use std::collections::HashMap;
use tracing::{error, info};
use zbus::{connection, interface, object_server::SignalContext};

/// DBus interface for niri shell IPC
pub struct NiriInterface {
    state: SharedState,
    socket_path: String,
}

impl NiriInterface {
    pub fn new(state: SharedState) -> Self {
        let socket_path = std::env::var("NIRI_SOCKET").unwrap_or_default();
        Self { state, socket_path }
    }
}

#[interface(name = "org.caelestia.Niri")]
impl NiriInterface {
    /// Get all workspaces as JSON array
    #[zbus(property)]
    async fn workspaces(&self) -> String {
        let workspaces = self.state.workspaces.read().await;
        let mut ws_vec: Vec<_> = workspaces.values().collect();
        ws_vec.sort_by_key(|w| w.idx);
        serde_json::to_string(&ws_vec).unwrap_or_else(|_| "[]".to_string())
    }

    /// Get all windows as JSON array
    #[zbus(property)]
    async fn windows(&self) -> String {
        let windows = self.state.windows.read().await;
        let win_vec: Vec<_> = windows.values().collect();
        serde_json::to_string(&win_vec).unwrap_or_else(|_| "[]".to_string())
    }

    /// Get all outputs as JSON array
    #[zbus(property)]
    async fn outputs(&self) -> String {
        let outputs = self.state.outputs.read().await;
        let out_vec: Vec<_> = outputs.values().collect();
        serde_json::to_string(&out_vec).unwrap_or_else(|_| "[]".to_string())
    }

    /// Get focused workspace ID (0 if none)
    #[zbus(property)]
    async fn focused_workspace(&self) -> u64 {
        self.state
            .focused_workspace_id
            .read()
            .await
            .unwrap_or(0)
    }

    /// Get focused window ID (0 if none)
    #[zbus(property)]
    async fn focused_window(&self) -> u64 {
        self.state.focused_window_id.read().await.unwrap_or(0)
    }

    /// Get focused output name
    #[zbus(property)]
    async fn focused_output(&self) -> String {
        self.state
            .focused_output
            .read()
            .await
            .clone()
            .unwrap_or_default()
    }

    /// Get keyboard layouts as JSON
    #[zbus(property)]
    async fn keyboard_layouts(&self) -> String {
        let layouts = self.state.keyboard_layouts.read().await;
        serde_json::to_string(&*layouts).unwrap_or_else(|_| "{}".to_string())
    }

    /// Focus a workspace by index (1-based, on current output)
    async fn focus_workspace(&self, index: u32) -> String {
        let action = format!(
            "{{\"FocusWorkspace\":{{\"reference\":{{\"Index\":{}}}}}}}",
            index
        );
        self.send_action(&action).await
    }

    /// Focus a workspace by its global ID (works across outputs)
    async fn focus_workspace_by_id(&self, id: u64) -> String {
        let action = format!(
            "{{\"FocusWorkspace\":{{\"reference\":{{\"Id\":{}}}}}}}",
            id
        );
        self.send_action(&action).await
    }

    /// Focus workspace relative (+1 or -1)
    async fn focus_workspace_relative(&self, delta: i32) -> String {
        let direction = if delta > 0 { "Down" } else { "Up" };
        let action = format!(
            "{{\"FocusWorkspace\":{{\"reference\":{{\"{}\":{{}}}}}}}}",
            direction
        );
        self.send_action(&action).await
    }

    /// Move focused window to workspace by index
    async fn move_window_to_workspace(&self, index: u32) -> String {
        let action = format!(
            "{{\"MoveWindowToWorkspace\":{{\"reference\":{{\"Index\":{}}}}}}}",
            index
        );
        self.send_action(&action).await
    }

    /// Focus workspace by global index (1-based, across all outputs)
    /// Workspaces are sorted by output name, then by per-output index
    async fn focus_workspace_by_global_index(&self, global_index: u32) -> String {
        let workspaces = self.state.workspaces.read().await;
        let mut ws_vec: Vec<_> = workspaces.values().collect();

        // Sort by output name, then by idx (per-output index)
        ws_vec.sort_by(|a, b| {
            let output_cmp = a.output.cmp(&b.output);
            if output_cmp != std::cmp::Ordering::Equal {
                output_cmp
            } else {
                a.idx.cmp(&b.idx)
            }
        });

        // Find workspace at global_index (1-based)
        if global_index == 0 || global_index as usize > ws_vec.len() {
            return format!("Error: global index {} out of range (1-{})", global_index, ws_vec.len());
        }

        let ws_id = ws_vec[(global_index - 1) as usize].id;
        drop(workspaces);

        // Focus by ID (works across outputs)
        self.focus_workspace_by_id(ws_id).await
    }

    /// Move window to workspace by global index (1-based, across all outputs)
    async fn move_window_to_workspace_by_global_index(&self, global_index: u32) -> String {
        let workspaces = self.state.workspaces.read().await;
        let mut ws_vec: Vec<_> = workspaces.values().collect();

        // Sort by output name, then by idx
        ws_vec.sort_by(|a, b| {
            let output_cmp = a.output.cmp(&b.output);
            if output_cmp != std::cmp::Ordering::Equal {
                output_cmp
            } else {
                a.idx.cmp(&b.idx)
            }
        });

        if global_index == 0 || global_index as usize > ws_vec.len() {
            return format!("Error: global index {} out of range (1-{})", global_index, ws_vec.len());
        }

        let ws_id = ws_vec[(global_index - 1) as usize].id;
        drop(workspaces);

        // Move to workspace by ID
        let action = format!(
            "{{\"MoveWindowToWorkspace\":{{\"reference\":{{\"Id\":{}}}}}}}",
            ws_id
        );
        self.send_action(&action).await
    }

    /// Close focused window
    async fn close_window(&self) -> String {
        self.send_action("{\"CloseWindow\":{}}").await
    }

    /// Focus a window by ID
    async fn focus_window(&self, id: u64) -> String {
        let action = format!("{{\"FocusWindow\":{{\"id\":{}}}}}", id);
        self.send_action(&action).await
    }

    /// Send a raw action JSON string
    async fn action(&self, action_json: String) -> String {
        self.send_action(&action_json).await
    }

    /// Switch keyboard layout
    async fn switch_keyboard_layout(&self, layout: String) -> String {
        let action = if layout == "next" {
            "{\"SwitchLayout\":{\"layout\":\"Next\"}}".to_string()
        } else if layout == "prev" {
            "{\"SwitchLayout\":{\"layout\":\"Prev\"}}".to_string()
        } else {
            return "Error: layout must be 'next' or 'prev'".to_string();
        };
        self.send_action(&action).await
    }

    /// Quit niri
    async fn quit(&self) -> String {
        self.send_action("{\"Quit\":{\"skip_confirmation\":false}}").await
    }

    /// Power off monitors
    async fn power_off_monitors(&self) -> String {
        self.send_action("{\"PowerOffMonitors\":{}}").await
    }

    /// Cycle column width through presets without wrapping
    /// direction: "next" (wider) or "prev" (narrower)
    async fn cycle_column_width(&self, direction: String) -> String {
        const PRESETS: [f64; 4] = [0.33333, 0.5, 0.66667, 1.0];
        const STRUTS_AND_GAPS: u32 = 52 + 16; // left+right struts (26*2) + gaps (8*2)

        // Query niri for focused window (includes size)
        let focused_json = match crate::niri::send_request(&self.socket_path, "\"FocusedWindow\"").await {
            Ok(json) => json,
            Err(e) => return format!("Error querying focused window: {}", e),
        };

        let response: serde_json::Value = match serde_json::from_str(&focused_json) {
            Ok(v) => v,
            Err(e) => return format!("Error parsing response: {}", e),
        };

        // Get window info
        let window = match response.get("Ok").and_then(|ok| ok.get("FocusedWindow")) {
            Some(w) if !w.is_null() => w,
            _ => return "No focused window".to_string(),
        };

        let window_width = match window.get("size").and_then(|s| s.get("width")).and_then(|w| w.as_u64()) {
            Some(w) => w as u32,
            None => return "Could not get window width".to_string(),
        };

        let workspace_id = match window.get("workspace_id").and_then(|w| w.as_u64()) {
            Some(id) => id,
            None => return "Could not get workspace ID".to_string(),
        };

        // Get output name from workspace
        let output_name = {
            let workspaces = self.state.workspaces.read().await;
            match workspaces.get(&workspace_id).and_then(|ws| ws.output.clone()) {
                Some(name) => name,
                None => return "Could not find workspace output".to_string(),
            }
        };

        // Get output width
        let output_width = {
            let outputs = self.state.outputs.read().await;
            match outputs.get(&output_name).and_then(|o| o.logical.as_ref()) {
                Some(logical) => logical.width,
                None => return "Could not get output dimensions".to_string(),
            }
        };

        // Calculate usable width and current proportion
        let usable_width = output_width.saturating_sub(STRUTS_AND_GAPS);
        if usable_width == 0 {
            return "Invalid usable width".to_string();
        }

        let current_proportion = window_width as f64 / usable_width as f64;

        // Find closest preset index
        let closest_idx = PRESETS
            .iter()
            .enumerate()
            .min_by(|(_, a), (_, b)| {
                let diff_a = (*a - current_proportion).abs();
                let diff_b = (*b - current_proportion).abs();
                diff_a.partial_cmp(&diff_b).unwrap_or(std::cmp::Ordering::Equal)
            })
            .map(|(i, _)| i)
            .unwrap_or(0);

        // Calculate target index based on direction (clamping, no wrap)
        let target_idx = match direction.as_str() {
            "next" => {
                if closest_idx >= PRESETS.len() - 1 {
                    return "Already at maximum width".to_string();
                }
                closest_idx + 1
            }
            "prev" => {
                if closest_idx == 0 {
                    return "Already at minimum width".to_string();
                }
                closest_idx - 1
            }
            _ => return "Invalid direction: use 'next' or 'prev'".to_string(),
        };

        // Send SetColumnWidth action
        let action = format!(
            "{{\"SetColumnWidth\":{{\"change\":{{\"SetProportion\":{}}}}}}}",
            PRESETS[target_idx]
        );
        self.send_action(&action).await
    }

    // Signals for state changes (named _updated to avoid conflict with property _changed methods)
    #[zbus(signal)]
    async fn workspaces_updated(ctx: &SignalContext<'_>) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn windows_updated(ctx: &SignalContext<'_>) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn outputs_updated(ctx: &SignalContext<'_>) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn focus_updated(ctx: &SignalContext<'_>) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn keyboard_layout_updated(ctx: &SignalContext<'_>) -> zbus::Result<()>;
}

impl NiriInterface {
    async fn send_action(&self, action: &str) -> String {
        match crate::niri::send_action(&self.socket_path, action).await {
            Ok(response) => response,
            Err(e) => format!("Error: {}", e),
        }
    }
}

/// Create the DBus connection with the Niri interface
pub async fn create_connection(state: SharedState) -> Result<connection::Connection> {
    let interface = NiriInterface::new(state.clone());

    let conn = connection::Builder::session()?
        .name("org.caelestia.Niri")?
        .serve_at("/org/caelestia/Niri", interface)?
        .build()
        .await?;

    info!("DBus server running at org.caelestia.Niri");
    Ok(conn)
}

/// Run the DBus event loop (emitting signals on state changes)
pub async fn run_server(conn: connection::Connection, state: SharedState) -> Result<()> {

    // Get the object server to emit signals
    let object_server = conn.object_server();

    // Subscribe to state events and emit DBus signals
    let mut event_rx = state.subscribe();

    loop {
        match event_rx.recv().await {
            Ok(event) => {
                let iface_ref = object_server
                    .interface::<_, NiriInterface>("/org/caelestia/Niri")
                    .await?;
                let ctx = iface_ref.signal_context();

                match event {
                    StateEvent::WorkspacesChanged => {
                        if let Err(e) = NiriInterface::workspaces_updated(&ctx).await {
                            error!("Failed to emit WorkspacesUpdated signal: {}", e);
                        }
                    }
                    StateEvent::WindowsChanged => {
                        if let Err(e) = NiriInterface::windows_updated(&ctx).await {
                            error!("Failed to emit WindowsUpdated signal: {}", e);
                        }
                    }
                    StateEvent::OutputsChanged => {
                        if let Err(e) = NiriInterface::outputs_updated(&ctx).await {
                            error!("Failed to emit OutputsUpdated signal: {}", e);
                        }
                    }
                    StateEvent::FocusChanged => {
                        if let Err(e) = NiriInterface::focus_updated(&ctx).await {
                            error!("Failed to emit FocusUpdated signal: {}", e);
                        }
                    }
                    StateEvent::KeyboardLayoutChanged => {
                        if let Err(e) = NiriInterface::keyboard_layout_updated(&ctx).await {
                            error!("Failed to emit KeyboardLayoutUpdated signal: {}", e);
                        }
                    }
                }
            }
            Err(e) => {
                error!("Event channel error: {}", e);
            }
        }
    }
}
