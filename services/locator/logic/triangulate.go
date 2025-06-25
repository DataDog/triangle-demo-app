package logic

import (
	"errors"
	"fmt"
	"locator/models"
	"math"
	"sort"

	"gonum.org/v1/gonum/optimize"
)

const speedOfSound = 343.0 // m/s

func TriangulateFromBundle(bundle models.SignalBundle) models.Detection {
	var detections []models.Detection
	for _, t := range bundle.Towers {
		detections = append(detections, models.Detection{
			X:         float64(t.X),
			Y:         float64(t.Y),
			Timestamp: t.HeardAt,
		})
	}

	return Triangulate(bundle.Towers, detections)
}

func Triangulate(towers []models.TowerDetection, detections []models.Detection) models.Detection {
	if len(towers) != 3 || len(detections) != 3 {
		fmt.Printf("[triangulation] Need exactly 3 towers and detections, got %d and %d\n",
			len(towers), len(detections))
		return fallbackDetection()
	}

	// Create a slice of tower-detection pairs for sorting
	type towerPair struct {
		tower     models.TowerDetection
		detection models.Detection
	}
	pairs := make([]towerPair, 3)
	for i := range towers {
		pairs[i] = towerPair{
			tower:     towers[i],
			detection: detections[i],
		}
	}

	// Sort pairs by detection timestamp to ensure T1 is earliest
	sort.Slice(pairs, func(i, j int) bool {
		return pairs[i].detection.Timestamp < pairs[j].detection.Timestamp
	})

	// Calculate time differences relative to earliest detection (T1)
	dt2 := (pairs[1].detection.Timestamp - pairs[0].detection.Timestamp) / 1000.0 // ms to s
	dt3 := (pairs[2].detection.Timestamp - pairs[0].detection.Timestamp) / 1000.0

	// Convert time differences to distance differences using speed of sound
	// Positive d12 means signal reached T2 after T1
	d12 := dt2 * speedOfSound
	d13 := dt3 * speedOfSound

	fmt.Printf("[triangulation] Tower order: T1(%.0f,%.0f) T2(%.0f,%.0f) T3(%.0f,%.0f)\n",
		pairs[0].tower.X, pairs[0].tower.Y,
		pairs[1].tower.X, pairs[1].tower.Y,
		pairs[2].tower.X, pairs[2].tower.Y)
	fmt.Printf("[triangulation] Timestamps: t1=%.3f t2=%.3f t3=%.3f\n",
		float64(pairs[0].detection.Timestamp)/1000.0,
		float64(pairs[1].detection.Timestamp)/1000.0,
		float64(pairs[2].detection.Timestamp)/1000.0)
	fmt.Printf("[triangulation] Time differences: Δt2=%.4fs Δt3=%.4fs\n", dt2, dt3)
	fmt.Printf("[triangulation] Distance differences: d12=%.2fm d13=%.2fm\n", d12, d13)

	// Try nonlinear solver first
	x, y, err := solveTDOANonlinear(
		float64(pairs[0].tower.X), float64(pairs[0].tower.Y), // T1 (earliest)
		float64(pairs[1].tower.X), float64(pairs[1].tower.Y), // T2 (second)
		float64(pairs[2].tower.X), float64(pairs[2].tower.Y), // T3 (third)
		d12, d13,
	)

	if err != nil {
		fmt.Printf("[triangulation] Nonlinear solver failed: %v\n", err)
		// Fall back to linear solver with same tower ordering
		x, y, err = solveTDOAFromDeltas(
			float64(pairs[0].tower.X), float64(pairs[0].tower.Y), // T1 (earliest)
			float64(pairs[1].tower.X), float64(pairs[1].tower.Y), // T2 (second)
			float64(pairs[2].tower.X), float64(pairs[2].tower.Y), // T3 (third)
			d12, d13,
		)
		if err != nil {
			fmt.Printf("[triangulation] Linear solver also failed: %v\n", err)
			return fallbackDetection()
		}
	}

	return models.Detection{
		X:         x,
		Y:         y,
		Timestamp: pairs[0].detection.Timestamp, // Use earliest timestamp
	}
}

func fallbackDetection() models.Detection {
	return models.Detection{X: -1, Y: -1, Timestamp: -1}
}

// tdoaProblem holds the parameters for the TDoA optimization
type tdoaProblem struct {
	x1, y1, x2, y2, x3, y3 float64 // Tower coordinates
	d12, d13               float64 // Signed TDoA distances
}

// solveTDOAFromDeltas solves the TDoA problem using a linear approximation
func solveTDOAFromDeltas(
	x1, y1, x2, y2, x3, y3 float64,
	d12, d13 float64,
) (float64, float64, error) {
	// Translate coordinates so tower A is at origin
	x2p := x2 - x1
	y2p := y2 - y1
	x3p := x3 - x1
	y3p := y3 - y1

	fmt.Printf("[solver] rel B=(%.2f, %.2f)  rel C=(%.2f, %.2f)\n", x2p, y2p, x3p, y3p)

	// Calculate distances between towers
	dAB := math.Hypot(x2p, y2p)
	dAC := math.Hypot(x3p, y3p)
	fmt.Printf("[solver] tower distances: AB=%.2fm  AC=%.2fm\n", dAB, dAC)
	fmt.Printf("[solver] comparing TDoA-derived distances: |d12|=%.2fm  |d13|=%.2fm\n", math.Abs(d12), math.Abs(d13))

	// Validate TDoA distances are reasonable compared to tower distances
	if math.Abs(d12) > dAB || math.Abs(d13) > dAC {
		fmt.Printf("[solver] TDoA distances exceed physical separation:\n")
		if math.Abs(d12) > dAB {
			fmt.Printf("         - |d12| (%.2fm) > AB (%.2fm)\n", math.Abs(d12), dAB)
		}
		if math.Abs(d13) > dAC {
			fmt.Printf("         - |d13| (%.2fm) > AC (%.2fm)\n", math.Abs(d13), dAC)
		}
		return 0, 0, errors.New("TDoA distances exceed tower distances")
	}

	// Scale the system to improve numerical stability
	scale := math.Max(dAB, dAC)
	x2p /= scale
	y2p /= scale
	x3p /= scale
	y3p /= scale
	d12 /= scale
	d13 /= scale

	// Coefficients of linear system
	A := 2 * x2p
	B := 2 * y2p
	C := 2 * x3p
	D := 2 * y3p

	// Use squared TDoA distances (d12 and d13 are already signed deltas)
	E := x2p*x2p + y2p*y2p - d12*d12
	F := x3p*x3p + y3p*y3p - d13*d13

	denom := A*D - B*C
	fmt.Printf("[solver] determinant = %.4f\n", denom)
	if math.Abs(denom) < 1e-6 {
		fmt.Printf("[solver] determinant too small: %.8f — towers may be collinear\n", denom)
		return 0, 0, errors.New("no unique solution — towers may be collinear")
	}

	// Solve the linear system for x and y
	y := (E*C - A*F) / denom
	x := (E - B*y) / A

	// Scale back to world coordinates
	x *= scale
	y *= scale
	x += x1
	y += y1

	// Clamp solution to valid range before validation
	x = math.Max(100, math.Min(x, 900))
	y = math.Max(100, math.Min(y, 900))

	// Calculate residual with clamped coordinates
	residual := calculateResiduals(x, y, x1, y1, x2, y2, x3, y3, d12*scale, d13*scale)
	fmt.Printf("[solver] linear solution (x,y)=(%.2f, %.2f) residual=%.6f\n", x, y, residual)

	return x, y, nil
}

// residualThresholdConverger implements a custom convergence criterion based on residual threshold
type residualThresholdConverger struct {
	threshold float64
}

// Init implements the optimize.Converger interface
func (r residualThresholdConverger) Init(dim int) {
	// No initialization needed for this converger
}

func (r residualThresholdConverger) Converged(loc *optimize.Location) optimize.Status {
	if loc.F < r.threshold {
		return optimize.Success
	}
	return optimize.NotTerminated
}

// solveTDOANonlinear solves the TDoA problem using nonlinear optimization
func solveTDOANonlinear(
	x1, y1, x2, y2, x3, y3 float64,
	d12, d13 float64,
) (float64, float64, error) {
	// Validate TDoA distances against physical constraints
	d12_abs := math.Abs(d12)
	d13_abs := math.Abs(d13)

	// Calculate tower distances
	dAB := math.Hypot(x2-x1, y2-y1)
	dAC := math.Hypot(x3-x1, y3-y1)
	dBC := math.Hypot(x3-x2, y3-y2)

	// Check if TDoA distances are physically possible
	if d12_abs > dAB || d13_abs > dAC {
		return 0, 0, fmt.Errorf("TDoA distances exceed physical tower separation: d12=%.2f > %.2f or d13=%.2f > %.2f",
			d12_abs, dAB, d13_abs, dAC)
	}

	// Create optimization problem working directly in real coordinates
	problem := optimize.Problem{
		Func: func(x []float64) float64 {
			// Get current test position
			px, py := x[0], x[1]

			// Calculate distances from source to each tower
			d1 := math.Hypot(px-x1, py-y1)
			d2 := math.Hypot(px-x2, py-y2)
			d3 := math.Hypot(px-x3, py-y3)

			// Calculate residuals (signed distance differences)
			r1 := (d2 - d1) - d12
			r2 := (d3 - d1) - d13

			// Add soft boundary penalty with wider margins
			const margin = 20.0 // Increased margin
			const bound_min = 100.0
			const bound_max = 900.0
			boundary_penalty := 0.0

			if px < bound_min+margin {
				boundary_penalty += math.Pow(bound_min+margin-px, 2)
			}
			if px > bound_max-margin {
				boundary_penalty += math.Pow(px-(bound_max-margin), 2)
			}
			if py < bound_min+margin {
				boundary_penalty += math.Pow(bound_min+margin-py, 2)
			}
			if py > bound_max-margin {
				boundary_penalty += math.Pow(py-(bound_max-margin), 2)
			}

			// Scale residuals by average tower distance for better conditioning
			scale := (dAB + dAC + dBC) / 3.0
			r1 /= scale
			r2 /= scale
			boundary_penalty /= (scale * scale)

			// Add very small regularization term to prefer solutions near center
			// This helps prevent solutions at infinity while being negligible for valid solutions
			center_x := (x1 + x2 + x3) / 3
			center_y := (y1 + y2 + y3) / 3
			regularization := 1e-8 * (math.Pow(px-center_x, 2) + math.Pow(py-center_y, 2)) / (scale * scale)

			// Return weighted sum of squared residuals, boundary penalty, and regularization
			return r1*r1 + r2*r2 + 0.05*boundary_penalty + regularization
		},
		Grad: func(grad, x []float64) {
			// Get current test position
			px, py := x[0], x[1]

			// Calculate distances from source to each tower
			d1 := math.Hypot(px-x1, py-y1)
			d2 := math.Hypot(px-x2, py-y2)
			d3 := math.Hypot(px-x3, py-y3)

			// Scale factor for better conditioning
			scale := (dAB + dAC + dBC) / 3.0

			// Calculate residuals
			r1 := ((d2 - d1) - d12) / scale
			r2 := ((d3 - d1) - d13) / scale

			// Partial derivatives
			dr1dx := ((px-x2)/d2 - (px-x1)/d1) / scale
			dr1dy := ((py-y2)/d2 - (py-y1)/d1) / scale
			dr2dx := ((px-x3)/d3 - (px-x1)/d1) / scale
			dr2dy := ((py-y3)/d3 - (py-y1)/d1) / scale

			// Add boundary penalty gradients
			const margin = 20.0 // Increased margin
			const bound_min = 100.0
			const bound_max = 900.0

			if px < bound_min+margin {
				grad[0] += -0.1 * (bound_min + margin - px) / (scale * scale)
			}
			if px > bound_max-margin {
				grad[0] += 0.1 * (px - (bound_max - margin)) / (scale * scale)
			}
			if py < bound_min+margin {
				grad[1] += -0.1 * (bound_min + margin - py) / (scale * scale)
			}
			if py > bound_max-margin {
				grad[1] += 0.1 * (py - (bound_max - margin)) / (scale * scale)
			}

			// Add regularization gradient
			center_x := (x1 + x2 + x3) / 3
			center_y := (y1 + y2 + y3) / 3
			grad[0] += 2e-8 * (px - center_x) / (scale * scale)
			grad[1] += 2e-8 * (py - center_y) / (scale * scale)

			grad[0] += 2*r1*dr1dx + 2*r2*dr2dx
			grad[1] += 2*r1*dr1dy + 2*r2*dr2dy
		},
	}

	// Try linear solver first to get initial guess
	x0, y0, err := solveTDOAFromDeltas(x1, y1, x2, y2, x3, y3, d12, d13)
	if err != nil {
		// If linear solver fails, use center of valid range
		x0, y0 = 500, 500
	}

	// More practical convergence settings
	settings := &optimize.Settings{
		FuncEvaluations:   0, // No limit on function evaluations
		GradientThreshold: 1e-6,
		Recorder:          nil,
		Converger: residualThresholdConverger{
			threshold: 1e-8, // Very small threshold since we're using scaled residuals
		},
	}

	// Try multiple starting points to avoid local minima
	type solution struct {
		x, y     float64
		residual float64
		method   string
	}
	var solutions []solution

	// Generate better initial guesses based on geometry
	candidates := []struct{ x, y float64 }{
		{x0, y0},                                 // Linear solution
		{500, 500},                               // Center
		{(x1 + x2 + x3) / 3, (y1 + y2 + y3) / 3}, // Centroid
		// Add points along the TDoA hyperbolas
		{x1 + d12*0.5*(x2-x1)/dAB, y1 + d12*0.5*(y2-y1)/dAB},             // Point along T1-T2
		{x1 + d13*0.5*(x3-x1)/dAC, y1 + d13*0.5*(y3-y1)/dAC},             // Point along T1-T3
		{x2 + (d13-d12)*0.5*(x3-x2)/dBC, y2 + (d13-d12)*0.5*(y3-y2)/dBC}, // Point along T2-T3
	}

	fmt.Printf("[solver] trying %d initial points with direct coordinate optimization\n", len(candidates))
	for _, c := range candidates {
		initial := []float64{c.x, c.y}

		// First try Nelder-Mead for broad search
		nmResult, err := optimize.Minimize(problem, initial, settings, &optimize.NelderMead{
			SimplexSize: 100.0, // Larger initial simplex for broader search
		})

		if err == nil && nmResult.Status == optimize.Success {
			x, y := nmResult.X[0], nmResult.X[1]
			if validateSolution(x, y) == nil {
				solutions = append(solutions, solution{
					x: x, y: y,
					residual: nmResult.F,
					method:   "nelder-mead",
				})

				// Use Nelder-Mead result as starting point for BFGS
				bfgsResult, err := optimize.Minimize(problem, nmResult.X, settings, &optimize.BFGS{})
				if err == nil && bfgsResult.Status == optimize.Success {
					x, y := bfgsResult.X[0], bfgsResult.X[1]
					if validateSolution(x, y) == nil {
						solutions = append(solutions, solution{
							x: x, y: y,
							residual: bfgsResult.F,
							method:   "bfgs",
						})
					}
				}
			}
		}
	}

	if len(solutions) == 0 {
		return 0, 0, fmt.Errorf("no solutions converged with acceptable residual")
	}

	// Find solution with lowest residual
	best := solutions[0]
	for _, s := range solutions[1:] {
		if s.residual < best.residual {
			best = s
		}
	}

	fmt.Printf("[solver] best solution: (x,y)=(%.1f, %.1f) residual=%.8f method=%s\n",
		best.x, best.y, best.residual, best.method)

	return best.x, best.y, nil
}

// validateSolution checks if a solution is within valid bounds
func validateSolution(x, y float64) error {
	if x < 50 || x > 950 || y < 50 || y > 950 {
		return fmt.Errorf("solution outside valid range: (%.2f, %.2f)", x, y)
	}

	// Add additional validation checks
	if math.IsNaN(x) || math.IsNaN(y) || math.IsInf(x, 0) || math.IsInf(y, 0) {
		return fmt.Errorf("invalid solution coordinates: (%.2f, %.2f)", x, y)
	}

	return nil
}

// calculateResiduals computes the squared residuals for a given solution
func calculateResiduals(x, y, x1, y1, x2, y2, x3, y3, d12, d13 float64) float64 {
	// Calculate distances from source to each tower
	d1 := math.Sqrt(math.Pow(x-x1, 2) + math.Pow(y-y1, 2))
	d2 := math.Sqrt(math.Pow(x-x2, 2) + math.Pow(y-y2, 2))
	d3 := math.Sqrt(math.Pow(x-x3, 2) + math.Pow(y-y3, 2))

	// Calculate residuals (signed distance differences)
	r1 := (d2 - d1) - d12
	r2 := (d3 - d1) - d13

	// Add very soft penalty for solutions extremely close to towers
	const minTowerDist = 2.0   // reduced from 10.0
	const penaltyWeight = 0.01 // reduced from 0.1
	towerPenalty := 0.0

	// Use smoother quadratic dropoff
	if d1 < minTowerDist {
		factor := (minTowerDist - d1) / minTowerDist
		towerPenalty += factor * factor
	}
	if d2 < minTowerDist {
		factor := (minTowerDist - d2) / minTowerDist
		towerPenalty += factor * factor
	}
	if d3 < minTowerDist {
		factor := (minTowerDist - d3) / minTowerDist
		towerPenalty += factor * factor
	}

	// Return weighted sum of squared residuals and reduced penalty
	return r1*r1 + r2*r2 + penaltyWeight*towerPenalty
}
