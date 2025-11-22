package ui

import "github.com/KyleKing/dotfiles/completion-server/pkg/types"

// Position indicates where the overlay is displayed
type Position int

const (
	// PositionAbove displays overlay above the prompt
	PositionAbove Position = iota
	// PositionBelow displays overlay below the prompt
	PositionBelow
)

// DetailPosition indicates where the detail panel is displayed
type DetailPosition int

const (
	// DetailHidden hides the detail panel
	DetailHidden DetailPosition = iota
	// DetailLeft shows detail panel on the left
	DetailLeft
	// DetailRight shows detail panel on the right
	DetailRight
)

// Model represents the UI state
type Model struct {
	// Completions to display
	Completions []types.Candidate

	// Selected index
	SelectedIndex int

	// Overlay position (above/below prompt)
	Position Position

	// Detail panel position
	DetailPosition DetailPosition

	// Terminal dimensions
	Width  int
	Height int

	// Show detail panel for selected item
	ShowDetail bool
}

// NewModel creates a new UI model
func NewModel(completions []types.Candidate) *Model {
	return &Model{
		Completions:    completions,
		SelectedIndex:  0,
		Position:       PositionBelow,
		DetailPosition: DetailHidden,
		Width:          80,  // Default
		Height:         24,  // Default
		ShowDetail:     false,
	}
}

// TogglePosition toggles between above/below
func (m *Model) TogglePosition() {
	if m.Position == PositionAbove {
		m.Position = PositionBelow
	} else {
		m.Position = PositionAbove
	}
}

// NextItem moves selection down
func (m *Model) NextItem() {
	if len(m.Completions) == 0 {
		return
	}
	m.SelectedIndex = (m.SelectedIndex + 1) % len(m.Completions)
}

// PrevItem moves selection up
func (m *Model) PrevItem() {
	if len(m.Completions) == 0 {
		return
	}
	m.SelectedIndex = (m.SelectedIndex - 1 + len(m.Completions)) % len(m.Completions)
}

// SelectedCompletion returns the currently selected completion
func (m *Model) SelectedCompletion() *types.Candidate {
	if len(m.Completions) == 0 || m.SelectedIndex < 0 || m.SelectedIndex >= len(m.Completions) {
		return nil
	}
	return &m.Completions[m.SelectedIndex]
}

// DetermineDetailPosition determines where to show detail panel based on available space
func (m *Model) DetermineDetailPosition() {
	if !m.ShowDetail {
		m.DetailPosition = DetailHidden
		return
	}

	// Simplified logic: show on right if enough space, otherwise left, otherwise hidden
	mainPanelWidth := 40
	detailPanelWidth := 50

	if m.Width >= mainPanelWidth+detailPanelWidth+5 {
		m.DetailPosition = DetailRight
	} else if m.Width >= mainPanelWidth+30 {
		m.DetailPosition = DetailLeft
	} else {
		m.DetailPosition = DetailHidden
	}
}
