package fuzzy

import (
	"strings"
	"unicode"

	"github.com/KyleKing/dotfiles/completion-server/pkg/types"
)

// Matcher performs fuzzy matching on completion candidates
type Matcher struct {
	caseSensitive bool
}

// Option configures the Matcher
type Option func(*Matcher)

// WithCaseSensitive enables case-sensitive matching
func WithCaseSensitive(enabled bool) Option {
	return func(m *Matcher) {
		m.caseSensitive = enabled
	}
}

// New creates a new fuzzy matcher
func New(opts ...Option) *Matcher {
	m := &Matcher{
		caseSensitive: false, // Default: case-insensitive
	}

	for _, opt := range opts {
		opt(m)
	}

	return m
}

// Match returns true if query fuzzy matches the candidate value
func (m *Matcher) Match(query, candidate string) bool {
	if query == "" {
		return true // Empty query matches everything
	}

	if !m.caseSensitive {
		query = strings.ToLower(query)
		candidate = strings.ToLower(candidate)
	}

	queryRunes := []rune(query)
	candidateRunes := []rune(candidate)

	qi := 0 // Query index
	for ci := 0; ci < len(candidateRunes) && qi < len(queryRunes); ci++ {
		if candidateRunes[ci] == queryRunes[qi] {
			qi++
		}
	}

	return qi == len(queryRunes) // All query characters found
}

// Score calculates a fuzzy match score (0.0 to 100.0)
// Higher scores indicate better matches
func (m *Matcher) Score(query, candidate string) float64 {
	if query == "" {
		return 0.0 // No bonus for empty query
	}

	originalCandidate := candidate
	if !m.caseSensitive {
		query = strings.ToLower(query)
		candidate = strings.ToLower(candidate)
	}

	queryRunes := []rune(query)
	candidateRunes := []rune(candidate)

	if len(queryRunes) == 0 {
		return 0.0
	}

	var score float64
	qi := 0          // Query index
	consecutive := 0 // Consecutive match count
	lastMatchPos := -1

	for ci := 0; ci < len(candidateRunes) && qi < len(queryRunes); ci++ {
		if candidateRunes[ci] == queryRunes[qi] {
			// Base score for match
			matchScore := 10.0

			// Bonus for consecutive matches
			if lastMatchPos == ci-1 {
				consecutive++
				matchScore += float64(consecutive) * 5.0
			} else {
				consecutive = 0
			}

			// Bonus for early matches (higher score for matches near the start)
			earlyBonus := float64(len(candidateRunes)-ci) / float64(len(candidateRunes)) * 5.0
			matchScore += earlyBonus

			// Bonus for matching after separator (-, _, space)
			if ci > 0 && isSeparator(candidateRunes[ci-1]) {
				matchScore += 10.0
			}

			// Bonus for matching uppercase in camelCase
			if unicode.IsUpper([]rune(originalCandidate)[ci]) {
				matchScore += 5.0
			}

			score += matchScore
			lastMatchPos = ci
			qi++
		}
	}

	// Penalty for not matching all characters
	if qi < len(queryRunes) {
		return 0.0 // Doesn't match
	}

	// Normalize score (higher is better, max 100)
	normalizedScore := score / float64(len(queryRunes))
	if normalizedScore > 100.0 {
		normalizedScore = 100.0
	}

	return normalizedScore
}

// Filter filters and scores candidates based on fuzzy matching
func (m *Matcher) Filter(query string, candidates []types.Candidate) []types.Candidate {
	if query == "" {
		// For empty query, add metadata but don't filter
		result := make([]types.Candidate, len(candidates))
		for i, candidate := range candidates {
			if candidate.Metadata == nil {
				candidate.Metadata = make(map[string]interface{})
			}
			candidate.Metadata["fuzzy_score"] = 0.0
			result[i] = candidate
		}
		return result
	}

	var filtered []types.Candidate
	for _, candidate := range candidates {
		if m.Match(query, candidate.Value) {
			// Add fuzzy score to existing score
			fuzzyScore := m.Score(query, candidate.Value)
			candidate.Score += fuzzyScore

			// Store original fuzzy score in metadata
			if candidate.Metadata == nil {
				candidate.Metadata = make(map[string]interface{})
			}
			candidate.Metadata["fuzzy_score"] = fuzzyScore

			filtered = append(filtered, candidate)
		}
	}

	return filtered
}

// isSeparator returns true if the rune is a word separator
func isSeparator(r rune) bool {
	return r == '-' || r == '_' || r == ' ' || r == '.'
}
