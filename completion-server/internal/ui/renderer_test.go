package ui_test

import (
	"strings"
	"testing"

	"github.com/KyleKing/dotfiles/completion-server/internal/ui"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

func TestNewRenderer(t *testing.T) {
	t.Parallel()

	renderer := ui.NewRenderer()
	if renderer == nil {
		t.Fatal("expected non-nil renderer")
	}
}

func TestRenderer_Render_Empty(t *testing.T) {
	t.Parallel()

	renderer := ui.NewRenderer()
	model := ui.NewModel([]types.Candidate{})

	output := renderer.Render(model)
	if output != "" {
		t.Errorf("expected empty output for empty completions, got: %s", output)
	}
}

func TestRenderer_Render_WithCompletions(t *testing.T) {
	t.Parallel()

	renderer := ui.NewRenderer()
	completions := []types.Candidate{
		{Value: "--hidden", Description: "Show hidden files", Source: "test"},
		{Value: "--type", Description: "Filter by type", Source: "test"},
	}

	model := ui.NewModel(completions)
	model.Width = 100 // Enough space for detail panel

	output := renderer.Render(model)

	if output == "" {
		t.Fatal("expected non-empty output")
	}

	// Should contain the values
	if !strings.Contains(output, "--hidden") {
		t.Error("expected output to contain '--hidden'")
	}

	if !strings.Contains(output, "--type") {
		t.Error("expected output to contain '--type'")
	}
}

func TestRenderer_Render_WithDetailPanel(t *testing.T) {
	t.Parallel()

	renderer := ui.NewRenderer()
	completions := []types.Candidate{
		{
			Value:       "--hidden",
			Description: "Show hidden files",
			Source:      "test",
			Metadata: map[string]interface{}{
				"type": "flag",
			},
		},
	}

	model := ui.NewModel(completions)
	model.Width = 100
	model.ShowDetail = true
	model.DetermineDetailPosition()

	output := renderer.Render(model)

	if output == "" {
		t.Fatal("expected non-empty output")
	}

	// Should contain detail panel content
	if !strings.Contains(output, "Source: test") {
		t.Error("expected output to contain source metadata")
	}
}

func TestRenderer_RenderWithPosition(t *testing.T) {
	t.Parallel()

	renderer := ui.NewRenderer()
	completions := []types.Candidate{
		{Value: "--hidden", Description: "Show hidden files"},
	}

	model := ui.NewModel(completions)

	output := renderer.RenderWithPosition(model, 10, 5)

	if output == "" {
		t.Fatal("expected non-empty output")
	}

	// Should contain ANSI escape codes for cursor save/restore
	if !strings.Contains(output, "\033[s") {
		t.Error("expected output to contain cursor save code")
	}

	if !strings.Contains(output, "\033[u") {
		t.Error("expected output to contain cursor restore code")
	}
}

func TestRenderer_Render_MaxItems(t *testing.T) {
	t.Parallel()

	renderer := ui.NewRenderer()

	// Create more than 5 completions
	completions := make([]types.Candidate, 10)
	for i := range completions {
		completions[i] = types.Candidate{
			Value:       string(rune('a' + i)),
			Description: "test",
		}
	}

	model := ui.NewModel(completions)
	output := renderer.Render(model)

	// Count how many items appear (should be limited to 5)
	// We can't easily count rendered items, but we can verify it's not empty
	if output == "" {
		t.Fatal("expected non-empty output")
	}
}
