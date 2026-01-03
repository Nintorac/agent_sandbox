package analysis

import (
	"testing"

	"gonum.org/v1/gonum/graph/simple"
)

// Ensures articulation detection works with node ID 0 (no-parent sentinel safety).
func TestFindArticulationPointsHandlesZeroID(t *testing.T) {
	g := simple.NewUndirectedGraph()
	// Explicit IDs: 0-1-2 chain; 1 should be articulation.
	n0 := simple.Node(0)
	n1 := simple.Node(1)
	n2 := simple.Node(2)
	g.AddNode(n0)
	g.AddNode(n1)
	g.AddNode(n2)
	g.SetEdge(g.NewEdge(n0, n1))
	g.SetEdge(g.NewEdge(n1, n2))

	ap := findArticulationPoints(g)
	if !ap[n1.ID()] {
		t.Fatalf("expected node 1 to be articulation, got %v", ap)
	}
	if ap[n0.ID()] || ap[n2.ID()] {
		t.Fatalf("endpoints should not be articulation: %v", ap)
	}
}
