# MAC Code Review
## ECE 410/510 - Codefest 4 - CLLM

## 1. LLM Model Versions

| File        | LLM     | Model Version     |
|-------------|---------|-------------------|
| mac_llm_A.v | Claude  | Claude Sonnet 4.6 |
| mac_llm_B.v | ChatGPT | GPT-5.3           |

## 2. Compilation Results

| File        | Command                                   | Result    |
|-------------|-------------------------------------------|-----------|
| mac_llm_A.v | iverilog -g2012 -o mac_llm_A mac_llm_A.v | No errors |
| mac_llm_B.v | iverilog -g2012 -o mac_llm_B mac_llm_B.v | No errors |

## 3. Simulation Results

Testbench: a=3, b=4 for 3 cycles, then assert rst, then a=-5, b=2 for 2 cycles.
Both files produced identical correct output:

    Cycle 1: out = 12  (expect 12)
    Cycle 2: out = 24  (expect 24)
    Cycle 3: out = 36  (expect 36)
    After rst: out = 0 (expect 0)
    Cycle 4: out = -10 (expect -10)
    Cycle 5: out = -20 (expect -20)
    Simulation done!

## 4. Issues Found

### Issue 1 - Blocking Assignment Inside always_ff (mac_llm_B.v)

(a) Exact offending lines:

    always_ff @(posedge clk) begin
        if (rst) begin
            out <= 32'sd0;
        end else begin
            mult = a * b;
            out  <= out + {{16{mult[15]}}, mult};
        end
    end

(b) Why it is wrong:
The line mult = a * b uses a blocking assignment (=) inside always_ff.
SystemVerilog requires always_ff to contain only non-blocking assignments (<=)
because always_ff models sequential flip-flop logic. In simulation the blocking
assignment executes immediately so results look correct, but in synthesis the
tool may implement mult as combinational logic instead of a register, causing
a simulation vs synthesis mismatch. This is the Wrong Process Type failure
mode listed in the assignment spec.

(c) Corrected version:
Move the multiplication outside always_ff into a combinational assign statement:

    logic signed [15:0] mult;
    assign mult = a * b;

    always_ff @(posedge clk) begin
        if (rst) begin
            out <= 32'sd0;
        end else begin
            out <= out + {{16{mult[15]}}, mult};
        end
    end

### Issue 2 - Sign Extension Error: Manual Bit Replication (mac_llm_B.v)

(a) Exact offending lines:

    logic signed [15:0] mult;
    mult = a * b;
    out  <= out + {{16{mult[15]}}, mult};

(b) Why it is wrong:
This is the Accumulator Width Mismatch failure mode listed in the assignment spec.
The 16-bit product in mult is manually sign-extended to 32 bits using
{{16{mult[15]}}, mult}. This manual bit replication is fragile: if the width
of mult ever changes, the replication count 16 must be updated manually or
the sign extension silently produces wrong results in hardware. The standard
and safe approach in SystemVerilog is to use $signed() which lets the tool
handle sign extension automatically based on declared widths.

(c) Corrected version:
Use $signed() on both inputs so SystemVerilog automatically sign-extends
the product to 32 bits with no manual bit manipulation:

    always_ff @(posedge clk) begin
        if (rst) begin
            out <= 32'sd0;
        end else begin
            out <= out + ($signed(a) * $signed(b));
        end
    end

### Issue 3 - Non-Standard Cast Notation (mac_llm_A.v)

(a) Exact offending lines:

    out <= out + (32'(signed'(a)) * 32'(signed'(b)));

(b) Why it is ambiguous:
The cast notation 32'(signed'(a)) is valid per IEEE 1800 but is less commonly
supported across all synthesis tools. Older versions of Quartus and certain
ASIC flows may issue warnings or errors with this style. The standard $signed()
system function is the portable, synthesis-safe, and universally supported way
to express signed intent and is recognized by Yosys, Vivado, Quartus, and DC.

(c) Corrected version:
Replace with the standard $signed() system function:

    out <= out + ($signed(a) * $signed(b));

Since a and b are already declared as input logic signed [7:0], $signed()
reinforces the signed intent and the result is automatically extended to
match the 32-bit signed accumulator out.

## 5. Summary Table

| Issue | File        | Severity | Failure Mode per Spec          |
|-------|-------------|----------|--------------------------------|
| 1     | mac_llm_B.v | High     | Wrong process type             |
| 2     | mac_llm_B.v | Medium   | Accumulator width mismatch     |
| 3     | mac_llm_A.v | Low      | Sign extension ambiguity       |

## 6. Conclusion

Both files compiled without errors and passed all testbench checks in simulation.
mac_llm_B.v (GPT-5.3) has two issues: a blocking assignment inside always_ff
causing simulation vs synthesis mismatch, and fragile manual sign extension.
mac_llm_A.v (Claude Sonnet 4.6) is cleaner but uses non-standard cast notation
that reduces portability. mac_correct.v fixes all three issues using $signed()
for portable sign extension and keeping always_ff strictly non-blocking.
