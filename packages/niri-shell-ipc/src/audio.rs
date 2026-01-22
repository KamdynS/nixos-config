use anyhow::Result;
use libpulse_binding::{
    callbacks::ListResult,
    context::{
        subscribe::{Facility, InterestMaskSet},
        Context, FlagSet as ContextFlagSet, State as ContextState,
    },
    mainloop::standard::{IterateResult, Mainloop},
    proplist::Proplist,
    volume::{ChannelVolumes, Volume},
};
use serde::Serialize;
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::{Arc, RwLock};
use tokio::sync::mpsc;
use tracing::{debug, error, info, warn};
use zbus::{interface, Connection};

/// Audio sink (output device)
#[derive(Debug, Clone, Serialize, Default)]
pub struct Sink {
    pub index: u32,
    pub name: String,
    pub description: String,
    pub volume: f64,
    pub muted: bool,
    pub is_default: bool,
}

/// Audio source (input device)
#[derive(Debug, Clone, Serialize, Default)]
pub struct Source {
    pub index: u32,
    pub name: String,
    pub description: String,
    pub volume: f64,
    pub muted: bool,
    pub is_default: bool,
}

/// Audio state
#[derive(Debug, Clone, Serialize, Default)]
pub struct AudioState {
    pub volume: f64,
    pub muted: bool,
    pub mic_volume: f64,
    pub mic_muted: bool,
    pub default_sink: String,
    pub default_source: String,
    pub sinks: Vec<Sink>,
    pub sources: Vec<Source>,
}

pub type SharedAudioState = Arc<RwLock<AudioState>>;

/// Commands to send to PulseAudio thread
#[derive(Debug)]
pub enum AudioCommand {
    SetVolume(f64),
    SetMuted(bool),
    SetMicVolume(f64),
    SetMicMuted(bool),
    SetDefaultSink(String),
    SetDefaultSource(String),
}

/// Run the PulseAudio client in a blocking thread
pub fn run_audio_blocking(
    state: SharedAudioState,
    mut cmd_rx: mpsc::Receiver<AudioCommand>,
) {
    // Create mainloop and context
    let mainloop = Rc::new(RefCell::new(
        Mainloop::new().expect("Failed to create PulseAudio mainloop"),
    ));

    let mut proplist = Proplist::new().unwrap();
    proplist
        .set_str(
            libpulse_binding::proplist::properties::APPLICATION_NAME,
            "niri-shell-ipc",
        )
        .unwrap();

    let context = Rc::new(RefCell::new(
        Context::new_with_proplist(&*mainloop.borrow(), "niri-shell-ipc", &proplist)
            .expect("Failed to create PulseAudio context"),
    ));

    // Connect to server
    context
        .borrow_mut()
        .connect(None, ContextFlagSet::NOFLAGS, None)
        .expect("Failed to connect to PulseAudio");

    // Wait for connection
    loop {
        match mainloop.borrow_mut().iterate(true) {
            IterateResult::Success(_) => {}
            IterateResult::Quit(_) | IterateResult::Err(_) => {
                error!("PulseAudio mainloop error during connection");
                return;
            }
        }

        match context.borrow().get_state() {
            ContextState::Ready => break,
            ContextState::Failed | ContextState::Terminated => {
                error!("PulseAudio context failed");
                return;
            }
            _ => {}
        }
    }

    info!("Connected to PulseAudio");

    // Set up subscription for changes
    let state_for_sub = state.clone();
    let context_for_sub = context.clone();

    context.borrow_mut().subscribe(
        InterestMaskSet::SINK | InterestMaskSet::SOURCE | InterestMaskSet::SERVER,
        |success| {
            if !success {
                warn!("Failed to subscribe to PulseAudio events");
            }
        },
    );

    // Set subscription callback
    let mainloop_for_cb = mainloop.clone();
    context
        .borrow_mut()
        .set_subscribe_callback(Some(Box::new(move |facility, operation, _index| {
            debug!("PulseAudio event: {:?} {:?}", facility, operation);
            // We'll refresh state on any relevant change
            match facility {
                Some(Facility::Sink) | Some(Facility::Source) | Some(Facility::Server) => {
                    // Signal mainloop to refresh (handled in main loop below)
                }
                _ => {}
            }
        })));

    // Initial state fetch
    fetch_all_state(&context, &state, &mainloop);

    info!("Audio service running");

    // Main loop
    loop {
        // Check for commands (non-blocking)
        match cmd_rx.try_recv() {
            Ok(cmd) => {
                handle_command(&context, &cmd, &state, &mainloop);
            }
            Err(mpsc::error::TryRecvError::Empty) => {}
            Err(mpsc::error::TryRecvError::Disconnected) => {
                info!("Audio command channel closed, exiting");
                break;
            }
        }

        // Iterate mainloop (with short timeout to allow checking commands)
        match mainloop.borrow_mut().iterate(false) {
            IterateResult::Success(_) => {}
            IterateResult::Quit(_) => break,
            IterateResult::Err(e) => {
                error!("PulseAudio mainloop error: {:?}", e);
                break;
            }
        }

        // Small sleep to prevent busy loop
        std::thread::sleep(std::time::Duration::from_millis(50));
    }
}

/// Fetch all audio state
fn fetch_all_state(
    context: &Rc<RefCell<Context>>,
    state: &SharedAudioState,
    mainloop: &Rc<RefCell<Mainloop>>,
) {
    let introspect = context.borrow().introspect();

    // Get server info (for defaults)
    let state_clone = state.clone();
    introspect.get_server_info(move |info| {
        let default_sink = info.default_sink_name.as_ref().map(|s| s.to_string()).unwrap_or_default();
        let default_source = info.default_source_name.as_ref().map(|s| s.to_string()).unwrap_or_default();
        if let Ok(mut s) = state_clone.write() {
            s.default_sink = default_sink;
            s.default_source = default_source;
        }
    });

    // Get sinks
    let state_clone = state.clone();
    introspect.get_sink_info_list(move |result| {
        if let ListResult::Item(info) = result {
            let sink = Sink {
                index: info.index,
                name: info.name.as_ref().map(|s| s.to_string()).unwrap_or_default(),
                description: info.description.as_ref().map(|s| s.to_string()).unwrap_or_default(),
                volume: volume_to_percent(&info.volume),
                muted: info.mute,
                is_default: false,
            };
            if let Ok(mut s) = state_clone.write() {
                // Update or add sink
                if let Some(existing) = s.sinks.iter_mut().find(|x| x.index == sink.index) {
                    *existing = sink;
                } else {
                    s.sinks.push(sink);
                }
                // Get default sink name and find default volume/mute
                let default_sink = s.default_sink.clone();
                let default_vol_mute = s.sinks.iter()
                    .find(|x| x.name == default_sink)
                    .map(|d| (d.volume, d.muted));
                if let Some((vol, muted)) = default_vol_mute {
                    s.volume = vol;
                    s.muted = muted;
                }
                // Mark default
                for sink in &mut s.sinks {
                    sink.is_default = sink.name == default_sink;
                }
            }
        }
    });

    // Get sources
    let state_clone = state.clone();
    introspect.get_source_info_list(move |result| {
        if let ListResult::Item(info) = result {
            // Skip monitor sources
            if info.monitor_of_sink.is_some() {
                return;
            }
            let source = Source {
                index: info.index,
                name: info.name.as_ref().map(|s| s.to_string()).unwrap_or_default(),
                description: info.description.as_ref().map(|s| s.to_string()).unwrap_or_default(),
                volume: volume_to_percent(&info.volume),
                muted: info.mute,
                is_default: false,
            };
            if let Ok(mut s) = state_clone.write() {
                if let Some(existing) = s.sources.iter_mut().find(|x| x.index == source.index) {
                    *existing = source;
                } else {
                    s.sources.push(source);
                }
                // Get default source name and find default volume/mute
                let default_source = s.default_source.clone();
                let default_vol_mute = s.sources.iter()
                    .find(|x| x.name == default_source)
                    .map(|d| (d.volume, d.muted));
                if let Some((vol, muted)) = default_vol_mute {
                    s.mic_volume = vol;
                    s.mic_muted = muted;
                }
                // Mark default
                for source in &mut s.sources {
                    source.is_default = source.name == default_source;
                }
            }
        }
    });

    // Iterate to process callbacks
    for _ in 0..10 {
        mainloop.borrow_mut().iterate(false);
        std::thread::sleep(std::time::Duration::from_millis(10));
    }
}

/// Handle a command
fn handle_command(
    context: &Rc<RefCell<Context>>,
    cmd: &AudioCommand,
    state: &SharedAudioState,
    mainloop: &Rc<RefCell<Mainloop>>,
) {
    let introspect = context.borrow().introspect();

    match cmd {
        AudioCommand::SetVolume(vol) => {
            let sink_name = state.read().ok().map(|s| s.default_sink.clone()).unwrap_or_default();
            if !sink_name.is_empty() {
                let mut introspect = context.borrow().introspect();
                let cv = percent_to_volume(*vol);
                introspect.set_sink_volume_by_name(&sink_name, &cv, None);
            }
        }
        AudioCommand::SetMuted(muted) => {
            let sink_name = state.read().ok().map(|s| s.default_sink.clone()).unwrap_or_default();
            if !sink_name.is_empty() {
                let mut introspect = context.borrow().introspect();
                introspect.set_sink_mute_by_name(&sink_name, *muted, None);
            }
        }
        AudioCommand::SetMicVolume(vol) => {
            let source_name = state.read().ok().map(|s| s.default_source.clone()).unwrap_or_default();
            if !source_name.is_empty() {
                let mut introspect = context.borrow().introspect();
                let cv = percent_to_volume(*vol);
                introspect.set_source_volume_by_name(&source_name, &cv, None);
            }
        }
        AudioCommand::SetMicMuted(muted) => {
            let source_name = state.read().ok().map(|s| s.default_source.clone()).unwrap_or_default();
            if !source_name.is_empty() {
                let mut introspect = context.borrow().introspect();
                introspect.set_source_mute_by_name(&source_name, *muted, None);
            }
        }
        AudioCommand::SetDefaultSink(name) => {
            context.borrow_mut().set_default_sink(name, |_| {});
        }
        AudioCommand::SetDefaultSource(name) => {
            context.borrow_mut().set_default_source(name, |_| {});
        }
    }

    // Process the command
    for _ in 0..5 {
        mainloop.borrow_mut().iterate(false);
        std::thread::sleep(std::time::Duration::from_millis(10));
    }

    // Refresh state after command
    fetch_all_state(context, state, mainloop);
}

/// Convert PulseAudio volume to percentage (0.0-1.0)
fn volume_to_percent(cv: &ChannelVolumes) -> f64 {
    let avg = cv.avg();
    avg.0 as f64 / Volume::NORMAL.0 as f64
}

/// Convert percentage to PulseAudio volume
fn percent_to_volume(percent: f64) -> ChannelVolumes {
    let vol = (percent.clamp(0.0, 1.5) * Volume::NORMAL.0 as f64) as u32;
    let mut cv = ChannelVolumes::default();
    cv.set(2, Volume(vol)); // Stereo
    cv
}

/// DBus interface for audio
pub struct AudioInterface {
    state: SharedAudioState,
    cmd_tx: mpsc::Sender<AudioCommand>,
}

impl AudioInterface {
    pub fn new(state: SharedAudioState, cmd_tx: mpsc::Sender<AudioCommand>) -> Self {
        Self { state, cmd_tx }
    }
}

#[interface(name = "org.caelestia.Audio")]
impl AudioInterface {
    #[zbus(property)]
    async fn volume(&self) -> f64 {
        self.state.read().map(|s| s.volume).unwrap_or(0.0)
    }

    #[zbus(property)]
    async fn muted(&self) -> bool {
        self.state.read().map(|s| s.muted).unwrap_or(false)
    }

    #[zbus(property)]
    async fn mic_volume(&self) -> f64 {
        self.state.read().map(|s| s.mic_volume).unwrap_or(0.0)
    }

    #[zbus(property)]
    async fn mic_muted(&self) -> bool {
        self.state.read().map(|s| s.mic_muted).unwrap_or(false)
    }

    #[zbus(property)]
    async fn default_sink(&self) -> String {
        self.state.read().map(|s| s.default_sink.clone()).unwrap_or_default()
    }

    #[zbus(property)]
    async fn default_source(&self) -> String {
        self.state.read().map(|s| s.default_source.clone()).unwrap_or_default()
    }

    #[zbus(property)]
    async fn sinks(&self) -> String {
        self.state.read()
            .map(|s| serde_json::to_string(&s.sinks).unwrap_or_else(|_| "[]".to_string()))
            .unwrap_or_else(|_| "[]".to_string())
    }

    #[zbus(property)]
    async fn sources(&self) -> String {
        self.state.read()
            .map(|s| serde_json::to_string(&s.sources).unwrap_or_else(|_| "[]".to_string()))
            .unwrap_or_else(|_| "[]".to_string())
    }

    /// Get all audio info as JSON
    #[zbus(property)]
    async fn info(&self) -> String {
        self.state.read()
            .map(|s| serde_json::to_string(&*s).unwrap_or_else(|_| "{}".to_string()))
            .unwrap_or_else(|_| "{}".to_string())
    }

    /// Set master volume (0.0-1.0)
    async fn set_volume(&self, volume: f64) -> bool {
        self.cmd_tx
            .send(AudioCommand::SetVolume(volume))
            .await
            .is_ok()
    }

    /// Set master mute
    async fn set_muted(&self, muted: bool) -> bool {
        self.cmd_tx
            .send(AudioCommand::SetMuted(muted))
            .await
            .is_ok()
    }

    /// Set mic volume (0.0-1.0)
    async fn set_mic_volume(&self, volume: f64) -> bool {
        self.cmd_tx
            .send(AudioCommand::SetMicVolume(volume))
            .await
            .is_ok()
    }

    /// Set mic mute
    async fn set_mic_muted(&self, muted: bool) -> bool {
        self.cmd_tx
            .send(AudioCommand::SetMicMuted(muted))
            .await
            .is_ok()
    }

    /// Set default sink by name
    async fn set_default_sink(&self, name: String) -> bool {
        self.cmd_tx
            .send(AudioCommand::SetDefaultSink(name))
            .await
            .is_ok()
    }

    /// Set default source by name
    async fn set_default_source(&self, name: String) -> bool {
        self.cmd_tx
            .send(AudioCommand::SetDefaultSource(name))
            .await
            .is_ok()
    }

    /// Increase volume by delta
    async fn increase_volume(&self, delta: f64) -> f64 {
        let current = self.state.read().map(|s| s.volume).unwrap_or(0.0);
        let new_vol = (current + delta).clamp(0.0, 1.0);
        let _ = self.cmd_tx.send(AudioCommand::SetVolume(new_vol)).await;
        new_vol
    }

    /// Decrease volume by delta
    async fn decrease_volume(&self, delta: f64) -> f64 {
        let current = self.state.read().map(|s| s.volume).unwrap_or(0.0);
        let new_vol = (current - delta).clamp(0.0, 1.0);
        let _ = self.cmd_tx.send(AudioCommand::SetVolume(new_vol)).await;
        new_vol
    }

    /// Toggle mute
    async fn toggle_mute(&self) -> bool {
        let current = self.state.read().map(|s| s.muted).unwrap_or(false);
        let _ = self.cmd_tx.send(AudioCommand::SetMuted(!current)).await;
        !current
    }

    /// Toggle mic mute
    async fn toggle_mic_mute(&self) -> bool {
        let current = self.state.read().map(|s| s.mic_muted).unwrap_or(false);
        let _ = self.cmd_tx.send(AudioCommand::SetMicMuted(!current)).await;
        !current
    }

    #[zbus(signal)]
    async fn volume_updated(ctx: &zbus::object_server::SignalContext<'_>, volume: f64) -> zbus::Result<()>;

    #[zbus(signal)]
    async fn mute_updated(ctx: &zbus::object_server::SignalContext<'_>, muted: bool) -> zbus::Result<()>;
}

/// Initialize audio state
pub fn init_audio_state() -> (SharedAudioState, mpsc::Sender<AudioCommand>) {
    let (cmd_tx, cmd_rx) = mpsc::channel(32);
    let state = Arc::new(RwLock::new(AudioState::default()));

    // Spawn PulseAudio thread
    let state_clone = state.clone();
    std::thread::spawn(move || {
        run_audio_blocking(state_clone, cmd_rx);
    });

    (state, cmd_tx)
}

/// Register audio DBus interface
pub async fn run_audio_dbus(
    conn: &Connection,
    state: SharedAudioState,
    cmd_tx: mpsc::Sender<AudioCommand>,
) -> Result<()> {
    let interface = AudioInterface::new(state, cmd_tx);

    conn.object_server()
        .at("/org/caelestia/Audio", interface)
        .await?;

    info!("Audio interface registered at /org/caelestia/Audio");
    Ok(())
}
