package protocol_test

import (
	"testing"

	"github.com/KyleKing/dotfiles/completion-server/pkg/protocol"
)

func TestRequest_Validate(t *testing.T) {
	t.Parallel()

	testCases := []struct {
		name           string
		request        protocol.Request
		expectedMax    int
		expectedCursor int
	}{
		{
			name: "sets default max results",
			request: protocol.Request{
				CommandLine: "fd ",
				CursorPos:   3,
				MaxResults:  0,
			},
			expectedMax:    5,
			expectedCursor: 3,
		},
		{
			name: "sets cursor to end if negative",
			request: protocol.Request{
				CommandLine: "fd ",
				CursorPos:   -1,
				MaxResults:  10,
			},
			expectedMax:    10,
			expectedCursor: 3,
		},
		{
			name: "preserves valid values",
			request: protocol.Request{
				CommandLine: "git checkout ",
				CursorPos:   5,
				MaxResults:  20,
			},
			expectedMax:    20,
			expectedCursor: 5,
		},
	}

	for _, tc := range testCases {
		t.Run(tc.name, func(t *testing.T) {
			t.Parallel()

			err := tc.request.Validate()
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}

			if tc.request.MaxResults != tc.expectedMax {
				t.Errorf("expected MaxResults=%d, got %d", tc.expectedMax, tc.request.MaxResults)
			}

			if tc.request.CursorPos != tc.expectedCursor {
				t.Errorf("expected CursorPos=%d, got %d", tc.expectedCursor, tc.request.CursorPos)
			}
		})
	}
}
