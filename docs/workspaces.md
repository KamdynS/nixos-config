# Workspace Indicators

Documentation for the Caelestia shell workspace indicator styling.

## Location

`home/caelestia/modules/bar/components/workspaces/Workspace.qml`

## Design Goals

The workspace indicators should be clearly visible and match the current theme aesthetic:

- **Inactive workspaces**: Contrasting background with muted numbered text
- **Active workspace**: Primary color background with contrasting text
- All workspace numbers should be easily visible at a glance

## Color Mapping

Colors are dynamically loaded from the current theme file (`themes/*.json`). The workspace component uses these M3 palette values:

| State    | Background          | Text            |
|----------|---------------------|-----------------|
| Inactive | `m3onSurface`       | `m3outline`     |
| Active   | `m3primary`         | `m3onPrimary`   |
| Hovered  | `m3surfaceBright`   | `m3onSurface`   |

### Gruvbox Dark
| State    | Background | Text      |
|----------|------------|-----------|
| Inactive | #ebdbb2    | #665c54   |
| Active   | #d79921    | #1d2021   |

### Gruvbox Light
| State    | Background | Text      |
|----------|------------|-----------|
| Inactive | #3c3836    | #7c6f64   |
| Active   | #b57614    | #fbf1c7   |

## Notes

- No border is used; workspaces have solid filled backgrounds
- Colors are loaded from theme JSON files in `themes/` via `stubs/Theme.qml`
- Theme changes propagate to `Colours.loadFromTheme()` which updates the M3 palette
