//! MPRIS media player aggregation interface
//!
//! Watches for MPRIS-compatible media players and provides unified control.

use futures::StreamExt;
use serde::Serialize;
use std::collections::HashMap;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, error, info};
use zbus::{interface, object_server::SignalEmitter, proxy, Connection};

pub type SharedMediaState = Arc<RwLock<MediaState>>;

#[derive(Debug, Clone, Default, Serialize)]
pub struct MediaMetadata {
    pub title: String,
    pub artist: String,
    pub album: String,
    pub art_url: String,
    pub length_us: i64,
}

#[derive(Debug, Clone, Serialize)]
pub struct MediaPlayer {
    pub name: String,
    pub identity: String,
    pub playback_status: String,
    pub can_control: bool,
    pub can_go_next: bool,
    pub can_go_previous: bool,
    pub can_play: bool,
    pub can_pause: bool,
}

#[derive(Debug, Clone, Default)]
pub struct MediaState {
    pub players: HashMap<String, MediaPlayer>,
    pub current_player: String,
    pub metadata: MediaMetadata,
    pub playback_status: String,
    pub position: i64,
}

impl MediaState {
    pub fn is_playing(&self) -> bool {
        self.playback_status == "Playing"
    }
}

// MPRIS proxies
#[proxy(
    interface = "org.mpris.MediaPlayer2",
    default_path = "/org/mpris/MediaPlayer2"
)]
trait MediaPlayer2 {
    #[zbus(property)]
    fn identity(&self) -> zbus::Result<String>;
}

#[proxy(
    interface = "org.mpris.MediaPlayer2.Player",
    default_path = "/org/mpris/MediaPlayer2"
)]
trait MediaPlayer2Player {
    fn play(&self) -> zbus::Result<()>;
    fn pause(&self) -> zbus::Result<()>;
    fn play_pause(&self) -> zbus::Result<()>;
    fn next(&self) -> zbus::Result<()>;
    fn previous(&self) -> zbus::Result<()>;

    #[zbus(property)]
    fn playback_status(&self) -> zbus::Result<String>;

    #[zbus(property)]
    fn metadata(&self) -> zbus::Result<HashMap<String, zbus::zvariant::OwnedValue>>;

    #[zbus(property)]
    fn position(&self) -> zbus::Result<i64>;

    #[zbus(property)]
    fn can_control(&self) -> zbus::Result<bool>;

    #[zbus(property)]
    fn can_go_next(&self) -> zbus::Result<bool>;

    #[zbus(property)]
    fn can_go_previous(&self) -> zbus::Result<bool>;

    #[zbus(property)]
    fn can_play(&self) -> zbus::Result<bool>;

    #[zbus(property)]
    fn can_pause(&self) -> zbus::Result<bool>;
}

/// DBus interface for media control
pub struct MediaInterface {
    state: SharedMediaState,
    conn: Connection,
}

impl MediaInterface {
    pub fn new(state: SharedMediaState, conn: Connection) -> Self {
        Self { state, conn }
    }

    async fn get_player_proxy(&self, bus_name: &str) -> Option<MediaPlayer2PlayerProxy<'_>> {
        MediaPlayer2PlayerProxy::builder(&self.conn)
            .destination(bus_name.to_string())
            .ok()?
            .build()
            .await
            .ok()
    }
}

#[interface(name = "org.caelestia.Media")]
impl MediaInterface {
    #[zbus(property)]
    async fn playing(&self) -> bool {
        self.state.read().await.is_playing()
    }

    #[zbus(property)]
    async fn current_player(&self) -> String {
        self.state.read().await.current_player.clone()
    }

    #[zbus(property)]
    async fn players(&self) -> String {
        let state = self.state.read().await;
        let players: Vec<&MediaPlayer> = state.players.values().collect();
        serde_json::to_string(&players).unwrap_or_else(|_| "[]".to_string())
    }

    #[zbus(property)]
    async fn metadata(&self) -> String {
        serde_json::to_string(&self.state.read().await.metadata).unwrap_or_else(|_| "{}".to_string())
    }

    #[zbus(property)]
    async fn playback_status(&self) -> String {
        self.state.read().await.playback_status.clone()
    }

    #[zbus(property)]
    async fn position(&self) -> i64 {
        self.state.read().await.position
    }

    #[zbus(property)]
    async fn art_url(&self) -> String {
        self.state.read().await.metadata.art_url.clone()
    }

    async fn play(&self) -> bool {
        let current = self.state.read().await.current_player.clone();
        if current.is_empty() {
            return false;
        }
        if let Some(proxy) = self.get_player_proxy(&current).await {
            proxy.play().await.is_ok()
        } else {
            false
        }
    }

    async fn pause(&self) -> bool {
        let current = self.state.read().await.current_player.clone();
        if current.is_empty() {
            return false;
        }
        if let Some(proxy) = self.get_player_proxy(&current).await {
            proxy.pause().await.is_ok()
        } else {
            false
        }
    }

    async fn play_pause(&self) -> bool {
        let current = self.state.read().await.current_player.clone();
        if current.is_empty() {
            return false;
        }
        if let Some(proxy) = self.get_player_proxy(&current).await {
            proxy.play_pause().await.is_ok()
        } else {
            false
        }
    }

    async fn next(&self) -> bool {
        let current = self.state.read().await.current_player.clone();
        if current.is_empty() {
            return false;
        }
        if let Some(proxy) = self.get_player_proxy(&current).await {
            proxy.next().await.is_ok()
        } else {
            false
        }
    }

    async fn previous(&self) -> bool {
        let current = self.state.read().await.current_player.clone();
        if current.is_empty() {
            return false;
        }
        if let Some(proxy) = self.get_player_proxy(&current).await {
            proxy.previous().await.is_ok()
        } else {
            false
        }
    }

    async fn set_player(&self, name: String) -> bool {
        let mut state = self.state.write().await;
        if state.players.contains_key(&name) {
            state.current_player = name;
            true
        } else {
            false
        }
    }

    #[zbus(signal)]
    async fn media_metadata_changed(ctx: &SignalEmitter<'_>) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn media_status_changed(ctx: &SignalEmitter<'_>, status: &str) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn media_players_changed(ctx: &SignalEmitter<'_>) -> zbus::Result<()>;
}

pub async fn run_media_dbus(conn: &Connection, state: SharedMediaState) -> anyhow::Result<()> {
    let iface = MediaInterface::new(state, conn.clone());
    conn.object_server()
        .at("/org/caelestia/Media", iface)
        .await?;

    info!("Media interface registered at /org/caelestia/Media");
    Ok(())
}

fn parse_metadata(meta: &HashMap<String, zbus::zvariant::OwnedValue>) -> MediaMetadata {
    let get_string = |key: &str| -> String {
        meta.get(key)
            .and_then(|v| <&str>::try_from(v).ok().map(|s| s.to_string()))
            .unwrap_or_default()
    };

    let artists: Vec<String> = meta
        .get("xesam:artist")
        .and_then(|v| <Vec<String>>::try_from(v.clone()).ok())
        .unwrap_or_default();

    let length = meta
        .get("mpris:length")
        .and_then(|v| i64::try_from(v).ok())
        .unwrap_or(0);

    MediaMetadata {
        title: get_string("xesam:title"),
        artist: artists.join(", "),
        album: get_string("xesam:album"),
        art_url: get_string("mpris:artUrl"),
        length_us: length,
    }
}

async fn fetch_player_info(conn: &Connection, bus_name: &str) -> Option<MediaPlayer> {
    let identity_proxy = MediaPlayer2Proxy::builder(conn)
        .destination(bus_name.to_string())
        .ok()?
        .build()
        .await
        .ok()?;

    let player_proxy = MediaPlayer2PlayerProxy::builder(conn)
        .destination(bus_name.to_string())
        .ok()?
        .build()
        .await
        .ok()?;

    Some(MediaPlayer {
        name: bus_name.to_string(),
        identity: identity_proxy.identity().await.unwrap_or_else(|_| bus_name.to_string()),
        playback_status: player_proxy.playback_status().await.unwrap_or_else(|_| "Stopped".to_string()),
        can_control: player_proxy.can_control().await.unwrap_or(false),
        can_go_next: player_proxy.can_go_next().await.unwrap_or(false),
        can_go_previous: player_proxy.can_go_previous().await.unwrap_or(false),
        can_play: player_proxy.can_play().await.unwrap_or(false),
        can_pause: player_proxy.can_pause().await.unwrap_or(false),
    })
}

async fn update_current_player_state(conn: &Connection, state: &SharedMediaState) {
    let current_player = state.read().await.current_player.clone();
    if current_player.is_empty() {
        return;
    }

    let proxy = match MediaPlayer2PlayerProxy::builder(conn)
        .destination(current_player.clone())
        .ok()
    {
        Some(b) => match b.build().await.ok() {
            Some(p) => p,
            None => return,
        },
        None => return,
    };

    let playback_status = proxy.playback_status().await.unwrap_or_else(|_| "Stopped".to_string());
    let position = proxy.position().await.unwrap_or(0);
    let metadata = proxy
        .metadata()
        .await
        .map(|m| parse_metadata(&m))
        .unwrap_or_default();

    let mut s = state.write().await;
    s.playback_status = playback_status;
    s.position = position;
    s.metadata = metadata;
}

fn select_current_player(state: &mut MediaState) {
    // Prefer a player that is Playing
    if let Some((name, _)) = state.players.iter().find(|(_, p)| p.playback_status == "Playing") {
        state.current_player = name.clone();
        return;
    }
    // Keep existing if still valid, otherwise pick first
    if !state.players.contains_key(&state.current_player) {
        state.current_player = state.players.keys().next().cloned().unwrap_or_default();
    }
}

pub async fn run_media_service(state: SharedMediaState, conn: Connection) {
    // Scan for existing MPRIS players
    if let Ok(dbus_proxy) = zbus::fdo::DBusProxy::new(&conn).await {
        if let Ok(names) = dbus_proxy.list_names().await {
            for name in names {
                let name_str = name.as_str();
                if name_str.starts_with("org.mpris.MediaPlayer2.") {
                    debug!("Found existing MPRIS player: {}", name_str);
                    if let Some(player) = fetch_player_info(&conn, name_str).await {
                        state.write().await.players.insert(name_str.to_string(), player);
                    }
                }
            }

            {
                let mut s = state.write().await;
                select_current_player(&mut s);
            }
            update_current_player_state(&conn, &state).await;

            let player_count = state.read().await.players.len();
            if player_count > 0 {
                info!("Found {} MPRIS players", player_count);
            }
        }
    }

    // Watch for NameOwnerChanged
    let dbus_proxy = match zbus::fdo::DBusProxy::new(&conn).await {
        Ok(p) => p,
        Err(e) => {
            error!("Failed to create DBus proxy: {}", e);
            std::future::pending::<()>().await;
            return;
        }
    };

    let mut stream = match dbus_proxy.receive_name_owner_changed().await {
        Ok(s) => s,
        Err(e) => {
            error!("Failed to create name owner changed stream: {}", e);
            std::future::pending::<()>().await;
            return;
        }
    };

    info!("Media service running, watching for MPRIS players");

    while let Some(signal) = stream.next().await {
        let args = match signal.args() {
            Ok(a) => a,
            Err(_) => continue,
        };

        let name = args.name.as_str();
        if !name.starts_with("org.mpris.MediaPlayer2.") {
            continue;
        }

        let old_owner = args.old_owner.as_ref().map(|s| s.as_str()).unwrap_or("");
        let new_owner = args.new_owner.as_ref().map(|s| s.as_str()).unwrap_or("");

        let mut players_changed = false;

        if new_owner.is_empty() && !old_owner.is_empty() {
            debug!("MPRIS player removed: {}", name);
            let mut s = state.write().await;
            s.players.remove(name);
            select_current_player(&mut s);
            players_changed = true;
        } else if !new_owner.is_empty() {
            debug!("MPRIS player added: {}", name);
            if let Some(player) = fetch_player_info(&conn, name).await {
                let mut s = state.write().await;
                s.players.insert(name.to_string(), player);
                select_current_player(&mut s);
                players_changed = true;
            }
        }

        if players_changed {
            update_current_player_state(&conn, &state).await;

            if let Ok(iface_ref) = conn
                .object_server()
                .interface::<_, MediaInterface>("/org/caelestia/Media")
                .await
            {
                let ctx = iface_ref.signal_emitter();
                let _ = MediaInterface::media_players_changed(&ctx).await;
            }
        }
    }
}
