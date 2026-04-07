# Loadsched

A command-line tool written in Zig that automates early-stage electrical distribution sizing for small industrial facilities. Given a JSON load list and a few parameters, it produces a structured sizing report covering transformer selection, main feeder cable sizing, and a motor starting screen — the same front-end steps an electrical consulting engineer performs before running a full power system study in ETAP or SKM.

***

## What It Does

Starting from a list of facility loads, `loadsched` walks through the following engineering workflow automatically:

1. **Load aggregation** — applies demand/diversity factors per load type and duty cycle to compute total demand kW and kVA
2. **Transformer sizing** — selects the next standard three-phase transformer rating above the demand (including a user-specified growth margin)
3. **Main feeder sizing** — computes full-load current, then selects the smallest cable from a built-in table that satisfies both ampacity and the 3% voltage drop limit
4. **Motor starting screen** — identifies the largest motor, computes a static motor/transformer kVA ratio and estimated voltage dip, and recommends a starting method if warranted
5. **Report generation** — writes a structured plain-text report to a file of your choosing

***

## Installation

Download the binary for your platform from the [Releases](../../releases) page.

| Platform | File |
|---|---|
| Windows x86_64 | `loadsched-x86_64-windows.exe` |
| Windows ARM64 | `loadsched-aarch64-windows.exe` |
| Linux x86_64 | `loadsched-x86_64-linux` |
| Linux ARM64 | `loadsched-aarch64-linux` |
| macOS Intel | `loadsched-x86_64-macos` |
| macOS Apple Silicon | `loadsched-aarch64-macos` |

***

## Usage

### Windows:
```
loadsched.exe <loads.json> --length <m> [options]
```
### MacOS/Linux:
```
./loadsched <loads.json> --length <m> [options]
```

### Required arguments

| Argument | Description |
|---|---|
| `<loads.json>` | Path to the facility load list JSON file |
| `--length <m>` | Main feeder length in metres |

### Options

| Flag | Default | Description |
|---|---|---|
| `--voltage <V>` | `600` | LV bus voltage, line-to-line (V) |
| `--pf <0-1>` | `0.90` | Target system power factor |
| `--growth <0-1>` | `0.20` | Future load growth margin as a fraction (0.20 = 20%) |
| `--out <file>` | `report.txt` | Output report file path |

The output directory is created automatically if it does not exist.

***

## Load List JSON Format

Each JSON file describes a facility and its electrical loads.

```json
{
  "facility_name": "Your Facility Name",
  "loads": [
    {
      "name":      "Process Motor 1",
      "kw":        75.0,
      "pf":        0.88,
      "load_type": "motor",
      "duty":      "continuous"
    },
    {
      "name":      "HVAC Unit",
      "kw":        40.0,
      "pf":        0.90,
      "load_type": "hvac",
      "duty":      "intermittent"
    }
  ]
}
```

### Field reference

| Field | Type | Description |
|---|---|---|
| `name` | string | Descriptive load name (appears in report table) |
| `kw` | number | Nameplate or design kW |
| `pf` | number | Load power factor (0–1) |
| `load_type` | string | `motor`, `lighting`, `hvac`, or `other` |
| `duty` | string | `continuous` or `intermittent` |

### Demand factors applied

Demand factors encode typical utilisation for each load category, based on industrial transformer sizing conventions:

| Load type | Continuous | Intermittent |
|---|---|---|
| `motor` | 1.00 | 0.40 |
| `lighting` | 0.90 | 0.70 |
| `hvac` | 0.80 | 0.50 |
| `other` | 0.85 | 0.50 |

***

## Example Files

Three example load lists are included in the `examples/` directory to exercise all program features:

### `examples/food_processing_plant.json`
A mixed motor/lighting/HVAC facility. Produces a clean all-PASS report — good baseline.

```bash
loadsched examples/food_processing_plant.json --length 80 --voltage 600 --pf 0.92 --growth 0.20 --out reports/food_plant.txt
```

Expected: 300 kVA transformer, 150mm² feeder cable, motor starting OK.

***

### `examples/compressor_station.json`
A heavy motor-dominated facility with a long feeder. Exercises the motor starting FLAG and voltage drop stress path.

```bash
loadsched examples/compressor_station.json --length 150 --voltage 600 --pf 0.87 --growth 0.25 --out reports/compressor.txt
```

Expected: 500 kVA transformer, motor/xfmr ratio FLAG with VFD recommendation, cable comparison table under stress.

***

### `examples/small_warehouse.json`
Lighting and HVAC only — no motors. Exercises the motor screen N/A path.

```bash
loadsched examples/small_warehouse.json --length 40 --voltage 600 --pf 0.92 --growth 0.30 --out reports/warehouse.txt
```

Expected: 45 kVA transformer, motor screen prints "No motors in load list."

***

## Engineering Scope and Limitations

`loadsched` is a **preliminary sizing tool** — it automates the front-end calculations that precede a full power system study. It is not a substitute for detailed engineering analysis.

| In scope | Out of scope |
|---|---|
| Demand aggregation with diversity factors | Short-circuit / fault current calculations |
| Standard transformer rating selection | Protection coordination |
| Main feeder ampacity and voltage drop | Harmonic analysis |
| Static motor starting screen | Dynamic motor starting study |
| Equipment schedule (BOM) generation | Arc flash study |
| Single-line diagram export (DXF) | Load flow for complex networks |

For final design, results should be validated in a power system analysis tool such as ETAP or SKM PowerTools, and reviewed by a licensed electrical engineer.

### Cable table

The feeder sizing module uses a built-in table of standard three-conductor copper XLPE cables. The voltage drop calculation uses the formula:

$$ VD\% = \frac{\sqrt{3} \cdot I \cdot L \cdot (R \cos\phi + X \sin\phi)}{V_{LL}} \times 100 $$

where $$ R $$ and $$ X $$ are the per-km resistance and reactance from the cable table, $$ L $$ is the feeder length in km, and $$ V_{LL} $$ is the line-to-line voltage.

### Transformer standard ratings

The tool selects from the following standard three-phase ratings (kVA):

`15, 30, 45, 75, 112.5, 150, 225, 300, 500, 750, 1000, 1500, 2000, 2500`

### Motor starting screen

The static voltage dip estimate uses the formula:

$$ VD\% \approx \frac{I_{start} \cdot kVA_{motor}}{kVA_{transformer}} \times Z_T\% $$

where the transformer impedance $$ Z_T $$ defaults to 5.75% per IEEE C57.12, and the starting current multiplier defaults to 6× per IEEE 141. These are conservative typical values — a dynamic motor starting study in ETAP or SKM is recommended whenever the screen raises a flag.

***

## Project Structure

```
loadsched/
├── src/
│   ├── main.zig          # CLI parsing and orchestration
│   ├── load.zig          # Load structs, demand factors, aggregation
│   ├── transformer.zig   # Standard rating selection
│   ├── feeder.zig        # Cable table, ampacity, voltage drop
│   ├── motor.zig         # Motor starting screen
│   ├── report.zig        # Report file writer
│   ├── bom.zig           # Equipment BOM CSV export
│   └── diagram.zig       # Single-line diagram DXF export
├── examples/
│   ├── food_processing_plant.json
│   ├── compressor_station.json
│   └── small_warehouse.json
├── reports/              # Output directory (created automatically)
├── build.zig
└── README.md
```
***

## Building From Source

Requires Zig `0.16.0-dev.2565+684032671` or a compatible nightly build, available from [ziglang.org/download](https://ziglang.org/download/).

```bash
git clone https://github.com/NotCaptainCandy/Loadsched.git
cd electrical-sizing-tool
zig build -Doptimize=ReleaseSafe
```

***

## Built With

- [Zig](https://ziglang.org/) `0.16.0-dev` — compiled, cross-platform systems language with no runtime dependencies
- Standard library only — no third-party dependencies
