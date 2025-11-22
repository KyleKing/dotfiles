package protocol

import "github.com/KyleKing/dotfiles/completion-server/pkg/types"

// Request is the JSON protocol for daemon communication
type Request struct {
	CommandLine string `json:"command"`
	CursorPos   int    `json:"cursor"`
	MaxResults  int    `json:"max"`
}

// Response is the JSON response from the daemon
type Response struct {
	Completions []types.Candidate `json:"completions"`
	Error       string            `json:"error,omitempty"`
}

// Validate checks if the request is valid
func (r *Request) Validate() error {
	if r.MaxResults <= 0 {
		r.MaxResults = 5 // Default
	}
	if r.CursorPos < 0 {
		r.CursorPos = len(r.CommandLine)
	}
	return nil
}
