package ui

import (
	"fmt"
	"strings"

	"github.com/charmbracelet/lipgloss"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// Renderer handles rendering the UI
type Renderer struct {
	styles *Styles
}

// NewRenderer creates a new UI renderer
func NewRenderer() *Renderer {
	return &Renderer{
		styles: DefaultStyles(),
	}
}

// Render generates the complete UI output
func (r *Renderer) Render(model *Model) string {
	if len(model.Completions) == 0 {
		return ""
	}

	// Update detail position based on available space
	model.DetermineDetailPosition()

	// Render main panel
	mainPanel := r.renderMainPanel(model)

	// Render detail panel if shown
	var detailPanel string
	if model.DetailPosition != DetailHidden && model.SelectedCompletion() != nil {
		detailPanel = r.renderDetailPanel(model)
	}

	// Combine panels based on detail position
	var output string
	if model.DetailPosition == DetailLeft {
		output = lipgloss.JoinHorizontal(lipgloss.Top, detailPanel, mainPanel)
	} else if model.DetailPosition == DetailRight {
		output = lipgloss.JoinHorizontal(lipgloss.Top, mainPanel, detailPanel)
	} else {
		output = mainPanel
	}

	return output
}

// renderMainPanel renders the completion list
func (r *Renderer) renderMainPanel(model *Model) string {
	var items []string

	maxItems := 5
	if len(model.Completions) < maxItems {
		maxItems = len(model.Completions)
	}

	for i := 0; i < maxItems; i++ {
		completion := model.Completions[i]
		itemStr := r.renderItem(completion, i == model.SelectedIndex)
		items = append(items, itemStr)
	}

	content := strings.Join(items, "\n")
	return r.styles.MainPanel.Render(content)
}

// renderItem renders a single completion item
func (r *Renderer) renderItem(completion types.Candidate, selected bool) string {
	// Format: "[value] description"
	valueStr := r.styles.ItemValue.Render(completion.Value)
	descStr := r.styles.ItemDescription.Render(completion.Description)

	line := fmt.Sprintf("%s  %s", valueStr, descStr)

	// Truncate if too long
	maxLen := 35
	if len(line) > maxLen {
		line = line[:maxLen] + "…"
	}

	if selected {
		return r.styles.SelectedItem.Render(line)
	}
	return r.styles.UnselectedItem.Render(line)
}

// renderDetailPanel renders the detail panel for the selected item
func (r *Renderer) renderDetailPanel(model *Model) string {
	selected := model.SelectedCompletion()
	if selected == nil {
		return ""
	}

	var content strings.Builder

	// Title
	title := r.styles.DetailTitle.Render(selected.Value)
	content.WriteString(title)
	content.WriteString("\n")

	// Description
	if selected.Description != "" {
		desc := r.styles.DetailDescription.Render(selected.Description)
		content.WriteString(desc)
		content.WriteString("\n")
	}

	// Metadata
	if len(selected.Metadata) > 0 {
		metadata := fmt.Sprintf("Source: %s", selected.Source)
		if display := selected.Display; display != "" && display != selected.Value {
			metadata += fmt.Sprintf("\nDisplay: %s", display)
		}
		metaStr := r.styles.DetailMetadata.Render(metadata)
		content.WriteString(metaStr)
	}

	return r.styles.DetailPanel.Render(content.String())
}

// RenderWithPosition wraps the output with ANSI escape codes for positioning
func (r *Renderer) RenderWithPosition(model *Model, cursorRow, cursorCol int) string {
	content := r.Render(model)
	if content == "" {
		return ""
	}

	// ANSI escape codes for cursor positioning
	// Save cursor, move to position, render, restore cursor

	var sb strings.Builder

	// Save cursor position
	sb.WriteString("\033[s")

	// Move cursor based on position
	if model.Position == PositionAbove {
		// Move up from current position
		lines := strings.Count(content, "\n") + 2
		sb.WriteString(fmt.Sprintf("\033[%dA", lines))
	} else {
		// Move down (below prompt)
		sb.WriteString("\n")
	}

	// Render content
	sb.WriteString(content)

	// Restore cursor position
	sb.WriteString("\033[u")

	return sb.String()
}
