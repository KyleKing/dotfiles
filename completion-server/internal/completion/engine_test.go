package completion_test

import (
	"testing"

	"github.com/KyleKing/dotfiles/completion-server/internal/completion"
)

func TestEngineCreation(t *testing.T) {
	t.Parallel()

	engine, err := completion.New()
	if err != nil {
		t.Fatalf("failed to create engine: %v", err)
	}

	if engine == nil {
		t.Fatal("expected engine to be non-nil")
	}
}

func TestEngineQuery(t *testing.T) {
	t.Parallel()

	engine, err := completion.New()
	if err != nil {
		t.Fatalf("failed to create engine: %v", err)
	}

	// Query with empty command - should return no error but empty results
	results, err := engine.Query("", 0, 5)
	if err != nil {
		t.Errorf("expected no error for empty query, got: %v", err)
	}

	if results == nil {
		t.Error("expected non-nil results")
	}
}

func TestEngineQueryWithCommand(t *testing.T) {
	t.Parallel()

	engine, err := completion.New()
	if err != nil {
		t.Fatalf("failed to create engine: %v", err)
	}

	// Query with a command
	results, err := engine.Query("fd ", 3, 5)
	if err != nil {
		t.Errorf("expected no error, got: %v", err)
	}

	// Should return empty results since no sources are configured yet
	if len(results) > 0 {
		t.Logf("got %d results (sources may be configured)", len(results))
	}
}
