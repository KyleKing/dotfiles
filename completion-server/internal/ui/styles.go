package ui

import "github.com/charmbracelet/lipgloss"

// Styles for the UI
type Styles struct {
	// Main panel styles
	MainPanel       lipgloss.Style
	SelectedItem    lipgloss.Style
	UnselectedItem  lipgloss.Style
	ItemValue       lipgloss.Style
	ItemDescription lipgloss.Style

	// Detail panel styles
	DetailPanel       lipgloss.Style
	DetailTitle       lipgloss.Style
	DetailDescription lipgloss.Style
	DetailMetadata    lipgloss.Style
}

// DefaultStyles returns default lipgloss styles
func DefaultStyles() *Styles {
	return &Styles{
		MainPanel: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("240")).
			Padding(0, 1).
			Width(40),

		SelectedItem: lipgloss.NewStyle().
			Background(lipgloss.Color("62")).
			Foreground(lipgloss.Color("230")).
			Bold(true),

		UnselectedItem: lipgloss.NewStyle().
			Foreground(lipgloss.Color("252")),

		ItemValue: lipgloss.NewStyle().
			Foreground(lipgloss.Color("86")).
			Bold(true),

		ItemDescription: lipgloss.NewStyle().
			Foreground(lipgloss.Color("243")),

		DetailPanel: lipgloss.NewStyle().
			Border(lipgloss.RoundedBorder()).
			BorderForeground(lipgloss.Color("240")).
			Padding(1).
			Width(50),

		DetailTitle: lipgloss.NewStyle().
			Foreground(lipgloss.Color("86")).
			Bold(true).
			Underline(true),

		DetailDescription: lipgloss.NewStyle().
			Foreground(lipgloss.Color("252")).
			MarginTop(1),

		DetailMetadata: lipgloss.NewStyle().
			Foreground(lipgloss.Color("243")).
			Italic(true).
			MarginTop(1),
	}
}
