package ui_test

import (
	"strings"
	"testing"

	"github.com/Dicklesworthstone/beads_viewer/pkg/analysis"
	"github.com/Dicklesworthstone/beads_viewer/pkg/ui"
)

// =============================================================================
// FlowMatrixView Tests (Legacy Summary Function)
// =============================================================================
// Note: The primary UI is now FlowMatrixModel (interactive). FlowMatrixView
// is kept for backward compatibility and returns a simple summary.

func TestFlowMatrixViewEmptyLabels(t *testing.T) {
	flow := analysis.CrossLabelFlow{
		Labels:     []string{},
		FlowMatrix: [][]int{},
	}

	result := ui.FlowMatrixView(flow, 80)
	expected := "No cross-label dependencies found"
	if result != expected {
		t.Errorf("FlowMatrixView() = %q, want %q", result, expected)
	}
}

func TestFlowMatrixViewNilLabels(t *testing.T) {
	flow := analysis.CrossLabelFlow{
		Labels:     nil,
		FlowMatrix: nil,
	}

	result := ui.FlowMatrixView(flow, 80)
	expected := "No cross-label dependencies found"
	if result != expected {
		t.Errorf("FlowMatrixView() with nil labels = %q, want %q", result, expected)
	}
}

func TestFlowMatrixViewSingleLabel(t *testing.T) {
	flow := analysis.CrossLabelFlow{
		Labels:     []string{"bug"},
		FlowMatrix: [][]int{{0}},
	}

	result := ui.FlowMatrixView(flow, 80)

	// Should contain header
	if !strings.Contains(result, "DEPENDENCY FLOW SUMMARY") {
		t.Errorf("FlowMatrixView() should contain header, got: %q", result)
	}

	// Should contain labels count
	if !strings.Contains(result, "Labels: 1") {
		t.Errorf("FlowMatrixView() should contain 'Labels: 1', got: %q", result)
	}
}

func TestFlowMatrixViewMultipleLabels(t *testing.T) {
	flow := analysis.CrossLabelFlow{
		Labels: []string{"bug", "feat", "docs"},
		FlowMatrix: [][]int{
			{0, 2, 1}, // bug blocks feat 2 times, docs 1 time
			{1, 0, 3}, // feat blocks bug 1 time, docs 3 times
			{0, 0, 0}, // docs blocks nothing
		},
		TotalCrossLabelDeps: 7,
	}

	result := ui.FlowMatrixView(flow, 80)

	// Should contain header
	if !strings.Contains(result, "DEPENDENCY FLOW SUMMARY") {
		t.Errorf("FlowMatrixView() should contain header, got: %q", result)
	}

	// Should contain labels count
	if !strings.Contains(result, "Labels: 3") {
		t.Errorf("FlowMatrixView() should contain 'Labels: 3', got: %q", result)
	}

	// Should contain cross-label deps count
	if !strings.Contains(result, "Cross-label dependencies: 7") {
		t.Errorf("FlowMatrixView() should contain 'Cross-label dependencies: 7', got: %q", result)
	}
}

func TestFlowMatrixViewWithBottlenecks(t *testing.T) {
	flow := analysis.CrossLabelFlow{
		Labels: []string{"api", "web"},
		FlowMatrix: [][]int{
			{0, 5},
			{2, 0},
		},
		BottleneckLabels:    []string{"api"},
		TotalCrossLabelDeps: 7,
	}

	result := ui.FlowMatrixView(flow, 80)

	// Should contain bottleneck info
	if !strings.Contains(result, "Bottleneck labels: [api]") {
		t.Errorf("FlowMatrixView() should contain bottleneck labels, got: %q", result)
	}
}

func TestFlowMatrixViewNotEmpty(t *testing.T) {
	flow := analysis.CrossLabelFlow{
		Labels: []string{"a", "b"},
		FlowMatrix: [][]int{
			{0, 1},
			{0, 0},
		},
	}

	result := ui.FlowMatrixView(flow, 80)

	if result == "" {
		t.Error("FlowMatrixView() should not return empty string for valid input")
	}

	if len(result) < 20 {
		t.Errorf("FlowMatrixView() output seems too short: %q", result)
	}
}

func TestFlowMatrixViewZeroWidth(t *testing.T) {
	flow := analysis.CrossLabelFlow{
		Labels:     []string{"test"},
		FlowMatrix: [][]int{{0}},
	}

	result := ui.FlowMatrixView(flow, 0)
	if result == "" {
		t.Error("FlowMatrixView(width=0) should not return empty string")
	}
}

func TestFlowMatrixViewNegativeWidth(t *testing.T) {
	flow := analysis.CrossLabelFlow{
		Labels:     []string{"test"},
		FlowMatrix: [][]int{{0}},
	}

	result := ui.FlowMatrixView(flow, -10)
	if result == "" {
		t.Error("FlowMatrixView(width=-10) should not return empty string")
	}
}

func TestFlowMatrixViewLargeMatrix(t *testing.T) {
	labels := []string{"api", "web", "db", "auth", "core"}
	n := len(labels)
	matrix := make([][]int, n)
	for i := range matrix {
		matrix[i] = make([]int, n)
		for j := range matrix[i] {
			if i != j {
				matrix[i][j] = i + j
			}
		}
	}

	flow := analysis.CrossLabelFlow{
		Labels:     labels,
		FlowMatrix: matrix,
	}

	result := ui.FlowMatrixView(flow, 120)

	// Should contain labels count
	if !strings.Contains(result, "Labels: 5") {
		t.Errorf("FlowMatrixView() should contain 'Labels: 5', got: %q", result)
	}
}

func TestFlowMatrixViewOutput(t *testing.T) {
	flow := analysis.CrossLabelFlow{
		Labels:              []string{"bug", "feat"},
		FlowMatrix:          [][]int{{0, 1}, {2, 0}},
		TotalCrossLabelDeps: 3,
		BottleneckLabels:    []string{},
	}

	result := ui.FlowMatrixView(flow, 80)

	// Verify structure
	lines := strings.Split(result, "\n")
	if len(lines) < 4 {
		t.Errorf("FlowMatrixView() should produce at least 4 lines, got %d", len(lines))
	}

	// First line should be header
	if !strings.Contains(lines[0], "DEPENDENCY FLOW SUMMARY") {
		t.Errorf("First line should be header, got: %q", lines[0])
	}
}

// =============================================================================
// Benchmarks
// =============================================================================

func BenchmarkFlowMatrixViewSmall(b *testing.B) {
	flow := analysis.CrossLabelFlow{
		Labels:     []string{"a", "b", "c"},
		FlowMatrix: [][]int{{0, 1, 2}, {0, 0, 1}, {1, 0, 0}},
	}
	for i := 0; i < b.N; i++ {
		_ = ui.FlowMatrixView(flow, 80)
	}
}

func BenchmarkFlowMatrixViewMedium(b *testing.B) {
	n := 10
	labels := make([]string, n)
	matrix := make([][]int, n)
	for i := 0; i < n; i++ {
		labels[i] = string(rune('a' + i))
		matrix[i] = make([]int, n)
		for j := 0; j < n; j++ {
			if i != j {
				matrix[i][j] = (i + j) % 5
			}
		}
	}
	flow := analysis.CrossLabelFlow{
		Labels:     labels,
		FlowMatrix: matrix,
	}
	for i := 0; i < b.N; i++ {
		_ = ui.FlowMatrixView(flow, 120)
	}
}

func BenchmarkFlowMatrixViewLarge(b *testing.B) {
	n := 20
	labels := make([]string, n)
	matrix := make([][]int, n)
	for i := 0; i < n; i++ {
		labels[i] = string(rune('a'+i%26)) + string(rune('0'+i/26))
		matrix[i] = make([]int, n)
		for j := 0; j < n; j++ {
			if i != j {
				matrix[i][j] = (i * j) % 10
			}
		}
	}
	flow := analysis.CrossLabelFlow{
		Labels:     labels,
		FlowMatrix: matrix,
	}
	for i := 0; i < b.N; i++ {
		_ = ui.FlowMatrixView(flow, 200)
	}
}
