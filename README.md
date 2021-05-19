# COMET
Reactive Program Synthesis by COMposable Execution Traces

## Repository layout
* unity-synthesis/: Configuration, specifications, test harnesses
    * arduino/: Arduino model
    * bool-bitvec/: Boolean and bitvector language synthesis
    * unity/: UNITY model
    * verilog/: Verilog model
    * ...
    * **Global config**
    * config.rkt: Global configuration, bitvector length, feature selection
    * **Paxos**
    * paxos-arduino.rkt: Harness for Paxos Arduino synthesis
    * paxos-verilog.rkt: Harness for Paxos Verilog synthesis
    * paxos.rkt: UNITY specifications for Paxos
    * **Scalability benchmarks**
    * batch-sender.rkt
    * round-robin-sender.rkt
    * scale-arduino.rkt: Harness for scalability benchmarks
    * **Serial communication**
    * serial-arduino.rkt
    * serial-verilog.rkt
    * serial.rkt: UNITY specifications for serial communication
    * ...

## Per-model files:
* backend.rkt: S-expressions to native syntax
* inversion.rkt: Symbolic syntactic forms
* mapping.rkt: Refinement mappings
* semantics.rkt: Expression evalulator and statement interpreter
* syntax.rkt: Abstract syntax
* synth.rkt: Synthesis
* verify.rkt: Post-synthesis verification

## Getting started

### Requirements
* Rosette 4.0 or higher
* Racket 8.0 or higher
* Z3 (included with Rosette distribution)

### Running the experiments

#### Paxos with and without memoization

1. Memoization is controlled by the `memoize` boolean defined in `config.rkt`.
2. Uncomment the specification you wish to synthesize in `paxos-arduino.rkt` or `paxos-verilog.rkt`.
2. Run the Paxos Arduino harness: `racket paxos-arduino.rkt` or `racket paxos-verilog.rkt`.

#### Scalability benchmarks

1. Ensure that memoization is set correctly in `config.rkt`.
2. Run the scalability benchmarks harness: `racket scale-arduino.rkt`.

### Writing your own specs

1. Take a look at the existing specifications: `serial.rkt`, `paxos.rkt`, `batch-sender.rkt`, and `round-robin-sender.rkt`. In addition, take a look at the UNITY syntax: `unity/syntax.rkt`.
2. Use one of the existing specifications as scaffolding for writing your own.
3. Use one of the existing harnesses for targetting Arduino or Verilog.
4. Run it!