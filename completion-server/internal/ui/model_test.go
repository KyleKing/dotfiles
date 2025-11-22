package ui_test

import (
	"testing"

	"github.com/KyleKing/dotfiles/completion-server/internal/ui"
	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

func TestNewModel(t *testing.T) {
	t.Parallel()

	completions := []types.Candidate{
		{Value: "--hidden", Description: "Show hidden files"},
		{Value: "--type", Description: "Filter by type"},
	}

	model := ui.NewModel(completions)

	if model == nil {
		t.Fatal("expected non-nil model")
	}

	if len(model.Completions) != 2 {
		t.Errorf("expected 2 completions, got %d", len(model.Completions))
	}

	if model.SelectedIndex != 0 {
		t.Errorf("expected SelectedIndex=0, got %d", model.SelectedIndex)
	}
}

func TestModel_TogglePosition(t *testing.T) {
	t.Parallel()

	model := ui.NewModel([]types.Candidate{})

	initialPos := model.Position

	model.TogglePosition()

	if model.Position == initialPos {
		t.Error("expected position to change")
	}

	model.TogglePosition()

	if model.Position != initialPos {
		t.Error("expected position to toggle back")
	}
}

func TestModel_NextItem(t *testing.T) {
	t.Parallel()

	completions := []types.Candidate{
		{Value: "a"},
		{Value: "b"},
		{Value: "c"},
	}

	model := ui.NewModel(completions)

	if model.SelectedIndex != 0 {
		t.Fatalf("expected initial index 0, got %d", model.SelectedIndex)
	}

	model.NextItem()
	if model.SelectedIndex != 1 {
		t.Errorf("expected index 1, got %d", model.SelectedIndex)
	}

	model.NextItem()
	if model.SelectedIndex != 2 {
		t.Errorf("expected index 2, got %d", model.SelectedIndex)
	}

	// Should wrap around
	model.NextItem()
	if model.SelectedIndex != 0 {
		t.Errorf("expected index to wrap to 0, got %d", model.SelectedIndex)
	}
}

func TestModel_PrevItem(t *testing.T) {
	t.Parallel()

	completions := []types.Candidate{
		{Value: "a"},
		{Value: "b"},
		{Value: "c"},
	}

	model := ui.NewModel(completions)

	// Should wrap to end
	model.PrevItem()
	if model.SelectedIndex != 2 {
		t.Errorf("expected index to wrap to 2, got %d", model.SelectedIndex)
	}

	model.PrevItem()
	if model.SelectedIndex != 1 {
		t.Errorf("expected index 1, got %d", model.SelectedIndex)
	}

	model.PrevItem()
	if model.SelectedIndex != 0 {
		t.Errorf("expected index 0, got %d", model.SelectedIndex)
	}
}

func TestModel_SelectedCompletion(t *testing.T) {
	t.Parallel()

	completions := []types.Candidate{
		{Value: "a"},
		{Value: "b"},
	}

	model := ui.NewModel(completions)

	selected := model.SelectedCompletion()
	if selected == nil {
		t.Fatal("expected non-nil selected completion")
	}

	if selected.Value != "a" {
		t.Errorf("expected 'a', got '%s'", selected.Value)
	}

	model.NextItem()
	selected = model.SelectedCompletion()
	if selected.Value != "b" {
		t.Errorf("expected 'b', got '%s'", selected.Value)
	}
}

func TestModel_SelectedCompletion_Empty(t *testing.T) {
	t.Parallel()

	model := ui.NewModel([]types.Candidate{})

	selected := model.SelectedCompletion()
	if selected != nil {
		t.Error("expected nil for empty completions")
	}
}

func TestModel_DetermineDetailPosition(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name               string
		width              int
		showDetail         bool
		expectedDetailPos  ui.DetailPosition
	}{
		{
			name:              "hidden when not showing detail",
			width:             100,
			showDetail:        false,
			expectedDetailPos: ui.DetailHidden,
		},
		{
			name:              "right when enough space",
			width:             100,
			showDetail:        true,
			expectedDetailPos: ui.DetailRight,
		},
		{
			name:              "left with medium space",
			width:             75,
			showDetail:        true,
			expectedDetailPos: ui.DetailLeft,
		},
		{
			name:              "hidden with small space",
			width:             50,
			showDetail:        true,
			expectedDetailPos: ui.DetailHidden,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			model := ui.NewModel([]types.Candidate{{Value: "test"}})
			model.Width = tc.width
			model.ShowDetail = tc.showDetail

			model.DetermineDetailPosition()

			if model.DetailPosition != tc.expectedDetailPos {
				t.Errorf("expected %v, got %v", tc.expectedDetailPos, model.DetailPosition)
			}
		})
	}
}
