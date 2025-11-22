package types_test

import (
	"testing"

	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

func TestCandidate(t *testing.T) {
	t.Parallel()

	candidate := types.Candidate{
		Value:       "--hidden",
		Display:     "-H, --hidden",
		Description: "Search hidden files",
		Score:       100.0,
		Source:      "carapace",
	}

	if candidate.Value != "--hidden" {
		t.Errorf("expected Value to be '--hidden', got %q", candidate.Value)
	}

	if candidate.Score != 100.0 {
		t.Errorf("expected Score to be 100.0, got %f", candidate.Score)
	}
}

func TestCommandSpec(t *testing.T) {
	t.Parallel()

	spec := types.CommandSpec{
		Name: "fd",
		Flags: []types.FlagSpec{
			{
				Long:        "--hidden",
				Short:       "-H",
				Description: "Search hidden files",
			},
		},
		Source: "carapace",
	}

	if spec.Name != "fd" {
		t.Errorf("expected Name to be 'fd', got %q", spec.Name)
	}

	if len(spec.Flags) != 1 {
		t.Errorf("expected 1 flag, got %d", len(spec.Flags))
	}
}
