use anyhow::Result;
use freedesktop_desktop_entry::DesktopEntry;
use nucleo_matcher::{
    pattern::{CaseMatching, Normalization, Pattern},
    Config, Matcher,
};
use serde::{Deserialize, Serialize};
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::Command;
use std::sync::Arc;
use tokio::sync::RwLock;
use tracing::{debug, error, info, warn};
use walkdir::WalkDir;
use zbus::{interface, Connection};

/// Application entry parsed from .desktop file
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct App {
    /// Desktop file ID (e.g., "firefox.desktop")
    pub id: String,
    /// Display name
    pub name: String,
    /// Generic name (e.g., "Web Browser")
    #[serde(skip_serializing_if = "Option::is_none")]
    pub generic_name: Option<String>,
    /// Icon name or path
    #[serde(skip_serializing_if = "Option::is_none")]
    pub icon: Option<String>,
    /// Exec command
    pub exec: String,
    /// Search keywords
    #[serde(default)]
    pub keywords: Vec<String>,
    /// Categories
    #[serde(default)]
    pub categories: Vec<String>,
    /// Comment/description
    #[serde(skip_serializing_if = "Option::is_none")]
    pub comment: Option<String>,
    /// Path to the .desktop file
    #[serde(skip)]
    pub path: PathBuf,
    /// Launch count for sorting
    #[serde(default)]
    pub launch_count: u32,
}

/// Search result with score
#[derive(Debug, Clone, Serialize)]
pub struct SearchResult {
    pub app: App,
    pub score: u32,
}

/// Apps state
#[derive(Debug, Default)]
pub struct AppsState {
    /// All applications indexed by ID
    pub apps: HashMap<String, App>,
    /// Launch counts for frequency sorting
    pub launch_counts: HashMap<String, u32>,
}

pub type SharedAppsState = Arc<RwLock<AppsState>>;

/// Scan XDG directories for .desktop files
pub fn scan_desktop_entries() -> Vec<App> {
    let mut apps = Vec::new();
    let locales = get_locales();

    // Get XDG data directories
    let data_dirs = get_xdg_data_dirs();

    for base_dir in data_dirs {
        let applications_dir = base_dir.join("applications");
        if !applications_dir.exists() {
            continue;
        }

        debug!("Scanning {:?}", applications_dir);

        // Walk directory for .desktop files
        for entry in WalkDir::new(&applications_dir).max_depth(2) {
            let entry = match entry {
                Ok(e) => e,
                Err(_) => continue,
            };
            let path = entry.path();
            if path.extension().map_or(false, |ext| ext == "desktop") {
                match parse_desktop_entry(&path.to_path_buf(), &locales) {
                    Ok(Some(app)) => {
                        apps.push(app);
                    }
                    Ok(None) => {
                        // Entry was hidden/no display, skip silently
                    }
                    Err(e) => {
                        debug!("Failed to parse {:?}: {}", path, e);
                    }
                }
            }
        }
    }

    info!("Found {} applications", apps.len());
    apps
}

/// Get XDG data directories
fn get_xdg_data_dirs() -> Vec<PathBuf> {
    let mut dirs = Vec::new();

    // User data dir first (highest priority)
    if let Some(data_home) = dirs::data_dir() {
        dirs.push(data_home);
    }

    // XDG_DATA_DIRS
    if let Ok(xdg_dirs) = std::env::var("XDG_DATA_DIRS") {
        for dir in xdg_dirs.split(':') {
            if !dir.is_empty() {
                dirs.push(PathBuf::from(dir));
            }
        }
    } else {
        // Default fallbacks
        dirs.push(PathBuf::from("/usr/local/share"));
        dirs.push(PathBuf::from("/usr/share"));
    }

    // Flatpak exports
    if let Some(data_home) = dirs::data_dir() {
        dirs.push(data_home.join("flatpak/exports/share"));
    }
    dirs.push(PathBuf::from("/var/lib/flatpak/exports/share"));

    dirs
}

/// Get system locales for name resolution
fn get_locales() -> Vec<String> {
    let mut locales = Vec::new();

    if let Ok(lang) = std::env::var("LANG") {
        // Parse LANG like "en_US.UTF-8"
        let lang = lang.split('.').next().unwrap_or(&lang);
        locales.push(lang.to_string());

        // Also add just the language code
        if let Some(code) = lang.split('_').next() {
            if code != lang {
                locales.push(code.to_string());
            }
        }
    }

    locales
}

/// Parse a single .desktop file
fn parse_desktop_entry(path: &PathBuf, locales: &[String]) -> Result<Option<App>> {
    let content = std::fs::read_to_string(path)?;
    let entry = DesktopEntry::from_str(path, &content, Some(locales))?;

    // Skip if NoDisplay or Hidden
    if entry.no_display() || entry.hidden() {
        return Ok(None);
    }

    // Skip non-Application types
    if entry.type_() != Some("Application") {
        return Ok(None);
    }

    // Must have a name and exec
    let name = match entry.name(locales) {
        Some(n) => n.to_string(),
        None => return Ok(None),
    };

    let exec = match entry.exec() {
        Some(e) => e.to_string(),
        None => return Ok(None),
    };

    // Get desktop file ID from path
    let id = path
        .file_name()
        .and_then(|n| n.to_str())
        .unwrap_or("unknown")
        .to_string();

    let app = App {
        id,
        name,
        generic_name: entry.generic_name(locales).map(|s| s.to_string()),
        icon: entry.icon().map(|s| s.to_string()),
        exec,
        keywords: entry
            .keywords(locales)
            .map(|k| k.into_iter().map(|s| s.to_string()).collect())
            .unwrap_or_default(),
        categories: entry
            .categories()
            .map(|c| c.into_iter().map(|s| s.to_string()).collect())
            .unwrap_or_default(),
        comment: entry.comment(locales).map(|s| s.to_string()),
        path: path.clone(),
        launch_count: 0,
    };

    Ok(Some(app))
}

/// Fuzzy search apps
pub fn search_apps(apps: &HashMap<String, App>, query: &str, limit: usize) -> Vec<SearchResult> {
    if query.is_empty() {
        // Return all apps sorted by launch count, then name
        let mut results: Vec<_> = apps
            .values()
            .map(|app| SearchResult {
                app: app.clone(),
                score: app.launch_count * 1000, // Boost by launch count
            })
            .collect();

        results.sort_by(|a, b| {
            b.score
                .cmp(&a.score)
                .then_with(|| a.app.name.to_lowercase().cmp(&b.app.name.to_lowercase()))
        });

        results.truncate(limit);
        return results;
    }

    let mut matcher = Matcher::new(Config::DEFAULT);
    let pattern = Pattern::parse(query, CaseMatching::Ignore, Normalization::Smart);

    let mut results: Vec<SearchResult> = apps
        .values()
        .filter_map(|app| {
            // Build searchable text: name + generic_name + keywords
            let mut haystack = app.name.clone();
            if let Some(ref generic) = app.generic_name {
                haystack.push(' ');
                haystack.push_str(generic);
            }
            for keyword in &app.keywords {
                haystack.push(' ');
                haystack.push_str(keyword);
            }

            // Match against the haystack
            let mut buf = Vec::new();
            let score = pattern.score(nucleo_matcher::Utf32Str::new(&haystack, &mut buf), &mut matcher)?;

            Some(SearchResult {
                app: app.clone(),
                score: score + app.launch_count * 100, // Boost frequent apps
            })
        })
        .collect();

    // Sort by score descending
    results.sort_by(|a, b| b.score.cmp(&a.score));
    results.truncate(limit);

    results
}

/// Launch an application
pub fn launch_app(app: &App) -> Result<()> {
    let exec = &app.exec;

    // Remove field codes (%f, %F, %u, %U, etc.)
    let exec_clean: String = exec
        .split_whitespace()
        .filter(|s| !s.starts_with('%'))
        .collect::<Vec<_>>()
        .join(" ");

    debug!("Launching: {}", exec_clean);

    // Use sh -c to handle complex exec lines
    Command::new("sh")
        .arg("-c")
        .arg(&exec_clean)
        .spawn()?;

    Ok(())
}

/// DBus interface for apps
pub struct AppsInterface {
    state: SharedAppsState,
}

impl AppsInterface {
    pub fn new(state: SharedAppsState) -> Self {
        Self { state }
    }
}

#[interface(name = "org.caelestia.Apps")]
impl AppsInterface {
    /// Get all apps as JSON array
    #[zbus(property)]
    async fn apps(&self) -> String {
        let state = self.state.read().await;
        let apps: Vec<&App> = state.apps.values().collect();
        serde_json::to_string(&apps).unwrap_or_else(|_| "[]".to_string())
    }

    /// Get app count
    #[zbus(property)]
    async fn app_count(&self) -> u32 {
        self.state.read().await.apps.len() as u32
    }

    /// Search apps with fuzzy matching, returns JSON array of results
    async fn search(&self, query: String, limit: u32) -> String {
        let state = self.state.read().await;
        let limit = if limit == 0 { 50 } else { limit as usize };
        let results = search_apps(&state.apps, &query, limit);

        // Return just the apps, not the scores
        let apps: Vec<&App> = results.iter().map(|r| &r.app).collect();
        serde_json::to_string(&apps).unwrap_or_else(|_| "[]".to_string())
    }

    /// Launch an app by ID, returns success
    async fn launch(&self, app_id: String) -> bool {
        let state = self.state.read().await;

        if let Some(app) = state.apps.get(&app_id) {
            match launch_app(app) {
                Ok(()) => {
                    info!("Launched: {}", app.name);
                    true
                }
                Err(e) => {
                    error!("Failed to launch {}: {}", app.name, e);
                    false
                }
            }
        } else {
            warn!("App not found: {}", app_id);
            false
        }
    }

    /// Record a launch for frequency tracking
    async fn record_launch(&self, app_id: String) {
        let mut state = self.state.write().await;

        let count = state.launch_counts.entry(app_id.clone()).or_insert(0);
        *count += 1;
        let new_count = *count;

        if let Some(app) = state.apps.get_mut(&app_id) {
            app.launch_count = new_count;
        }

        debug!("Recorded launch for {}, count: {}", app_id, new_count);
    }

    /// Rescan applications
    async fn rescan(&self) {
        let apps = scan_desktop_entries();
        let mut state = self.state.write().await;

        state.apps.clear();
        for mut app in apps {
            // Restore launch count if we have it
            if let Some(&count) = state.launch_counts.get(&app.id) {
                app.launch_count = count;
            }
            state.apps.insert(app.id.clone(), app);
        }

        info!("Rescanned, found {} apps", state.apps.len());
    }

    /// Signal emitted when apps change
    #[zbus(signal)]
    async fn apps_updated(ctx: &zbus::object_server::SignalContext<'_>) -> zbus::Result<()>;
}

/// Initialize apps state with scanned entries
pub async fn init_apps_state() -> SharedAppsState {
    let apps = scan_desktop_entries();
    let mut apps_map = HashMap::new();

    for app in apps {
        apps_map.insert(app.id.clone(), app);
    }

    Arc::new(RwLock::new(AppsState {
        apps: apps_map,
        launch_counts: HashMap::new(),
    }))
}

/// Register apps DBus interface
pub async fn run_apps_dbus(conn: &Connection, state: SharedAppsState) -> Result<()> {
    let interface = AppsInterface::new(state);

    conn.object_server()
        .at("/org/caelestia/Apps", interface)
        .await?;

    info!("Apps interface registered at /org/caelestia/Apps");
    Ok(())
}
