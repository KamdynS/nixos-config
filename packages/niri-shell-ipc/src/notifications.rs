//! Freedesktop Notification daemon interface
//!
//! Implements org.freedesktop.Notifications to receive notifications from apps,
//! and org.caelestia.Notifications for shell management.

use serde::Serialize;
use std::collections::HashMap;
use std::sync::atomic::{AtomicU32, Ordering};
use std::sync::Arc;
use std::time::{SystemTime, UNIX_EPOCH};
use tokio::sync::RwLock;
use tracing::info;
use zbus::{interface, object_server::SignalEmitter, Connection};

pub type SharedNotificationState = Arc<RwLock<NotificationState>>;

static NOTIFICATION_ID: AtomicU32 = AtomicU32::new(1);

#[derive(Debug, Clone, Serialize)]
pub struct Notification {
    pub id: u32,
    pub app_name: String,
    pub app_icon: String,
    pub summary: String,
    pub body: String,
    pub actions: Vec<(String, String)>, // (action_key, label)
    pub urgency: String,
    pub timestamp: u64,
    pub image_path: Option<String>,
    pub expire_timeout: i32,
}

#[derive(Debug, Clone, Default)]
pub struct NotificationState {
    pub notifications: Vec<Notification>,
    pub do_not_disturb: bool,
}

/// Standard freedesktop Notifications interface
/// This receives notifications from applications
pub struct FreedesktopNotifications {
    state: SharedNotificationState,
}

impl FreedesktopNotifications {
    pub fn new(state: SharedNotificationState) -> Self {
        Self { state }
    }
}

#[interface(name = "org.freedesktop.Notifications")]
impl FreedesktopNotifications {
    /// Receive a notification from an application
    async fn notify(
        &self,
        app_name: String,
        replaces_id: u32,
        app_icon: String,
        summary: String,
        body: String,
        actions: Vec<String>,
        hints: HashMap<String, zbus::zvariant::OwnedValue>,
        expire_timeout: i32,
    ) -> u32 {
        let id = if replaces_id > 0 {
            replaces_id
        } else {
            NOTIFICATION_ID.fetch_add(1, Ordering::SeqCst)
        };

        // Parse urgency from hints
        let urgency = hints
            .get("urgency")
            .and_then(|v| u8::try_from(v).ok())
            .map(|u| match u {
                0 => "low",
                2 => "critical",
                _ => "normal",
            })
            .unwrap_or("normal")
            .to_string();

        // Parse image path from hints
        let image_path = hints
            .get("image-path")
            .and_then(|v| <&str>::try_from(v).ok().map(|s| s.to_string()));

        // Parse actions into (key, label) pairs
        let action_pairs: Vec<(String, String)> = actions
            .chunks(2)
            .filter_map(|chunk| {
                if chunk.len() == 2 {
                    Some((chunk[0].clone(), chunk[1].clone()))
                } else {
                    None
                }
            })
            .collect();

        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .map(|d| d.as_secs())
            .unwrap_or(0);

        let notification = Notification {
            id,
            app_name,
            app_icon,
            summary,
            body,
            actions: action_pairs,
            urgency,
            timestamp,
            image_path,
            expire_timeout,
        };

        let mut state = self.state.write().await;

        // Replace existing notification with same ID or add new one
        if let Some(pos) = state.notifications.iter().position(|n| n.id == id) {
            state.notifications[pos] = notification;
        } else {
            state.notifications.push(notification);
        }

        // Keep only last 50 notifications
        if state.notifications.len() > 50 {
            state.notifications.remove(0);
        }

        info!("Notification received: id={}, summary={}", id, state.notifications.last().map(|n| &n.summary).unwrap_or(&String::new()));

        id
    }

    /// Close a notification
    async fn close_notification(&self, id: u32) {
        let mut state = self.state.write().await;
        state.notifications.retain(|n| n.id != id);
    }

    /// Get server capabilities
    async fn get_capabilities(&self) -> Vec<String> {
        vec![
            "body".to_string(),
            "body-markup".to_string(),
            "actions".to_string(),
            "icon-static".to_string(),
            "persistence".to_string(),
        ]
    }

    /// Get server information
    async fn get_server_information(&self) -> (String, String, String, String) {
        (
            "niri-shell-ipc".to_string(),
            "caelestia".to_string(),
            "0.1.0".to_string(),
            "1.2".to_string(), // Notification spec version
        )
    }

    /// Signal: notification was closed
    #[zbus(signal)]
    async fn notification_closed(ctx: &SignalEmitter<'_>, id: u32, reason: u32) -> zbus::Result<()>;

    /// Signal: action was invoked
    #[zbus(signal)]
    async fn action_invoked(ctx: &SignalEmitter<'_>, id: u32, action_key: &str) -> zbus::Result<()>;
}

/// Caelestia notification management interface
pub struct CaelestiaNotifications {
    state: SharedNotificationState,
}

impl CaelestiaNotifications {
    pub fn new(state: SharedNotificationState) -> Self {
        Self { state }
    }
}

#[interface(name = "org.caelestia.Notifications")]
impl CaelestiaNotifications {
    /// All current notifications as JSON
    #[zbus(property)]
    async fn notifications(&self) -> String {
        let state = self.state.read().await;
        serde_json::to_string(&state.notifications).unwrap_or_else(|_| "[]".to_string())
    }

    /// Do not disturb mode
    #[zbus(property)]
    async fn do_not_disturb(&self) -> bool {
        self.state.read().await.do_not_disturb
    }

    /// Set do not disturb mode
    async fn set_do_not_disturb(&self, enabled: bool) -> bool {
        self.state.write().await.do_not_disturb = enabled;
        true
    }

    /// Clear all notifications
    async fn clear_all(&self) -> bool {
        self.state.write().await.notifications.clear();
        true
    }

    /// Clear notifications from specific app
    async fn clear_app(&self, app_name: String) -> bool {
        let mut state = self.state.write().await;
        state.notifications.retain(|n| n.app_name != app_name);
        true
    }

    /// Dismiss a specific notification
    async fn dismiss(&self, id: u32) -> bool {
        let mut state = self.state.write().await;
        let len_before = state.notifications.len();
        state.notifications.retain(|n| n.id != id);
        state.notifications.len() < len_before
    }

    /// Invoke an action on a notification
    async fn invoke_action(&self, id: u32, action_key: String) -> bool {
        let state = self.state.read().await;
        state.notifications.iter().any(|n| {
            n.id == id && n.actions.iter().any(|(k, _)| k == &action_key)
        })
    }

    /// Signal: new notification added
    #[zbus(signal)]
    async fn notification_added(ctx: &SignalEmitter<'_>, notification_json: &str) -> zbus::Result<()>;

    /// Signal: notification removed
    #[zbus(signal)]
    async fn notification_removed(ctx: &SignalEmitter<'_>, id: u32) -> zbus::Result<()>;
}

/// Register the Notifications interfaces
pub async fn run_notifications_dbus(conn: &Connection, state: SharedNotificationState) -> anyhow::Result<()> {
    // Register freedesktop interface at standard path
    let fd_iface = FreedesktopNotifications::new(state.clone());
    conn.object_server()
        .at("/org/freedesktop/Notifications", fd_iface)
        .await?;

    // Register caelestia interface
    let ca_iface = CaelestiaNotifications::new(state);
    conn.object_server()
        .at("/org/caelestia/Notifications", ca_iface)
        .await?;

    // Request the well-known name for notifications
    conn.request_name("org.freedesktop.Notifications")
        .await?;

    info!("Notifications daemon registered (org.freedesktop.Notifications)");
    Ok(())
}
