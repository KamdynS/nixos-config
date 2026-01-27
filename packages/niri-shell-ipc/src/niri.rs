use crate::state::{
    KeyboardLayouts, LogicalOutput, Output, SharedState, StateEvent, Window, Workspace,
};
use anyhow::{Context, Result};
use serde::Deserialize;
use serde_json::Value;
use std::collections::HashMap;
use tokio::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use tokio::net::UnixStream;
use tracing::{debug, error, info, warn};

/// Run the niri IPC client, connecting to the socket and processing events
pub async fn run_client(socket_path: &str, state: SharedState) -> Result<()> {
    // Initial state fetch
    fetch_initial_state(socket_path, &state).await?;

    // Connect to event stream
    let stream = UnixStream::connect(socket_path)
        .await
        .context("Failed to connect to niri socket")?;

    let (read_half, mut write_half) = stream.into_split();

    // Request event stream
    write_half
        .write_all(b"\"EventStream\"\n")
        .await
        .context("Failed to send EventStream request")?;

    let reader = BufReader::new(read_half);
    let mut lines = reader.lines();

    info!("Connected to niri event stream");

    while let Some(line) = lines.next_line().await? {
        if let Err(e) = process_event(&line, &state).await {
            warn!("Error processing event: {}", e);
        }
    }

    Ok(())
}

/// Fetch initial state from niri
async fn fetch_initial_state(socket_path: &str, state: &SharedState) -> Result<()> {
    // Fetch workspaces
    let workspaces_json = send_request(socket_path, "\"Workspaces\"").await?;
    process_workspaces_response(&workspaces_json, state).await?;

    // Fetch windows
    let windows_json = send_request(socket_path, "\"Windows\"").await?;
    process_windows_response(&windows_json, state).await?;

    // Fetch outputs
    let outputs_json = send_request(socket_path, "\"Outputs\"").await?;
    process_outputs_response(&outputs_json, state).await?;

    // Fetch focused window
    let focused_json = send_request(socket_path, "\"FocusedWindow\"").await?;
    process_focused_window_response(&focused_json, state).await?;

    // Fetch keyboard layouts
    let kb_json = send_request(socket_path, "\"KeyboardLayouts\"").await?;
    process_keyboard_layouts_response(&kb_json, state).await?;

    info!("Initial state fetched");
    Ok(())
}

/// Send a single request to niri and get response
async fn send_request(socket_path: &str, request: &str) -> Result<String> {
    let mut stream = UnixStream::connect(socket_path)
        .await
        .context("Failed to connect to niri socket")?;

    stream
        .write_all(format!("{}\n", request).as_bytes())
        .await?;
    stream.shutdown().await?;

    let mut reader = BufReader::new(stream);
    let mut response = String::new();
    reader.read_line(&mut response).await?;

    Ok(response)
}

/// Send an action to niri
pub async fn send_action(socket_path: &str, action: &str) -> Result<String> {
    let request = format!("{{\"Action\":{}}}", action);
    send_request(socket_path, &request).await
}

/// Process workspaces response
async fn process_workspaces_response(json: &str, state: &SharedState) -> Result<()> {
    let response: Value = serde_json::from_str(json)?;

    if let Some(workspaces) = response.get("Ok").and_then(|ok| ok.get("Workspaces")) {
        let mut ws_map = state.workspaces.write().await;
        ws_map.clear();

        if let Some(arr) = workspaces.as_array() {
            for ws in arr {
                if let Some(workspace) = parse_workspace(ws) {
                    if workspace.is_focused {
                        *state.focused_workspace_id.write().await = Some(workspace.id);
                    }
                    ws_map.insert(workspace.id, workspace);
                }
            }
        }
    }

    state.notify(StateEvent::WorkspacesChanged);
    Ok(())
}

/// Process windows response
async fn process_windows_response(json: &str, state: &SharedState) -> Result<()> {
    let response: Value = serde_json::from_str(json)?;

    if let Some(windows) = response.get("Ok").and_then(|ok| ok.get("Windows")) {
        let mut win_map = state.windows.write().await;
        win_map.clear();

        if let Some(arr) = windows.as_array() {
            for win in arr {
                if let Some(window) = parse_window(win) {
                    if window.is_focused {
                        *state.focused_window_id.write().await = Some(window.id);
                    }
                    win_map.insert(window.id, window);
                }
            }
        }
    }

    state.notify(StateEvent::WindowsChanged);
    Ok(())
}

/// Process outputs response
async fn process_outputs_response(json: &str, state: &SharedState) -> Result<()> {
    let response: Value = serde_json::from_str(json)?;

    if let Some(outputs) = response.get("Ok").and_then(|ok| ok.get("Outputs")) {
        let mut out_map = state.outputs.write().await;
        out_map.clear();

        if let Some(arr) = outputs.as_array() {
            for out in arr {
                if let Some(output) = parse_output(out) {
                    if output.is_focused {
                        *state.focused_output.write().await = Some(output.name.clone());
                    }
                    out_map.insert(output.name.clone(), output);
                }
            }
        }
    }

    state.notify(StateEvent::OutputsChanged);
    Ok(())
}

/// Process focused window response
async fn process_focused_window_response(json: &str, state: &SharedState) -> Result<()> {
    let response: Value = serde_json::from_str(json)?;

    if let Some(focused) = response.get("Ok").and_then(|ok| ok.get("FocusedWindow")) {
        if focused.is_null() {
            *state.focused_window_id.write().await = None;
        } else if let Some(id) = focused.get("id").and_then(|v| v.as_u64()) {
            *state.focused_window_id.write().await = Some(id);
        }
    }

    state.notify(StateEvent::FocusChanged);
    Ok(())
}

/// Process keyboard layouts response
async fn process_keyboard_layouts_response(json: &str, state: &SharedState) -> Result<()> {
    let response: Value = serde_json::from_str(json)?;

    if let Some(kb) = response.get("Ok").and_then(|ok| ok.get("KeyboardLayouts")) {
        let names = kb
            .get("names")
            .and_then(|v| v.as_array())
            .map(|arr| {
                arr.iter()
                    .filter_map(|v| v.as_str().map(String::from))
                    .collect()
            })
            .unwrap_or_default();

        let current_idx = kb
            .get("current_idx")
            .and_then(|v| v.as_u64())
            .unwrap_or(0) as u32;

        *state.keyboard_layouts.write().await = KeyboardLayouts { names, current_idx };
    }

    state.notify(StateEvent::KeyboardLayoutChanged);
    Ok(())
}

/// Process an event from the event stream
async fn process_event(line: &str, state: &SharedState) -> Result<()> {
    let event: Value = serde_json::from_str(line)?;

    // Skip the initial "Ok":"Handled" response
    if event.get("Ok").is_some() {
        debug!("Received Ok response, skipping");
        return Ok(());
    }

    // Check for errors
    if let Some(err) = event.get("Err") {
        error!("Niri error event: {:?}", err);
        return Ok(());
    }

    // Process different event types (events come directly, not wrapped in Ok)
    if let Some(workspaces) = event.get("WorkspacesChanged") {
        debug!("WorkspacesChanged event");
        if let Some(arr) = workspaces.get("workspaces").and_then(|v| v.as_array()) {
            let mut ws_map = state.workspaces.write().await;
            ws_map.clear();
            for ws in arr {
                if let Some(workspace) = parse_workspace(ws) {
                    if workspace.is_focused {
                        *state.focused_workspace_id.write().await = Some(workspace.id);
                    }
                    ws_map.insert(workspace.id, workspace);
                }
            }
        }
        state.notify(StateEvent::WorkspacesChanged);
    } else if let Some(ws) = event.get("WorkspaceActivated") {
        debug!("WorkspaceActivated event");
        let ws_id = ws.get("id").and_then(|v| v.as_u64());
        let is_focused = ws.get("focused").and_then(|v| v.as_bool()).unwrap_or(false);

        if let Some(id) = ws_id {
            let mut ws_map = state.workspaces.write().await;
            // Update active status
            for workspace in ws_map.values_mut() {
                workspace.is_active = workspace.id == id;
                if is_focused {
                    workspace.is_focused = workspace.id == id;
                }
            }
            if is_focused {
                *state.focused_workspace_id.write().await = Some(id);
            }
        }
        state.notify(StateEvent::WorkspacesChanged);
        state.notify(StateEvent::FocusChanged);
    } else if let Some(win) = event.get("WindowOpenedOrChanged") {
        debug!("WindowOpenedOrChanged event");
        if let Some(window_data) = win.get("window") {
            if let Some(window) = parse_window(window_data) {
                let id = window.id;
                let is_focused = window.is_focused;
                state.windows.write().await.insert(id, window);
                if is_focused {
                    *state.focused_window_id.write().await = Some(id);
                }
            }
        }
        state.notify(StateEvent::WindowsChanged);
    } else if let Some(win) = event.get("WindowClosed") {
        debug!("WindowClosed event");
        if let Some(id) = win.get("id").and_then(|v| v.as_u64()) {
            state.windows.write().await.remove(&id);
            let current_focused = *state.focused_window_id.read().await;
            if current_focused == Some(id) {
                *state.focused_window_id.write().await = None;
            }
        }
        state.notify(StateEvent::WindowsChanged);
    } else if let Some(focus) = event.get("WindowFocusChanged") {
        debug!("WindowFocusChanged event");
        let id = focus.get("id").and_then(|v| v.as_u64());
        *state.focused_window_id.write().await = id;

        // Update focus status in windows
        let mut windows = state.windows.write().await;
        for window in windows.values_mut() {
            window.is_focused = Some(window.id) == id;
        }

        state.notify(StateEvent::FocusChanged);
        state.notify(StateEvent::WindowsChanged);
    } else if let Some(kb) = event.get("KeyboardLayoutsChanged") {
        debug!("KeyboardLayoutsChanged event");
        if let Some(layouts) = kb.get("keyboard_layouts") {
            let names = layouts
                .get("names")
                .and_then(|v| v.as_array())
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| v.as_str().map(String::from))
                        .collect()
                })
                .unwrap_or_default();

            let current_idx = layouts
                .get("current_idx")
                .and_then(|v| v.as_u64())
                .unwrap_or(0) as u32;

            *state.keyboard_layouts.write().await = KeyboardLayouts { names, current_idx };
        }
        state.notify(StateEvent::KeyboardLayoutChanged);
    } else if let Some(kb) = event.get("KeyboardLayoutSwitched") {
        debug!("KeyboardLayoutSwitched event");
        if let Some(idx) = kb.get("idx").and_then(|v| v.as_u64()) {
            state.keyboard_layouts.write().await.current_idx = idx as u32;
        }
        state.notify(StateEvent::KeyboardLayoutChanged);
    }

    Ok(())
}

/// Parse a workspace from JSON
fn parse_workspace(v: &Value) -> Option<Workspace> {
    Some(Workspace {
        id: v.get("id")?.as_u64()?,
        idx: v.get("idx").and_then(|v| v.as_u64()).unwrap_or(0) as u32,
        name: v.get("name").and_then(|v| v.as_str()).map(String::from),
        output: v.get("output").and_then(|v| v.as_str()).map(String::from),
        is_active: v.get("is_active").and_then(|v| v.as_bool()).unwrap_or(false),
        is_focused: v.get("is_focused").and_then(|v| v.as_bool()).unwrap_or(false),
        active_window_id: v.get("active_window_id").and_then(|v| v.as_u64()),
    })
}

/// Parse a window from JSON
fn parse_window(v: &Value) -> Option<Window> {
    Some(Window {
        id: v.get("id")?.as_u64()?,
        title: v.get("title").and_then(|v| v.as_str()).map(String::from),
        app_id: v.get("app_id").and_then(|v| v.as_str()).map(String::from),
        workspace_id: v.get("workspace_id").and_then(|v| v.as_u64()),
        is_focused: v.get("is_focused").and_then(|v| v.as_bool()).unwrap_or(false),
        is_floating: v.get("is_floating").and_then(|v| v.as_bool()),
    })
}

/// Parse an output from JSON
fn parse_output(v: &Value) -> Option<Output> {
    let logical = v.get("logical").map(|l| LogicalOutput {
        x: l.get("x").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
        y: l.get("y").and_then(|v| v.as_i64()).unwrap_or(0) as i32,
        width: l.get("width").and_then(|v| v.as_u64()).unwrap_or(0) as u32,
        height: l.get("height").and_then(|v| v.as_u64()).unwrap_or(0) as u32,
        scale: l.get("scale").and_then(|v| v.as_f64()).unwrap_or(1.0),
    });

    Some(Output {
        name: v.get("name")?.as_str()?.to_string(),
        make: v.get("make").and_then(|v| v.as_str()).map(String::from),
        model: v.get("model").and_then(|v| v.as_str()).map(String::from),
        logical,
        is_focused: v.get("is_focused").and_then(|v| v.as_bool()).unwrap_or(false),
        active_workspace_id: v.get("current_workspace_id").and_then(|v| v.as_u64()),
    })
}
