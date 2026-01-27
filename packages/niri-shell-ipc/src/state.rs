use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::{broadcast, RwLock};

/// Workspace information from niri
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Workspace {
    pub id: u64,
    pub idx: u32,
    pub name: Option<String>,
    pub output: Option<String>,
    pub is_active: bool,
    pub is_focused: bool,
    pub active_window_id: Option<u64>,
}

/// Window/toplevel information from niri
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Window {
    pub id: u64,
    pub title: Option<String>,
    pub app_id: Option<String>,
    pub workspace_id: Option<u64>,
    pub is_focused: bool,
    pub is_floating: Option<bool>,
}

/// Output/monitor information from niri
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Output {
    pub name: String,
    pub make: Option<String>,
    pub model: Option<String>,
    pub logical: Option<LogicalOutput>,
    pub is_focused: bool,
    pub active_workspace_id: Option<u64>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LogicalOutput {
    pub x: i32,
    pub y: i32,
    pub width: u32,
    pub height: u32,
    pub scale: f64,
}

/// Keyboard layout information
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct KeyboardLayouts {
    pub names: Vec<String>,
    pub current_idx: u32,
}

/// Event types for signaling changes
#[derive(Debug, Clone)]
pub enum StateEvent {
    WorkspacesChanged,
    WindowsChanged,
    OutputsChanged,
    FocusChanged,
    KeyboardLayoutChanged,
}

/// The shared state between niri client and DBus server
#[derive(Debug)]
pub struct State {
    pub workspaces: RwLock<HashMap<u64, Workspace>>,
    pub windows: RwLock<HashMap<u64, Window>>,
    pub outputs: RwLock<HashMap<String, Output>>,
    pub keyboard_layouts: RwLock<KeyboardLayouts>,
    pub focused_workspace_id: RwLock<Option<u64>>,
    pub focused_window_id: RwLock<Option<u64>>,
    pub focused_output: RwLock<Option<String>>,
    pub event_tx: broadcast::Sender<StateEvent>,
}

pub type SharedState = Arc<State>;

impl State {
    pub fn new() -> SharedState {
        let (event_tx, _) = broadcast::channel(100);
        Arc::new(State {
            workspaces: RwLock::new(HashMap::new()),
            windows: RwLock::new(HashMap::new()),
            outputs: RwLock::new(HashMap::new()),
            keyboard_layouts: RwLock::new(KeyboardLayouts::default()),
            focused_workspace_id: RwLock::new(None),
            focused_window_id: RwLock::new(None),
            focused_output: RwLock::new(None),
            event_tx,
        })
    }

    pub fn subscribe(&self) -> broadcast::Receiver<StateEvent> {
        self.event_tx.subscribe()
    }

    pub fn notify(&self, event: StateEvent) {
        // Ignore send errors (no receivers)
        let _ = self.event_tx.send(event);
    }
}

impl Default for State {
    fn default() -> Self {
        let (event_tx, _) = broadcast::channel(100);
        State {
            workspaces: RwLock::new(HashMap::new()),
            windows: RwLock::new(HashMap::new()),
            outputs: RwLock::new(HashMap::new()),
            keyboard_layouts: RwLock::new(KeyboardLayouts::default()),
            focused_workspace_id: RwLock::new(None),
            focused_window_id: RwLock::new(None),
            focused_output: RwLock::new(None),
            event_tx,
        }
    }
}
